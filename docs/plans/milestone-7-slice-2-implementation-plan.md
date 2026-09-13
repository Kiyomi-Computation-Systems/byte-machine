# Milestone 7 — Slice ② (the generator over every construct, and the property suite) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

Authority: [decision 0033](../decisions/0033-property-suite-contract.md) (Gate 0, PR #85),
then `milestone-7-design.md` §4.3, §4.4, §4.10 and §7, then the parent plan's
`§22.4`, `§22.5`, `§22.6` and `§25:1618` / `§25:1620` / `§25:1621` / `§25:1626`.

This is the slice `§25:1618` and `§25:1620` name — the bounded valid-machine generator,
rebuilt, and the differential property suite over it. It replaces a generator that is valid
**by construction** with one whose validity is `verify-machine`'s verdict, moves the trial
into a library three slices will read, and takes the differential from five of `§22.4`'s
nine members to all nine plus two layers the lanes cannot supply between them.

Everything below was measured at **`f3fbf4e`** (`main` after PR #91), on branch
`docs/m7-slice-2-plan`, tree clean. Each number states the command that produced it. Every
`src/` and `test/` line number moves the moment Task 6 lands and no tool here notices them,
so every construct is named as well as numbered, and **Task 1 re-takes the whole census at
the slice's own base before anything is edited.**

Eight measurement reports were produced against this exact tree and are this plan's
evidence base. Where a number below came from one of them and describes a *prototype*
rather than the shipped tree, it says so: **a number from a throwaway driver describes the
driver**, and the floor literal in particular is a property of the generator this slice
writes, not of any prototype.

---

## 1. Twenty-three findings that shape the work

### F1 — design §4.4's draw, implemented literally, is accepted 3 of 64; and what it accepts is degenerate

A prototype of §4.4's draw written to the section's letter and run against the **shipped**
`verify-machine` accepts **3 of 64 draws (4.7%)** under the committed seed `20260823`.
Decision 0033 item 2 fixes the floor at "no lower than half the machine count", and design
§4.10 fixes the machine count at 64 — so the floor is **32**. The draw fails it by a factor
of ten.

```
sh scratch/run3.sh Z7 20260823 64 "(fin-term fin-kind eof-any stop-on span-pair)"
-> VARIANT=Z7 SEED=20260823 DRAWS=64 ACCEPTED=3 RAISED=0 RATE=0.046875
```

**The rate is not the finding.** Over 2000 baseline draws the same prototype accepts 251,
and of those:

```
sh scratch/run3.sh V1 20260823 2000 "(fin-term fin-kind eof-any stop-on span-pair)"
-> NODES=((1 . 135) (2 . 35) (3 . 42) (4 . 16) (5 . 9) (6 . 4) (7 . 4) (8 . 2) (9 . 2) (10 . 1) (12 . 1))
   ENTRY-KIND=((error . 134) (pause . 25) (sequence-dispatch . 19) (span-start . 19)
               (counted-consume . 18) (span-end . 14) (field-action . 9) (field-branch . 6)
               (integer-accumulate . 3) (callback . 2) (byte-dispatch . 2))
```

**135 of 251 accepted machines have exactly one node; 134 of them are a single `error` node
as the entry; a byte dispatch is the entry of 2.** A byte-range matcher appears in **one**
of the 251 — at sixty-four machines per seed set, ~0.25 machines.

The consequence for the plan is sharper than "steer the draw". *The floor as decision 0033
states it does not measure what it is for*: a draw could be steered to 100% acceptance by
making every machine a single error node and the floor would read green while every counter
of item 2 read zero. **What stops the degenerate case is item 2's counters, not the floor**,
and this plan says so where the floor literal is written (Task 7 Step 4) rather than
implying the floor carries that weight.

### F2 — three independent prototypes of the same paragraph disagree by 30×, so no prototype's rate may become the floor literal

Three agents prototyped §4.4's draw against the shipped verifier. Their baseline rates:

| prototype | baseline rate | dominant rejections |
|---|---|---|
| `constructs.md` §8.1 variant A | **30 / 200 = 15.0%** | `non-eof-into-finish` 225, `eof-reachable-stop` 115 |
| `prototype.md` §4.1 | **251 / 2000 = 12.55%** | `zero-progress-cycle` 2023, `non-eof-into-finish` 1434, `eof-zero-progress-cycle` 1417 |
| `verifier.md` §4.1 configuration X0 | **2 / 400 = 0.5%** | `invalid-callback-declaration` 348/400, `invalid-span-callback` 253/400 |

The structural reasons are visible in the histograms and are not defects in any of the
three: the first does not draw back-edges (so neither cycle code appears at all), and the
third draws callback kinds from all four (so `invalid-callback-declaration` dominates).
Every one is a faithful reading of the same paragraph.

**What they agree on is the shape, and only the shape may be relied on here:**

- `non-eof-into-finish` (`§16.2:908`) and `eof-reachable-stop` (`§16.2:909`) are the
  dominant cost of a uniform kind draw;
- `overlapping-cases` (`§16.2:893`) is the dominant cost of a free matcher draw over many
  cases, and is expensive to steer and cheap to leave;
- `missing-target` and `unreachable-node` go to **zero** as soon as only referenced nodes
  are emitted — found independently by two of the three;
- the accepted set of a free draw is trivial machines.

**Impact:** every rate in F3 below is a *price ratio*, never a rate this lane will produce.
Task 2 measures the floor through the rewritten generator and the rewritten lane, and
Task 7 Step 4 writes the literal from that measurement. A plan that transcribed 38/64 would
be quoting a different program — and *the draw order alone moves it*: every steering
changes how many values come off the PRNG, which re-rolls the whole seeded sequence, the
effect `property-differential-tests.sps:223-229` already records ("The accumulate draw takes
two numbers from the same stream, so the whole seeded sequence re-rolled and every count
below moved").

### F3 — the steering table, priced in both directions, each steering classified against 0033 item 1

Decision 0033 item 1 permits "structural steering **only** where a draw would otherwise be
unconstructible (a target must name something)", and its Rejected clause forbids a generator
that would "encode pass 7's lattice … a second verifier in the test tree that agrees with
the first by construction and can therefore never disagree with it".

**The discriminator this plan adopts, from `verifier.md` §3**, because it is measurable
rather than rhetorical: *a rule is validity steering when it takes the code it targets to
**zero** in the rejection histogram; it is structural when the code stays nonzero — the
verifier is still the arbiter and the generator has only changed the rate.*

All rows are from one prototype (`prototype.md` §4.3), at 2000 draws, seed `20260823`, so
the two directions are comparable with each other.

**Direction 1 — added to the §4.4 baseline** (`(fin-term fin-kind eof-any stop-on span-pair)`
= 251 / 2000 = 12.55%):

| variant | change | accepted / 2000 | Δ (pts) |
|---|---|---|---|
| R08 | **add `placed`** (kind vocabulary per slot class) | 690 | **+22.0** |
| R07 | add `cbdefault` | 326 | +3.8 |
| R04 | remove `stop` entirely | 306 | +2.8 |
| R01 / R02 | remove `finish` from the terminal / kind vocabulary | 302 / 302 | +2.6 each |
| R06 | add `back-prog` | 297 | +2.3 |
| R09 | add `few-cases` | 275 | +1.2 |
| R03 | remove "an arbitrary existing node" from the EOF-route draw | 257 | +0.3 |
| R05 | remove the span start/end pairing | 220 | −1.6 |
| R10 | **add `entry-bd`** | 83 | **−8.4** |
| J | add `cbkind-free` (callback kinds from all four) | 6 / 200 | −6.5 vs **`prototype.md`'s own 200-draw §4.4 baseline, 19 / 200 = 9.5%** |

**Direction 2 — dropped from the recommended set** (`(span-pair placed back-prog cbdefault
entry-bd few-cases)` = 1128 / 2000 = 56.4%), which is the direction that names each
steering's real price:

| drop | accepted / 2000 | Δ (pts) |
|---|---|---|
| `placed` | 238 | **−44.5** |
| `few-cases` | 616 | −25.6 |
| `back-prog` | 725 | −20.2 |
| `span-pair` | 811 | −15.9 |
| `cbdefault` | 922 | −10.3 |
| `entry-bd` | 1469 | **+17.1** (it is a cost) |

*Row J's baseline is not F2's "variant A".* F2's A is `constructs.md`'s §4.4-as-written
variant at **30 / 200 = 15.0%** (`constructs.md` §8.1, variant A); row J is measured against
`prototype.md`'s own 200-draw baseline, **19 / 200 = 9.5%** (`prototype.md` §4.3, row J's own
"vs A") — the same
`19 / 200` Task 2 Step 2 lists. The name "variant A" is reserved for `constructs.md`'s
throughout this plan, and row J spells its own baseline so a reader reproducing Step 3 knows
which one it is measured against.

**The two directions disagree about magnitude by a factor of two, and that is the point.**
`placed` is worth +22 added to a bad draw and −44.5 removed from a good one. A plan that
priced a steering in one direction only would misstate every number in this table.

**Each steering, classified, with the argument this plan would defend:**

1. **`placed`** — a `finish` node is drawn only at an `eof-target` slot; a `stop` node only
   at a slot that is `byte?`-and-not-`eof?` and is not `span-end-next`. **Structural.** F7's
   table: a `finish` is legal at **4 of 23** positions and illegal at 19; a `stop` is legal at
   15 of 23. "Draw a kind uniformly into a slot" is not a well-formed draw for those two kinds
   — it is unconstructible-in-context, the same category as "a target must name something".
   And the discriminator holds: `eof-reachable-stop` survives at **70 per 2000** with `placed`
   on, so the verifier still decides. *Price: −44.5 / +22.0.*
2. **`few-cases`** — a dispatch draws 1–2 cases, not 1–4. **A bound, not a steering.** §4.10
   already fixes the node budget, the input length and the schedule count; the case count is
   the same kind of number and belongs in the same list. Keeps all four matcher kinds at
   healthy rates (`m-exact` 472, `m-set` 432, `m-range` 372, `m-complement` 250 of 1128
   accepted). *Price: −25.6 / +1.2.*
3. **`back-prog`** — a back-edge is drawn only over a slot reached by consuming a byte.
   **Structural.** A back-edge over a zero-width slot closes a zero-width cycle *by
   construction*, so `zero-progress-cycle` there is a property of the edge that was drawn, not
   of the machine. Both cycle codes stay nonzero (`zero-progress-cycle` 297,
   `eof-zero-progress-cycle` 138 per 2000). *Price: −20.2 / +2.3.*
4. **`span-pair` + `span-body`** — spans are drawn as start → one advancing byte dispatch
   carrying its own private EOF error node → end. **Coverage steering, and §4.4 declares it
   so** ("the span steering is coverage steering, and the verifier still decides"). The
   pairing zeroes `invalid-span-state` in one prototype (95/400 → 0) and leaves it at 1 per
   2000 in another, so it sits at the boundary — and F5 shows the counter it exists for is
   **unsatisfiable without `span-body`**. Taken on the design's own warrant, with the residual
   measured rather than claimed. *Price: pairing −15.9 / −1.6; `span-body` **+1.6**, i.e. it
   is free.*
5. **`cbdefault`** — an optional `decision` callback's `default-branch` is one of its declared
   keys. **Validity — DECLINED. See F4**, which resolves it from the verifier's own code and
   states the measured consequence. *Price: −10.3 / +3.8.*
6. **`entry-bd`** — the entry is a byte dispatch. **Coverage steering, which §4.4 presupposes
   without saying so**: it keeps "the 256 single-byte trials … §22.7's all-byte coverage of
   *the entry dispatch*". Measured with the entry drawn freely, a byte dispatch is the entry
   of **2 of 251** accepted machines and appears anywhere in **6**. *Price: **+17.1 / −8.4** —
   it costs points in both directions, and buys the entire §22.7 trial.*
7. **Only referenced terminals are emitted.** **Structural** — a machine carrying a node
   nothing can name is not a draw, it is a bug. Measured independently by two prototypes:
   `missing-target` and `unreachable-node` go from 176 / 390 to **0**. *Not priced as a
   steering: it is the construction method.*

**Two validity steerings measured and REFUSED, with the measurement:**

| variant | rate | why refused |
|---|---|---|
| `disjoint` (case *i* draws inside its own `256/n` chunk) | 164 / 200 = **82.0%**, `overlapping-cases` → **zero** | Zeroes the code, and complement matchers fall to 16 of 164 accepted machines. In a sibling prototype the analogous rule took `m-exact`, `m-set` and `m-complement` to **0 of 326** accepted machines, leaving only `m-range`. Decision 0033 item 2 requires a counter per matcher kind ≥ 1. |
| `distinct` (distinct exact bytes — the shipped generator's H1) | 17 / 200 = 8.5% | Sacrifices **three of the four matcher kinds** and buys nothing. |

**A structural fact about `make-byte-complement-matcher` worth recording where the matcher
draw is written:** a complement matches everything outside the matcher it wraps, so in a
dispatch with any second case it overlaps *by construction* unless that case is contained in
the complemented set (`matcher-bytes` of a complement of a one-byte matcher is 255 bytes).
`m-complement` is therefore the matcher kind most likely to be starved by any
overlap-avoiding steering, and `few-cases` is what keeps it alive at 250 of 1128.

### F4 — `cbdefault` is validity steering, resolved from the verifier's own code; the plan declines it, and the measured consequence is a rate below the floor

This is the one place where the record's letter and the measured tree pull against each
other, and the resolution is from the code, not from the prototype's label.

**The rule, quoted.** `pass-declarations`, `src/byte-machine/verify.sls`, the `§16.2:891`
arm:

```scheme
       ;; §16.2:891. Derived from §9.3:419, not invented here: "An optional
       ;; decision callback must declare `default-branch`". A REQUIRED decision
       ;; callback needs none -- it is always bound, so no default is reached.
       (filter values
               (map (lambda (cd)
                      (let ((k (callback-declaration-kind cd))
                            (req (callback-declaration-required? cd))
                            (db (callback-declaration-default-branch cd)))
                        (if (and (eq? k 'decision) (not req)
                                 (not (and (symbol? db)
                                           (memq db (callback-declaration-branch-keys cd)))))
                            (make-diagnostic/declarations 'invalid-callback-declaration
                                             (callback-declaration-name cd)
                                             "optional decision callback has no valid default branch" (list (callback-declaration-name cd)))
                            #f)))
                    cbs))
```

**The reframing available, and why it fails.** One could say a `default-branch` is *a
reference that must name one of the declared keys*, which is the same category as "a target
must name something" and therefore structural. Two facts in the code refuse it:

1. **The slot is not a reference-that-must-name-something.** `#f` is not a degenerate value
   here; it is the *correct* value for a required decision callback and for every
   non-decision callback. The obligation is conditional on `kind` **and** `required?` — which
   is exactly the conjunction the verifier evaluates. `make-callback-declaration` accepts
   `#f` and accepts any symbol: `(unless (or (eq? default-branch #f) (symbol? default-branch))
   …)`. Nothing is unconstructible.
2. **`make-callback-declaration`'s own header names this check by number as deliberately
   deferred, and states the consequence of moving it** — verbatim, `ir.sls`:

   > *** WHAT IS DELIBERATELY *NOT* CHECKED HERE, and why. *** Three checks are
   > locally evaluable from these six arguments and all three belong to the
   > verifier (design §6, decision 0020's split):
   >   - §16.2:891, an optional DECISION callback without a valid declared
   >     default branch — `kind`, `required?`, `branch-keys` and
   >     `default-branch` are all right here, and it is still pass 6a's;
   >   … a machine whose construction failed never exists, so the verifier arm
   >   becomes unreachable through the public API and its permissive mutation
   >   survives while the suite reports it caught.

   A generator that steers around `§16.2:891` reproduces, one layer out, precisely the
   failure that paragraph exists to prevent.

**Verdict: `cbdefault` is validity steering. The plan declines it.**

**The measured consequence, stated and not papered over.** Dropping `cbdefault` from the
recommended set gives **922 / 2000 = 46.1%** (`sh scratch/run3.sh S3 20260823 2000
"(span-pair placed back-prog entry-bd few-cases)"`), i.e. **~29.5 accepted of 64 — below the
floor of 32.** Declining the steering and changing nothing else puts the slice under 0033
item 2's own trigger — "a measured rate below half sends the draw back for steering before the
lane lands" (`0033` item 2, verbatim; the draw lives in §4.4, which is where "back" goes).

**The remedy, in two parts, both grounded in the same code.**

**(a) The `default-branch` is drawn from the slot's own vocabulary.** Instead of forcing it
to a declared key, draw it uniformly from `(cons #f declared-keys)` — the machine's own key
space plus the legal absence. That is a *draw over one slot among values the slot already
admits*, which is the same class as §4.4's own EOF-route draw from `{#f, a finish, an error,
an existing node}` — a four-way choice over a slot whose vocabulary is `{a symbol naming a
node, #f}`, not a widening of it. It leaves `§16.2:891` firing whenever the draw lands `#f`
on an optional decision callback, so the code stays nonzero and the discriminator of F3 is
satisfied.

*The arithmetic, stated as a prediction the measurement overrides.* With kind a fair coin
over `{event, decision}`, `required?` a fair coin, and `k ∈ {1,2}` declared keys, the
fraction of declarations tripping `:891` is `1/2 × 1/2 × 1/(k+1)` ∈ [1/12, 1/8] against
`1/2 × 1/2 = 1/4` under the free draw — roughly a factor of two to three, not zero.
Predicted acceptance between 46.1% and 56.4%. **Task 2 Step 6 measures it. This paragraph is
not a number.**

**(b) Branch keys are drawn only for `decision` callbacks — and this one IS structural, on
the same code's own asymmetry.** `invalid-callback-declaration` has **two** emission sites
in `verify.sls`. The second is:

```scheme
       ;; A non-decision callback declaring branch keys or a default branch:
       ;; §10.3:504 gives branch keys to DECISION callbacks only, so any key on
       ;; another kind is undeclared by construction (§16.2:901's "undeclared").
```

**The discriminator is the deferral list, not the chapter the bullet sits in.**
`make-callback-declaration`'s header names exactly three checks as deliberately deferred to
the verifier — `§16.2:891`, `§16.2:902` and `§16.2:886` — and the branch-keys-on-a-non-decision
arm is **not among them**, while `:891` (the `default-branch` obligation F4 declines) **is**.
That asymmetry is the whole argument. `§10.3:504` — "allowed branch keys for decision
callbacks" — is a supporting citation only, and it is important that it stay one: **`§10.3:505`
is the very next bullet in the same shape list** and reads "the default branch for an optional
decision callback", so "it is a §10.3 declaration-shape bullet" would license `cbdefault` by
the identical reasoning and re-open two pages of F4 on the weaker argument. Drawing branch keys
only for decision callbacks is drawing the declaration's own shape; drawing a valid
`default-branch` is discharging a check the constructor deliberately left to pass 6a.

*This half is already inside every rate in F3's table*: the prototype draws kind from
`#(event decision)` and gives keys only to `decision`, so its −10.3 price for `cbdefault` is
the `:891` arm **alone**. Stating that is what stops a reader double-counting the remedy.

**If Task 2 Step 6's measured accepted count is still below 32**, the escalation ladder, in
order, each with its price and none of them a floor reduction (0033 is a Gate 0 record and a
plan may not weaken one):

1. re-measure with the `span-body` correction of F5 included — measured **+1.6 points** and
   required for the span counter anyway;
2. the remaining rejection classes in the recommended set, by size (`overlapping-cases` 761,
   `zero-progress-cycle` 297, `inconsistent-span-state` 163, `eof-zero-progress-cycle` 138,
   `eof-reachable-stop` 70 per 2000) — every cheap lever over the first is one of the two
   **refused** matcher steerings of F3, so this step has no move that does not cost a
   matcher counter;
3. **escalate to the owner** as an amendment note on decision 0033 — the span-pairing
   reframing `verifier.md` §3(a) option 1 describes ("a span is a bracketed region; a lone
   span end is a lone closing paren, so the pair *is* the construct") is a *reading* of
   clause 1 and not a fact, and it must be ratified in the record rather than widened
   quietly by a plan.

### F5 — §4.4's span pairing is UNDER-SPECIFIED, and the adjacent realisation of it makes decision 0033 item 2's span counters unsatisfiable

**The defect is in the realisation, not in §4.4's sentence, and this plan says which** — a
false supporting argument for a correct decision is the shape this branch already carries four
instances of (Task 13 Step 2). §4.4's full sentence is "span nodes drawn as a matched start/end
pair **whose end has a private error sink and a non-terminal successor**". It constrains the
end's *successor* and says **nothing about what lies between start and end**, which a worklist
would fill with drawn nodes. The prototype realised the pairing **adjacently** — the end is the
start's `next` — and that is where `[mark, mark)` comes from.

**And §4.4 already presupposes the body node, on its own stated warrant.** The clause names a
"private error sink", which F6 measures is a slot **`make-span-end-node` does not have**; and
the warrant §4.4 gives for it — "a shared sink joins `none` with `(active s)` (decision 0029
item 2)" — is a claim about a node reached **with a span open**, i.e. an input-reading node
*inside* the span. The only node in the construct that can carry an `eof-target` at all is
therefore a body node, and §4.4's own clause is what implies it. §4.4 is **tightened**, not
corrected: the pairing sentence stands and gains the body explicitly.

Realised adjacently, the span covers `[mark, mark)`. **`§14:834`** ("Empty
span-data fragments are suppressed") suppresses it, so the span-data callback is **never
invoked**:

| span pairing | span-fragment machines of 40 | trial shape |
|---|---|---|
| adjacent pair (the prototype's realisation) | **0** | 256 single-byte trials |
| adjacent pair | **0** | 256 four-byte trials |
| **start → a one-case advancing byte dispatch → end**, that dispatch carrying **its own private EOF error node** | **4** | 256 single-byte trials |

```
sh scratch/run3.sh W3 20260823 1 "(span-pair placed back-prog cbdefault entry-bd few-cases interp)"
-> OBSERVED-IN-N-MACHINES: … span-fragment=0 …
sh scratch/run3.sh W4 20260823 1 "(… interp long-input)"
-> OBSERVED-IN-N-MACHINES: … span-fragment=0 …
sh scratch/run3.sh W5 20260823 1 "(span-pair span-body … interp)"
-> OBSERVED-IN-N-MACHINES: … span-fragment=4 …
```

Zero fragments across 40 machines × 10 240 single-byte trials, and zero across 10 240
four-byte trials. **Under the adjacent realisation the span-event counters decision 0033
item 2 demands read zero forever, in both halves, on every seed.**

**The correction costs nothing** — acceptance is *higher* with it: 1160/2000 = 58.0% with
`span-body` against 1128/2000 = 56.4% without (`X1` vs `T2`). It is cheaper than the
adjacent pair because the body node's own EOF sink is the decision-0029 discipline §4.4
itself argues for, applied to the node that actually **has** an `eof-target`.

**§4.4 is tightened in place** (Task 12 Step 1), with the body node written into the pairing
sentence and a note recording that the sentence's own "private error sink" clause is what
implies it. It is not filed as an error in §4.4, because it is not one.

**The seed sensitivity, which is the part the plan must not ship blind.** The same
measurement at 40 accepted machines under four seeds:

| seed | span-fragment machines of 40 |
|---|---|
| 20260823 (committed) | 4 |
| 1 | **0** |
| 7 | **0** |
| 99 | 3 |

**Two of four seeds deliver no span fragment at all — with the `span-body` shape already
applied.** A span-event counter driven only by §4.4's 256 single-byte trials is a coin flip.
The drawn multi-byte inputs and the schedule sweep must carry it, and **Task 7 Step 5 measures
that they do, first, before any other counter** — this is the single most likely way Slice ②'s
oracle goes red for a reason that is not a defect.

*What this table is and is not.* It is a **diagnostic**, measured on the prototype at 256
single-byte trials only, with none of the drawn multi-byte inputs and none of the schedule
sweep. It is **not** a pass criterion. Decision 0033 item 2 asserts each counter "≥ 1 over the
seed set"; item 3 fixes one committed default that "CI and every pin run"; and design §7's
Oracle reads "every counter ≥ 1 in both halves **under the committed seed**". Task 7 Step 5
therefore **gates on the committed seed** and **records** the other three. The plan does not
pre-classify a zero under a non-committed seed as a defect in this slice — this very table
shows the `span-body` shape landing and two seeds still reading zero, so "the shape did not
land or the sweep is not reaching the span" is not an exhaustive disjunction.

### F6 — §4.4's "private error sink" names a slot that does not exist, and the two constructors flanking it fail differently

§4.4: "span nodes drawn as a matched start/end pair **whose end has a private error sink**
and a non-terminal successor".

`make-span-end-node`'s full parameter list is `name span next source-label`. There is no
`error` slot on either span kind, and the constructor's header says so:

> One mandatory successor each, on the field-action precedent rather than the
> byte-dispatch eof-target one: neither §10.6:590 nor §10.6:594 gives these
> kinds a route of their own for anything, so there is no case for a #f arm.

Measured, a fifth argument does not even raise a contract condition:

```
RAISED-OTHER make-span-end-node with a fourth 'error' argument (NO SUCH SLOT)
  | (- "incorrect number of arguments ~s to ~s")
```

— a **raw Chez arity error with no `who`**, which a lane's `guard` reads as "the case
raised" and which no diagnostic names.

And the same mistake on the neighbouring kind is worse because it is **silent**:

```
ACCEPTED  make-counted-consume-node with an 'error' argument (NO SUCH SLOT)
```

`(make-counted-consume-node 'n 'f 'x #f 'err)` builds, with `'err` landing in
`source-label`.

**The steering is therefore re-stated, and it is the same node F5 requires:** *every
input-reading node drawn between a span start and its matching end draws its `eof-target`
to a fresh error node of its own, never to a shared sink.* The shipped realisation of the
idea is already in the tree — `counted-machine.sls:111-113`:

> `body`'s EOF route is its OWN truncation node: the shared one is reached with
> no span open, and pass 7 rejects one node carrying both states.

The decision-0029 argument §4.4 gives is correct; only the carrier is misnamed. **Corrected
in place** (Task 12), and the two API traps go in a comment at the span task's site.

### F7 — the kind draw is position-dependent for **two** kinds, not one, and the table is the most load-bearing in the slice

`test/common/kind-position-census-tests.sps`'s `position-table` has **23** positions
(`sed -n "/^(define position-table/,/^$/p" … | rg -c "^   \(list '"` → `23`), of which
**19** are byte positions and **7** are EOF positions (`… | rg -o "^   \(list '[a-z-]+ +#t"
| wc -l` → `19`; `… +#[tf] +#t` → `7`). Read as a draw rule, through `expected-codes`:

- **a `finish` node is legal at exactly 4 of the 23 positions** — the four `eof-target`
  slots `dispatch-eof-target`, `sequence-eof-target`, `accumulate-eof-target`,
  `count-eof-target` — and nowhere else;
- **a `stop` node is legal at 15 of 23** — everywhere except the seven `eof?` positions
  **and `span-end-next`**, whose own comment reads "*** A SPAN END IS A PARKED STATE ***".

A uniform thirteen-way kind draw into an arbitrary slot therefore puts an illegal node there
by construction, and for `finish` there is **no** byte-slot draw that can produce a valid
one.

**Two corrections to the evidence base, carried so a reviewer does not have to re-derive
them:** `constructs.md` §5.3 says "Twenty of the 23 positions are byte positions" — measured,
**nineteen**; and its D3 says only `finish` is un-drawable, while the same table shows `stop`
illegal at eight positions.

**Impact on the plan, three ways.** The kind draw needs a *position-aware vocabulary*, not a
uniform one (that is `placed`, F3 row 1, the +22/−44.5 steering). A `finish` node's only
producer in an accepted machine is the **EOF-route draw**, so its counter must be driven by
an EOF trial, not a byte trial (F13's LABEL 4 nesting hazard is the same fact from the pin
side). And the generator's own totality row must assert that all thirteen kinds appear
**somewhere across the draw tables** — not that each appears at each slot, which `§16.2`
makes false.

### F8 — the worklist construction silences three diagnostic codes and three of §4.6's eight oracle rows

Measured across 8 800 draws in 26 configurations, **17 of the 30 codes were produced and 13
were never produced**:

```
comm -23 /tmp/all30.txt /tmp/seen17.txt
duplicate-callback-declaration  duplicate-error-declaration  duplicate-name
duplicate-span-declaration      invalid-eof-target           invalid-field-declaration
invalid-name                    invalid-shape                missing-callback-declaration
missing-error-declaration       missing-target               reserved-branch-key
unreachable-node
```

Two of those are silenced by **§4.4's own construction method, not by any steering the plan
could drop**: a worklist over open slots fills every slot with a node it allocated or a
terminal it emits, so `lookup` never misses (`missing-target` **0/8800**) and every node has
an in-edge from its allocator (`unreachable-node` **0/8800**). Five more are `(memq x seen)`
checks over tables built from counter-minted names, which cannot collide.

Design §4.6 says of the independent oracle: "Each rule fires ≥ 1 and stays silent ≥ 1 across
the draws, or the row is red." **Three of its eight rows — `:885` (duplicates), `:887`/`:905`
(resolution) and `:897` (unreachable) — cannot fire on the material §4.4 produces.**

**The plan's decision, taken here because it changes what Slice ② builds — and whose row it
is, said precisely.** The generator gains two explicit, named, priced draws — with probability
*p* a slot names a symbol that is never built (a **dangling target**), and with probability *q*
an allocated node is attached to nothing (an **orphan**). Both are *draws*, not rules: they
widen what the generator produces rather than narrowing it, so 0033 item 1's permission is not
engaged at all.

**The obligation they discharge is §4.6's, and §4.6 is Slice ④'s.** "Each rule fires ≥ 1 and
stays silent ≥ 1 across the draws, or the row is red" is the **independent oracle's** oracle,
and §4.6's own drive is "§4.4's generator **with its structural steering off**, plus every draw
the property lane rejected" — a configuration Slice ④ selects. Nothing in decision 0033, §4.3,
§4.4, §4.10 or §7 requires **this** lane to produce `missing-target` or `unreachable-node`;
0033 item 1 requires only that rejected draws be counted by code and kept.

**So the draws are built and measured here and turned on there.** `p` and `q` are members of
the steering record (F18) — the mechanism this plan already ships so that "whatever the
property lane steers around, the free mode still produces". **In the property lane they are
`0`**, so they cost the acceptance rate — the one number 0033 item 2 turns into a blocking
gate — **nothing**. Task 2 Step 9 measures them with the draws **on**, in the scratch
prototype, and Slice ④ inherits the numbers through Task 12 Step 7's hand-forward. Charging a
Slice ④ row to Slice ②'s floor would be spending the gate's own budget on someone else's
oracle, and Task 2 Step 8's rung 2 says in terms that such a rung "can only make it worse".

**And the list of seventeen codes a free draw supplies for free is handed forward to Slice
④** in Task 12 — it is the difference between Slice ④ writing thirty catalogue entries and
writing thirteen.

**One consequence of Slice ⓪ the plan must expect at the moment Slice ④ turns them on.**
Decision 0031 narrowed `pass-reachability` to the occupiable relation; the family
`E →(eof) T →(byte) Z` moved ACCEPTED → REJECTED, and everything behind an EOF-only-reachable
dispatch's byte edges is now dead under `:897`. The worklist hides that family today (every
node is byte-reachable from the entry). **The orphan and dangling draws are what make
`unreachable-node` start appearing**, and it is expected in the free mode's ledger at that
point rather than treated as a regression.

### F9 — the counter census: 46 counters over seven families, 92 checks, and three families have no source of truth in the tree

Decision 0033 item 2 names seven families. Measured, member by member:

| family | members | counters | checks | source of the closed list |
|---|---|---|---|---|
| node kind | 13 | 13 | 26 | `node?`, `ir.sls` — **derived** |
| matcher kind | 4 | 4 | 8 | `matcher?`, `ir.sls` — **derived** |
| field operation | 7 | 7 | 14 | `field-operations`, `ir.sls` — **derived** |
| field predicate | 7 | 7 | 14 | `field-predicates`, `ir.sls` — **derived** |
| callback outcome | 4 | 4 | 8 | parent plan `§13:805-808` — **literal** |
| span event | 5 | 5 | 10 | parent plan `§14:830-836` — **literal** |
| schedule shape | 6 | 6 | 12 | parent plan `§22.5:1278-1283` — **literal** |
| **total** | **46** | **46** | **92** | |

```
rg -n "span-events|span-event|schedule-shapes|schedule-kinds|callback-outcomes" \
   --glob '!build/**' --glob '!.claude/**' .
-> (no output)
```

**Three of the seven families have no closed list anywhere in `src/` or `test/`.** Design
§4.10 names five totality rows and all five are the derived ones; callback *outcomes*, span
events and schedule shapes have neither a row nor a source. For those three the closed list
is **declared in the program and pinned to a `§`-line citation**, and the plan says so rather
than letting a census sweep read "five totality rows exist" as discharging item 2 over seven
families.

**The five span events, each with a measured observed witness** (probe 1, both lanes
byte-identical): `span-open` (`parser-active-span` ≠ `#f` after a feed — measured
`(need-input body payload)`); `boundary-fragment` (a fragment whose `(parser-state-name ps)`
is an input node — `(data body payload 1 2)`); `end-fragment` (a fragment at the span-end
node — `(data sclose payload 2 3)`); `completion` (the complete callback fired with
`parser-active-span` `#f` inside it — `(done sclose #f)`, which is `§14:841` observed);
`suppressed-empty` (a completion with **zero** fragment records over an empty
`[mark, cursor)`).

**The four callback outcomes, each observed without reading the script** (`§13:805-808`; the
evidence base works each one through, `counters.md` §2.5 rows 32-35). The script is the
**draw**, so no counter may read it; all four are readable from the trial:

- `continue` — the post-step `(parser-state-name pr)` equals the callback node's **continue
  target**, with no branch marker set;
- `pause` — `(parser-result-status r)` is `paused` at a step whose callback accumulator gained
  an entry, plus the `(parser-resume! pr)` ack, and on resume the state name is the node's
  declared pause continuation (`§13:812-814`). **This is a distinct member from
  `node kind pause`**: a callback *returning* pause is not a pause *node* executing, the two
  labels differ by their family word, and each gets its own pair;
- `declared-branch-key` — the post-step state name is the **branch** target for the key the
  script returned, distinct from the continue target. The `key → node` mapping comes from the
  **callback declarations in the draw manifest** (Task 6 Step 1), which is a decoder in exactly
  the sense F18 licenses: *the observation is that the trial reached that name; the alist only
  says what that name was drawn as*;
- `explicit-failure` — `(parser-error-code e)` equals the drawn failure's application code,
  with `(parser-error-domain e)` `callback` and `(parser-error-node-name e)` the callback
  node's name — all three already compared by `project-error`. This is the one callback outcome
  fully observed with **no steering at all**.

**The six schedule shapes, each observed from the result sequence and never from the schedule
spec the driver was handed** (`§22.5:1278-1283`; `counters.md` §2.7 rows 41-46). The driver
returns a Layer-1 tuple per step, and every shape is a property of that list:

- `every-split-point` — ≥ 2 feed **results**, the first `need-input` with `consumed` equal to
  the split index; `split-point-pair` — ≥ 3 feed results over one input; `random-multi-split`
  — ≥ 3 feed results **and** a raw fragment/`need-input` boundary sequence differing from the
  one-feed baseline's (`§22.5:1287` makes raw boundaries schedule-dependent, which is what
  makes this one non-tautological);
- `empty-feeds` — a feed result with `consumed` 0 and `next` equal to the call's `start` at a
  **non-sticky** lifecycle; `nonzero-slice` — a first feed whose `next` ≥ a nonzero `start`
  (`next` is slice-relative, `§9.3:392`, so a lane reading from index 0 answers differently);
  `padded-bytevector` — the same, **and** the stream offset after equals the offset before plus
  `consumed`, with unrelated prefix/suffix bytes present.

**The honest caveat, carried because it is the weakest of the seven families.** The driver
*chose* the shape, so "an observed value, never the draw" is hardest here. The forms above are
the strongest available — each reads something the **parser** produced (a result count, a
`consumed`, a `next`, a boundary trace), not the cut list — and the shipped anti-precedent is
named in the Global Constraints so it is not copied: `differential-sequence-tests.sps`'s
`(check "at least one draw was a genuine multi-split (>= 2 cuts)" (> multi 0))`, where `multi`
is folded from the drawn `cuts`.

**Without these two paragraphs the executing agent is handed twenty required checks, a census
row demanding them, and — in `trial-result`'s callback trace — exactly one convenient value,
the scripted `outcome`, which is the forbidden one.** That is F10's shipped defect
(`(pair? fnames)`) reproduced at ten counters, in a plan written to stop it. Task 4 Step 2's
callback-trace record therefore carries the **observed** fields beside the scripted one, and
the scripted `outcome` is retained for replay and for the Layer-1 cross-lane comparison only —
never as a counter's operand.

**Two members have no state-name witness and need a mechanism the shipped generator does not
have, demonstrated rather than assumed** (probe 2): `parser-state-name` **never names** a
zero-width node — a machine `start --A--> act(set-mask) --> br(zero f) -> yes|no --> gate`
reports `after1 (need-input gate 12 5)` in both lanes, three nodes later. What *does* witness
them is the **field value**: `seen = 5 = 1 | 4` proves `act`'s `set-mask` ran and that the
**false** arm of `zero` on `f = 12` ran. So:

- **field operations** need a **witness field per drawn `field-action` node**, so the change
  is attributable to one node, with an operand drawn so the change is visible (a `store`
  constant ≠ the prior value, a `clear` on a nonzero field, an `increment` below the bound, a
  `set-mask` with a bit the value lacks, a `clear-mask` with a bit it has);
- **field predicates** need a **marker `field-action` node on each arm** writing distinct
  bits into one marker field. The shipped precedent is `cov-marker` and the `yes`/`no` pair
  in `field-access-tests.sps`'s `cov-machine`, whose comment records `mask-all 12` surviving
  and `mask-all 14` catching — *the operand must separate a member from its siblings*.

Both are coverage steering of the class §4.4 already licenses for spans, and **refusing them
means item 2 cannot be discharged for fourteen of the forty-six counters.** They are taken,
and Task 6 Step 8 says so at the site.

**`span-event/suppressed-empty` is an absence and needs the conjunction stated**: the counter
reads two *positive* observed values together — the completion event fired **and** the
fragment accumulator's length over that interval — so it cannot be satisfied by "nothing
happened at all". If that still fails to separate, the fallback is a **drawn shape that
forces the empty case** (a `span-start` immediately followed by a `span-end`, which
`§14:831`'s "if nonempty" makes always-empty and which `differential-span-tests.sps`'s
`eopen`/`eclose` pair proves verifies), never `EXPECT_SURVIVES`.

**The label vocabulary, and the one mutual-substring pair in it.** Agreed half: `at least one
agreed trial <verb> <family word> <member>`; interpreter-only half: `the interpreter alone
<verb> <family word> <member>`. Keeping those two prefixes keeps decision 0033's own census
command (`rg -c '"at least one|"the interpreter alone' …`) working and printing the new
total. Every pair in all seven families was checked; **the only mutual substring is `field
operation clear` inside `field operation clear-mask`**, separated by the mandatory
` -- expected a true value` tail (F11). `zero`/`nonzero` do not collide because the family
word immediately precedes the member.

### F10 — the shipped eight are five agreed and three interpreter-only, one of them reads the draw, and two have no twin

Decision 0033 item 2 says "Each has the two halves the shipped lane has … the shipped eight
stay." Measured, the shipped lane does not have that shape:

```
rg -n '"at least one|"the interpreter alone' test/common/property-differential-tests.sps
-> 276, 279, 288, 290, 296   (five "at least one …")
   304, 306, 312             (three "the interpreter alone …")
```

Pairing by accumulator: `acc-count`↔`acc-ref-count`, `over-count`↔`over-ref-count`,
`paused-count`↔`paused-ref-count`. **`finished-count` and `field-count` have no twin.** So
"the shipped eight stay" and "each has the two halves" cannot both hold: the shipped eight
must become **ten**, and this plan names the two new labels (Task 7 Step 3).

**And one of the eight reads the draw, which item 2's own sentence forbids.**
`property-differential-tests.sps:266`:

```scheme
(if (pair? fnames) (+ field-count 1) field-count)
```

`fnames` is `gen-machine`'s **second return value** — the generator's own record of what it
declared. No parser is consulted. The check it feeds is `"at least one generated machine
declares a field"`, and item 2 says a counter reads an observed value "**never the draw that
requested it**". Measured: `field 25` of 40, against `acc 13` / `over 13` for the observed
halves.

**Resolution, by name:** the label survives and its **witness changes** to an observed one —
a field value read back through `parser-field-ref` from **both** parsers and differing from
its declared initial. No Pass 39 pin is anchored on that label, so nothing breaks; and it
gains an interpreter-only twin. Carrying it forward unchanged would reproduce the pattern at
~90 counters, which is the one thing item 2 exists to stop.

**`finished-count` is a conjunction its name does not show**, and the lane's own comment says
so: reaching `finished` needs the EOF draw to have routed the entry's `eof-target` to `done`
**and** at least one of the 256 bytes to leave both parsers `ready`. That is an argument
*for* a twin, not against one.

**The shipped eight against the new families.** **Seven of the eight** cover a member a new
per-kind counter also covers (rows 1/8 → `node-kind/pause`; row 2 → `node-kind/finish`; rows
4/6 and 5/7 → `node-kind/integer-accumulate`'s digit and overflow arms; **row 3 is the only one
excluded** — it is a declaration draw and is no family member). Measured, the eight labels are
at `property-differential-tests.sps:276, 279, 288, 290, 296, 304, 306, 312` and the pairing by
accumulator reproduces exactly. **The shipped label IS the member's counter** — minting a
second label for the same member produces two checks that fail together and therefore two
records for every pin on either, which is F11's defect deliberately reintroduced.

**The arithmetic, derived term by term under F9's own template.** The evidence base
(`counters.md` §7.2) states this as `92 − 2 − 2 + 2 + 2 ≈ 94`, which evaluates to **92**,
carries a `≈`, and ends "the plan should state the exact number". Derived here instead, with
the pause and finish pairs scored **alike**, because they stand in the same relation to the
table:

| term | value | why |
|---|---|---|
| F9's census | **92** | 46 members (13 + 4 + 7 + 7 + 4 + 5 + 6) × two halves |
| the shipped pause pair | **+0** | it **is** `node kind pause`'s two checks — absorbed, not added, and not subtracted either |
| the shipped finish pair | **+0** | it **is** `node kind finish`'s two checks (one shipped, one new twin) |
| `integer-accumulate`'s second arm | **+2** | the family has one member and the node has **two** arms; the digit and overflow pairs are four checks where the table holds two |
| the `declares a field` pair | **+2** | a declaration draw, no family member at all (F10 row 3) |
| **total** | **96 counter checks over 48 keys** | |

`callback outcome pause` is a **distinct member** from `node kind pause` and gets its own pair;
F9's label template (`at least one agreed trial <verb> <family word> <member>`) makes them two
different labels, and collapsing them would leave a callback *returning* pause with no witness
at all. **48 keys × 2 = 96** is the literal, written once here and set from here in Task 3
Step 6, Task 3 Step 11, Task 7 Step 6, Verification item 5 and the Exit. The two assertions of
Task 3 Step 6 — `asserted` against the literal, and `asserted` against
`(* 2 (length (counter-keys)))` — then agree **by construction**; at 94 they could not both
hold, because 94 requires 47 keys and no key set consistent with F9 and F10 produces 47.

### F11 — every per-member pin must anchor on the interpreter-only half's **full** label, and this is measured, not preferred

Applying Pass 39's `compile.sls` byte-test inversion and running the property program:

```
status=1   FAIL lines: 43   pin "byte agreement" occurrences: 40
```

The three non-agreement FAIL records are, verbatim:

```
at least one of the 40 generated machines' 256-byte trial observes a pause -- expected a true value
at least one generated machine's trial commits a digit -- expected a true value
at least one generated machine's trial overflows the field -- expected a true value
```

**The compile-inversion mutant zeroes every AGREED counter and leaves every INTERPRETER-ONLY
counter standing** — all three shipped pairs, measured. In the rewritten lane it will
therefore satisfy *every* agreed-half pin. **Every per-member pin anchors on the
interpreter-only half's label**, which is the half no cross-lane divergence can zero.

The shipped comment already states the principle (`property-differential-tests.sps:150-157`:
"The interpreter-only counters separate 'the arm never ran' from 'the lanes disagreed about
it'"); this is the proof at the pin level.

**And the pin must be the full label plus ` -- expected a true value`.** Two measured
reasons: the bare phrase `observes a pause` matches **two** labels of its own mutant's output
(F14), and `field operation clear` is a literal substring of `field operation clear-mask`
(F9). The two shipped accumulate pins, which are written as full labels plus the detail, stay
at 1 even though their own twins also fail — that is the shape to copy.

**The per-machine agreement label cannot satisfy the rule as written.** `"byte agreement"`
matches 40 records because the label is *per machine*. Two dispositions are available and the
plan must pick one and write it down:

- **name one machine index** — measured working today: `"machine 0 \\(seed 20260823\\) byte
  agreement"` → 1 in its own mutant, 0 in all five others — at the cost of being a drawn
  shape that must be re-measured whenever the seed or the machine count moves, and design
  §4.10 moves the count to 64;
- **read the rule as "one (case, check-label) pair" for a parameterised label** and record the
  count it does produce beside the pin.

**This plan takes the first** (Task 10 Step 2), because design §7's oracle says "each pin's
match count in its own mutant's output exactly one" and a plan that reinterprets the oracle
to fit the tree is weakening it. The machine index and the `got` value are re-measured after
the rewrite, never carried over, and the pin's comment names the seed it was measured under
(decision 0033 item 3).

### F12 — the rejects-everything mutant contains every counter pin by construction, and the fix is to partition the harness cases

Design §7 requires a pin for "the floor removed", and is explicit that a declared survivor is
not acceptable: "the witness is a mutant that rejects everything."

**A mutant that rejects everything zeroes every counter in the table as well as the floor.**
Its FAIL-record set is a strict **superset** of the record set of every "kind K's draw arm
removed" mutant, so all 96 counter pins are also satisfied by it — "a signature two
mutations produce", and the nesting is **by construction**, the same shape as the
widening/deleting pair AGENTS.md records. The miniature of it is already measured: the
compile-inversion mutant's output contains, besides its 40 agreement records, exactly the
three agreed counters' labels (F11).

**Resolution: partition the harness cases.** The floor and the structural equality go in
their own `harness-case`; the counter loop runs in a **second** `harness-case` entered only
when the floor held. A rejects-everything mutant then fails the floor case and **one**
sentinel in the second case, and produces **none** of the 96 member labels, so every
per-member pin resolves to one record and is not matched by it.

**The cost, stated:** the skip must itself be witnessed, or a defect that always skips is
invisible. The sentinel that closes it reads the **observed** accepted count — never the
counter table's length — and is `(check-equal "the counter pass ran over N accepted machines"
<observed> <measured literal>)`.

Two rejected alternatives, with their reasons: recording the nesting beside the pins is
cheaper and weaker (the per-member pins stay non-discriminating against that one mutant); and
making the floor failure *raise* is refused outright — AGENTS.md prefers a mutation caught by
a failed comparison over one caught by a raise.

### F13 — Pass 39's six mutations, decided by LABEL: four re-anchors, two retirements, and no subsumption anywhere in the pass

All six mutants were applied individually to a throwaway copy of the tree and run under Pass
39's own verify command (`python3 $S/runmut.py`). Distinct FAIL records, with the per-machine
agreement label normalised:

| mutant | exit | FAIL records | distinct checks reddened |
|---|---|---|---|
| `bytetest` (block 1) | 1 | **43** | `machine <N> (seed <S>) byte agreement` ×40; the pause, digit and overflow **agreed** counters |
| `resume` (block 2) | 1 | **1** | `case raised` — the case aborts (`checks=14`, not 89) |
| `pause` (block 3) | 1 | **2** | the agreed and interpreter-only pause counters |
| `eof` (block 4) | 1 | **1** | the idle-completion finish counter |
| `accp` (block 5) | 1 | **2** | the agreed and interpreter-only digit counters |
| `init` (block 6) | 1 | **2** | the agreed and interpreter-only overflow counters |

**The 6×6 subset matrix, computed in both directions over normalised `(case: what)` record
sets, has nothing but the diagonal.** Every one of the six owns exactly one unique record:

| mutant | its unique record |
|---|---|
| bytetest | `machine <N> (seed <S>) byte agreement` |
| resume | `case raised` |
| pause | `the interpreter alone observes a pause` |
| eof | `…256-byte trial observes an idle-completion finish` |
| accp | `the interpreter alone commits a digit` |
| init | `the interpreter alone overflows the field` |

**No subsumption exists in Pass 39 at `f3fbf4e`.** (The suite's own header says otherwise —
F15.)

**The verdicts, one per LABEL:**

**LABEL 1 — `compile: the dispatch byte test is inverted, diverging from the oracle`.
RE-ANCHOR, the PIN only.** `FILE` is `src/byte-machine/compile.sls`, which §4.9's gate holds
unchanged, so `FIND` and `REPLACE` are untouched; the decision — "the emitted dispatch's
`case` key is the source byte, unshifted, so the generated executor agrees with the
interpreter oracle" — is the core property the rewritten lane tests. The pin moves for three
measured reasons: it matches 40 records of its own mutant's output; the label it names is
written by the program this slice rewrites; and the machine count goes to 64, which re-rolls
the seed sequence so machine 0's record changes. **The pin's `got` value and machine index
are re-measured after the rewrite, never carried over.**

**LABEL 2 — `property-differential: resume-pair! stops calling parser-resume!`. RE-ANCHOR —
its `FIND` RELOCATES.** `(list (parser-resume! pr) (parser-resume! pg))` is the whole body of
`resume-pair!`, and the pause protocol moves into `(byte-machine test property-driver)`.
After the rewrite the text occurs **0 times** in `property-differential-tests.sps` and
`MutationRunner.cmake:342-350` fires ("pattern occurs 0 times … expected 1"), counted as
UNCAUGHT. `FILE` becomes the driver library's path and `FIND` re-anchors onto the driver's
**single** resume site.

*Two flags this re-anchor carries.* First, the `REPLACE` names a construct the rewrite
re-contracts: `(list 'feed-ready 'feed-ready)` hard-codes the *feed*-pause ack, and today the
lane never reaches a finish pause — the program says so in its own comment ("a byte-reachable
pausep's continuation is always 'start"). §4.4 draws pause continuations freely, so the new
driver **can** reach `paused-finish`, and then the `REPLACE` changes two things at once (no
resume *and* the wrong ack) and the mutant falls into the acks-disagree branch rather than
the lifecycle violation the pin names. The `REPLACE` echoes the ack the real call would have
returned, or drops the ack by a form the driver treats as "resumed". Second, §4.4's trial has
**three** pause points (the feed loop, the finish loop, the post-reset feed); if the rewrite
inlines the resume at each, the `FIND` occurs 2 or 3 times and `SITES` fails in the other
direction. **Keep the single helper.**

*And one form flag.* This mutant is caught by a **raise**, not a comparison: the case aborts
at machine 0 with `code: lifecycle-violation who*: parser-feed! detail: (paused-feed feed)`
and `checks=14` against the baseline's 89. Because the case aborts it emits **none** of the
anti-vacuity records, so it can never collide with a counter pin — and equally, any pin that
relies on a counter being reddened is invisible under it. If the new driver catches the
lifecycle violation (as a three-layer comparison probably should), the pin is re-measured
from scratch.

**LABEL 3 — `machine-gen: the pause draw's coin is hard-wired to false`. RE-ANCHOR** onto the
pause row of the new kind-draw table. The decision — "the generator actually draws pause
nodes" — still exists and design §7 names its successor directly ("each kind's draw arm
removed (its counter reads zero)"). New `FIND`: the `pause-node?` / `make-pause-node` row,
named as a construct; new `REPLACE`: that row removed from the table — **not** a `#f`-style
hard-wire, which no longer exists. It becomes a *member of the thirteen-pin family*, not a
special case, and is counted in the additions arithmetic. **The new pin must not be `"observes
a pause"`** (F14); the measured separating form today is `"the interpreter alone observes a
pause -- expected a true value"` → 1/0/0/0/0/0.

**LABEL 4 — `machine-gen: the eof draw's coin is hard-wired to false`. RE-ANCHOR** onto the
EOF-route draw's member list. New `FIND`: the route vector containing the finish member; new
`REPLACE`: the same list with the finish member removed. The shipped pin `"idle-completion
finish"` is measured **clean** today (1 on its own mutant, 0 on every other of the six,
including `bytetest`); keep those words if the rewritten label keeps them, else pin the new
label's full text plus the detail.

*Nesting hazard to measure before pinning.* Two different mutants can zero the same counter:
the `finish-node?` **kind** draw arm removed, and the finish **member** of the EOF-route set
removed. `machine-gen.sls`'s own header says why they may be the same thing — "done (finish)
joins the graph only when drawn as the entry eof-target, so it is never byte-reachable
(§16.2:908 holds by construction)" — and F7 says the same from the census side: the EOF route
is the *only* accepted producer of a reachable finish. **If the plan writes both pins, Task 11
Step 3 measures the subset relation in both directions.** They may be nested by construction,
in which case one is kept and the nesting is recorded beside it, in the tree, named by LABEL.

**LABEL 5 — `machine-gen: the pinned accumulate case advances instead of reexecuting`.
RETIRE.** The construct is gone (no `accp`, no pinned case, every inbound mode drawn), and so
is the decision — which is *the mutation's own stated reason*: "byte-trial feeds ONE byte to
a fresh pair. Advancing consumes it at the dispatch, so `accp` is entered with the slice
already exhausted." §4.4 keeps the 256 single-byte trials **and adds** eight drawn inputs of
length 0–6 under every split point, so an `advance` inbound edge leaves the accumulate node a
byte to read and the digit arm runs either way. The premise that made `reexecute`
load-bearing is removed by the rewrite, and no construct in the new generator carries the
decision. AGENTS.md: "only one a later fix makes unobservable is retired."

**LABEL 6 — `machine-gen: the accumulate field's initial is one below the only workable
value`. RETIRE.** `(make-uint-field 'n 8 25 #f)` is gone: §4.4 draws one or two uint fields
at drawn widths and drawn initials, so there is no chosen constant to move by one.

*Why it is not a re-anchor, stated so nobody spends a cycle discovering it.* The obvious
re-anchor is "force the drawn initial to a constant", and neither direction names the same
decision: forcing it to `0` does **not** zero the overflow counter (six base-10 digits
overflow a u8 from 0, and §4.4 draws inputs up to six bytes), and forcing it to
`(- (expt 2 width) 1)` zeroes the **commit** counter instead, which is LABEL 5's territory.
Either would be a **new** pin with a new decision and must be declared as an addition, not a
re-anchor. Task 9 Step 6 *runs both* and records what they do, so the tombstone's refusal is
measured rather than argued.

**Both retirements carry the staged-deletion discipline AGENTS.md requires** — the sweep
cannot see a retirement, and "another fixture already witnesses it" is a coverage claim, not
a collision claim. Task 9 Steps 4–7 stage the deletion, measure which mutants still redden
the check the retiring one owned, measure whether the replacement separates the arm at all,
and refuse the retirement if either measurement comes back empty. **Stage first** — `git add
-A` the deletion *before* applying any mutation by hand, because `git checkout --` to undo a
hand-applied mutation wipes the task's own unstaged implementation.

**A census correction.** Decision 0033's Consequences say "four of the six `FIND` text in
`machine-gen.sls` that the rewrite deletes". Four is right about `machine-gen.sls` (measured:
`rg -c "FILE test/support/harness/byte-machine/test/machine-gen.sls" …` → `4`) and understates
the coupling: mutation 2's `FIND` is in `property-differential-tests.sps`, which this slice
also rewrites. **Five of the six `FIND`s are in files this slice rewrites**; only mutation
1's, in `compile.sls`, is in a file the gate holds unchanged.

**And the census is by FILE, not by SPEC.** Lexing the whole suite with a single
left-to-right scanner that skips `#` comments, `#[=[…]=]` bracket comments, `"…"` strings and
`[=[…]=]` bracket arguments: **526** `byte_machine_mutation` calls, of which 4 in
`machine-gen.sls` and 1 in `property-differential-tests.sps`; **no variable-`FILE` block
expands to either file** (all six variables resolve to `harness.sls`, `fingerprint.sls` or a
launcher). A SPEC-only census would have found the same five here — but that is luck, not
method, and Task 1 Step 5 runs it by FILE.

### F14 — the shipped pin `"observes a pause"` matches **two** records of its own mutant's output while two comments in the tree claim it is unique

`SchemeMutationSuite.cmake:537-542`:

> Pinned to "observes a pause", the assertion's own words and otherwise unused in this
> program.

and the mutation's own comment at `:8613`: "Pinned to the assertion's own words, unique to
this one check."

Measured:

```
rg -n 'observes a pause' test/common/property-differential-tests.sps
277:                                      " generated machines' 256-byte trial observes a pause")
312:                (check "the interpreter alone observes a pause"
```

and with the mutation applied:

```
FAIL …: at least one of the 40 generated machines' 256-byte trial observes a pause -- expected a true value
FAIL …: the interpreter alone observes a pause -- expected a true value
>>> len(re.findall("observes a pause", out, re.DOTALL))
2
```

This is AGENTS.md's `check-labels-as-substrings-of-every-pin` trap live on the branch's own
base, in its second shape — *an old pin matching two records of its OWN mutant's output*,
which only a per-pin match-count sees: the lane is green, the mutation reports **caught**
(`MATCHES` asks whether, not how many), and the two-direction sweep is clean.

It was introduced by the very check that closed the subsumption F15 describes: Milestone 4
Slice ③ added `"the interpreter alone observes a pause"` — a superstring of a shipped pin —
into the same program, and neither the pin nor its two comments were re-read. The sibling
pins escaped only because they are written as **full labels plus the detail**.

**This slice is the first that can fix it, because it rewrites that lane**, and it does:
LABEL 3's re-anchored pin is a full label plus ` -- expected a true value` on the
interpreter-only half, and the two false comments are corrected in place (Task 9 Step 3).

### F15 — the mutation suite's own pin re-audit still files the p39 pause/eof pair as SUBSUMED; measured, neither is

`SchemeMutationSuite.cmake:1398-1411`:

> \# (a) SUBSUMED -- ten pairs. The narrow mutation's ENTIRE failure set is a
> \# subset of the broader one's … there is no text in the narrow mutant's output that is
> \# not also in the broad one's.
> \#   …
> \#   p39 pause draw, eof draw              < inverted dispatch byte test (two)

and the amendment at `:1453-1456` that deliberately leaves it standing: "Nothing here
re-measures the p32/p39 lanes, whose entries above stand as written."

**Measured at `f3fbf4e`, whole-set, both directions** (F13's matrix): `pause` emits `the
interpreter alone observes a pause`, which `bytetest` does **not**; `eof` emits `…observes an
idle-completion finish`, which `bytetest` does **not**. Neither is subsumed.

**Why it drifted, and why it matters here.** Milestone 4 Slice ③ added the three
interpreter-only counters — which is exactly the remedy lines 1483-1489 of the same header
say was **declined** ("Counting the oracle's own pause instead would separate them, but it
would weaken what the guard asserts"). The remedy shipped, it did **not** weaken the agreed
guard (both halves are asserted), and the header was never amended. A plan author reading the
header would conclude the pause and eof pins cannot be separated from the byte-test pin and
would re-ship them under-anchored.

**Task 9 Step 3 corrects the entry in place, dated, keeping the retraction** — a correction is
a record too, and the failure is the instructive part — and notes that lines 1483-1489's
"still declined" describes a remedy the tree already contains.

**One more cross-lane measurement, and the reason it does NOT widen any pin's collision set.**
A `compile.sls` mutation declared under a *different* SPEC **can** redden this lane's
anti-vacuity counters *when the property program is run by hand*: applying `compile: an error
declaration is resolved by code alone` (Pass 46) and running the **property** program gives
`exit=1, 14 FAIL records`, including the overflow counter.

**But a pin is only ever matched against its own pass's verify-command output, and that closes
the cross-SPEC direction by construction.** Measured: `byte_machine_mutation_run_spec` uses
`BYTE_MACHINE_MUTATION_VERIFY_COMMAND` whenever it is set and **ignores the mutation's `SPEC`
entirely** (`MutationRunner.cmake:164-170`); the variable is `set()` **48 times** in
`SchemeMutationSuite.cmake` and **never unset**, so every pass has one; and
`--program …/property-differential-tests.sps` appears **exactly once in the whole suite**, in
Pass 39's verify command at `SchemeMutationSuite.cmake:8567`. A `compile.sls` mutant declared
under another SPEC therefore never produces a property-lane record in its captured output, and
no Pass 39 pin can be satisfied by it.

**This plan records that as the reason and keeps the measurement as a note** — the alternative
was to ship "the sweep must judge these pins against the `compile.sls` mutants too" as a
required exit criterion resting on a premise the runner contradicts, which is another false
supporting argument for a correct precaution: exactly the defect F20, F14 and F15 correct
elsewhere. Task 11 Step 3 is re-stated accordingly: it asserts the **two literals above**
(`:8567` is the only verify command running this program; `:164-170` is why that settles it)
and runs the hand measurement once, as evidence, not as a gate. (The comment justifying that
Pass 46 mutation says the property lane is blind to it because "machine-gen.sls fixes two
declarations with distinct codes" — measured, it fixes **three**, two of which share the code
`unexpected-byte`. A false supporting argument for a correct decision; corrected in place with
its twin at `test/common/position-kind-tests.sps:439`.)

### F16 — the arithmetic: `EXPECTED_MUTATIONS` closes exactly today, and the new value is a formula in (retirements, additions)

```
rg -o 'byte_machine_mutation\(' test/support/cmake/SchemeMutationSuite.cmake | wc -l      -> 530
rg -n 'byte_machine_mutation\(' … | rg -v '^[0-9]+:byte_machine_mutation\($'               -> 4 lines: 9817 10041 10165 12602
rg -o 'byte_machine_mutation_run\(' …  | wc -l                                             -> 48
rg -c '^byte_machine_slice3_launcher_pass\(' …                                             -> 9
rg -c '^byte_machine_slice5b_launcher_pass\(' …                                            -> 3
```

- **530** raw occurrences; **−3** inside `#` comments (9817, 10041, 10165); **−1** inside a
  `message()` string (12602) = **526** real blocks, independently confirmed by the lexer,
  which skips both constructs.
- **−2** blocks inside the two wrapper-function bodies = **524** standalone.
- **+12** wrapper expansions (9 + 3).
- **524 + 12 = 536 = `EXPECTED_MUTATIONS`. Exact.**
- Passes: 48 occurrences, none in a comment or string, **−2** indented calls inside the two
  wrapper bodies = 46, **+12** expansions = **58 = `EXPECTED_PASSES`. Exact.**

**The new value:**

```
EXPECTED_MUTATIONS_new = 536 − R + A
EXPECTED_PASSES_new    = 58                (unchanged — this slice opens no new pass)
```

with **R = 2** (LABELs 5 and 6; a re-anchor never counts, it keeps its slot), giving
`534 + A`.

**Passes stay at 58 iff the slice adds no `byte_machine_mutation_run(` call.** Slice ② joins
the existing Pass 39, for the reason Slice ③ Task 6 did (`SchemeMutationSuite.cmake:492-503`:
"Pass 39 already runs this same program under this same verify command … so a second
reset/baseline/re-stage for the identical spec would only pay the suite's most expensive
lane's cost twice for no new discrimination"). **Because it JOINS Pass 39 rather than opening
a new pass, the new blocks go BETWEEN Pass 39's `byte_machine_mutation_reset()` (`:8559`) and
its `byte_machine_mutation_run(…)` (`:8666`)** — the general "after the previous pass's
`byte_machine_mutation_run`" rule is the rule for a **new** pass, and applying it to a join
would put the blocks between `:8666` and the next pass's `reset()` at `:8669`, where that
reset discards them. Task 10's preamble carries the measurement and both failure modes.

**`A`, itemised from design §7's own list — each an entry Task 10 must price, not a promise:**

| new-pin family | count | note |
|---|---|---|
| the verifier filter dropped (rejected draws executed) | 1 | caught by the structural count, by comparison and not by a raise |
| each kind's draw arm removed | **13** | the `SITES` trap of F17(b) applies to every one |
| each matcher's draw arm removed | **4** | same |
| the script answering `continue` unconditionally | 1 | the branch and failure counters |
| the split-point sweep collapsed to one feed | 1 | the schedule counter |
| an invariant's comparison inverted | **6** | one per Layer-3 row |
| the floor removed (a mutant that rejects everything) | 1 | F12 |
| the re-anchors (LABELs 1–4) | **0** | re-anchors keep their slots |

A lower bound of `1 + 13 + 4 + 1 + 1 + 6 + 1 = 27` gives `536 − 2 + 27 = 561`. **The nesting
measurements can reduce it** (LABEL 4's note, and every per-kind arm against the
verifier-filter mutation), so **`A` is fixed by measurement, not by this table** — design §11
is explicit that "the rule fixes a partition, not a count". Task 10 Step 9 writes the
measured number and `EXPECTED_MUTATIONS` is re-measured from the harness rather than computed.

**The header narrative.** `EXPECTED_PASSES` / `EXPECTED_MUTATIONS` sit under a ~200-line
running narrative (lines ~1180–1362) read newest-first. Slice ②'s entry goes at the **top**
and states the retirements separately from the additions, in the form the file already uses:
`"Milestone 7 Slice ②: … TWO removed (their decisions no longer exist; tombstones at the
site), <A> added. Mutations 536 − 2 + <A> = <N>."`

**And the banner is stale, and this slice is its natural receiver.**
`SchemeMutationSuite.cmake:9` reads `# FIFTY-FIVE PASSES, BECAUSE FIFTY-FIVE DIFFERENT
WITNESSES ARE NEEDED` against `EXPECTED_PASSES 58`, with a second differently-stale citation
at `:177` ("See \"FIFTY-FOUR PASSES...\" above"). The banner's own text names the defect:
"a banner left at the old number is the one surface no test can check." It is an
instruction; Task 9 Step 8 corrects it in place.

### F17 — the `SITES` trap fires in both directions, and this slice writes thirteen near-identical arms

`MutationRunner.cmake:342-350` counts the `FIND` literally over the **pristine** file and
fails when the count is not the declared `SITES` (default 1). Duplication is therefore a
within-one-file hazard, and this slice creates it three ways:

**(a) The shipped direction, "found 0, expected 1".** All four `machine-gen.sls` `FIND`s are
deleted by the rewrite; none of the four texts can plausibly reappear (`accp`, `pausei`,
`eofi` and the `'n 8 25` triple all go).

**(b) The new direction, and it is AGENTS.md line 348's trap in the exact shape it names.**
§4.4 asks for **thirteen** near-identical kind-draw arms, **four** matcher arms, **seven**
field operations, **seven** field predicates and **four** callback kinds, and design §7 wants
a pin per kind and per matcher. **Any `FIND` that is a single line of a shared arm skeleton
will occur 13 (or 4, or 7) times.** The rule, as a Global Constraint: every per-arm `FIND`
contains the arm's **own discriminating token** (the kind name, the matcher name, the
operation symbol), and the arms do not share a `let`-binding vocabulary that makes a one-line
anchor ambiguous. The precedent that earned the rule: Milestone 3 Slice ③ drafted
`pass-sequence-ambiguity` as a structural clone of `pass-overlap`'s `node-overlaps` and broke
three shipped mutations pinning single lines of that skeleton — *the fix is to rename the new
function's bindings, never to widen three shipped `FIND`s.*

**(c) Two-lane symmetry.** Every construct in the driver exists twice, once for `pr` and once
for `pg`. Any `FIND` written without a lane-discriminating token risks a count of 2.

### F18 — the driver's shape: a functional core, a steering **parameter**, and a declaration manifest the graph façade cannot supply

**The driver calls no `check` and imports no harness.** It returns values; the lane and the
fixture assert. Four reasons, in order of weight: the project's functional-core/imperative-
shell standard; the three consumers assert differently (the lane asserts 64 machines and 96
counters, Slice ③'s fixture asserts one trial, the minimizer asserts nothing and needs a
boolean oracle); no test-support library imports the harness today, so making the driver the
first adds a manifest-ordering constraint for no gain; and a pure verdict is directly
testable while a pin can anchor on the lane's label without that label living in a second
file. The one place the driver needs I/O is `emit-and-load` (and, in Slice ③, the saver), and
that seam is named and isolated.

**The steering is a parameter, from the first commit.** Design §4.6 says the independent
oracle runs "§4.4's generator **with its structural steering off**", while §4.4 and §7
describe a single fixed draw with the steering baked into the prose. If the steering is baked
in, Slice ④ cannot run §4.6 at all. `gen-machine` therefore takes a **steering record**
argument, and that single requirement resolves most of F3's tension: whatever the property
lane steers around, the free mode still produces, and the ledger keeps it.

**`(byte-machine graph)` exports no machine accessors at all**, and its header says so on
purpose: "Machine ACCESSORS stay private: §9.1 fixes a construction surface, and reading a
built machine back is not part of it." The shipped generator already works around it by
threading `fnames` out of `gen-machine`. At Slice ②'s scale the driver needs much more — the
field names **and widths** (Layer 3 row 4's `[0, 2^width)` needs the width), the callback
declarations (name, kind, `required?`, keys, default), the span declarations, and the decoder
mapping a node name back to the kind that was drawn. Three options, priced:

1. thread a **draw manifest** out of `gen-machine` — cheap, but it is the generator's *claim*
   rather than the machine's *content*, which is F10's "reads the draw" hazard one level up,
   and it gives Slice ③'s printer nothing;
2. **import `(byte-machine private ir)`** in the driver — precedent in four shipped test
   programs (`kind-position-census-tests.sps`, `graph-tests.sps`, `interpret-tests.sps`,
   `ir-tests.sps`), and `ir.sls` is already in both lane manifests inside
   `BYTE_MACHINE_CORE_PRIVATE` → `CORE_ALL` → `CORE_EMIT`, so **no CMake change is needed**;
3. widen `(byte-machine graph)`'s exports — a `src/` change. **Ruled out by §4.9's gate.**

**This plan takes (2) for the machine's content and (1) for the decoder**, and says which is
which. The decoder — a `name → (family . member)` alist the generator returns — is legitimate
under 0033 ("a state name reached"): *the observation is that the trial reached that name; the
alist only says what that name was drawn as.* It becomes the forbidden shape the moment a
counter increments without a trial producing the name.

**The totality rows live in the property program, not in the generator** — §4.10's placement,
against §7's ("its own totality rows" in `machine-gen.sls`). Two reasons: a row inside a
library must read a file at run time and its failure is a **raise**, not a harness comparison;
and §4.10's operand structure is the one that works. The generator's draw tables are
**hand-written tables in `machine-gen.sls`, exported**, and the row derives `ir.sls`'s set and
compares it to those keys — the S2 precedent exactly, whose operand argument
`milestone-5-slice-1a-implementation-plan.md` records: "the derived set is compared against a
mapping **declared in the test**, so a mutation whose `FILE` is `verify.sls` stages a mutated
verifier beside an unmutated test and the two sides disagree. The row is a mutation witness."
**If the generator drew from the runtime-read list instead, the row would compare `ir.sls`
against `ir.sls` and close nothing.**

**The callback-kind `memq` has no shipped extractor.** Two extractor shapes ship —
`kind-predicates-in-source` (an `(or …)` inside a `(define (P x) …)`) and `defined-list`
(a `(define NAME '(…))`). The callback-kind set is `(memq kind '(event decision span-data
span-complete))` inside `make-callback-declaration`'s body, and `rg -n "'memq" test/` prints
**no matches**. §4.10 promises a totality row for a shape no mechanism can read. The plan
**owes a third extractor** — walk to the named `define`, then find the `(memq VAR '(…))` form
in its body — with its own seeded "found it" guard on the `diagnostic-census-tests.sps`
precedent. Promoting the three `memq` sets to `(define NAME '(…))` in `ir.sls` would be
simpler and is a `src/` change; **§4.9's gate forbids it.**

### F19 — §4.4's schedule list drops `§22.5:1282` and narrows `:1279`, against a tree that implements both

§4.4: "eight drawn inputs of length 0-6 driven under every split point, **leading and
trailing empty feeds**, one sub-slice, one padded bytevector, and four seeded multi-split
schedules — `§22.5:1278-1283`".

The spec, verbatim:

| line | bullet | in §4.4's list? |
|---|---|---|
| 1278 | test every single split point | yes |
| 1279 | include leading, trailing, **and intermediate** empty feeds | **partly** — "intermediate" dropped |
| 1280 | feed through nonzero bytevector start/end indices | yes |
| 1281 | reuse larger bytevectors containing unrelated prefix/suffix bytes | yes |
| 1282 | **test selected pairs of split points for short messages** | **no** |
| 1283 | test deterministic random multi-split schedules | yes |

**The tree contradicts the omission at three sites.** `differential-span-tests.sps` drives
`span-splits` 6 + **`span-pairs` 21** + `span-others` 10 = 37;
`differential-callback-tests.sps` 5 + **15** + 10 = 30; `differential-counted-span-tests.sps`
7 + **28** + 10 = 45. Pairs are **50–62% of every shipped schedule set** — measured, callback
**15/30 = 50.0%**, span **21/37 = 56.8%**, counted-span **28/45 = 62.2%**; the decompositions
themselves reproduce exactly (`differential-callback-tests.sps:744` reads "5 single splits +
15 pairs + 10 others"). Each `others`
list carries an intermediate empty (`(list (list pay 0 2) (list nothing 0 0) (list pay 2 6))`).

**Impact:** a driver built from §4.4's prose alone would ship a *narrower* schedule sweep than
the fixed-machine lanes it generalises, and `§25:1626` would be discharged over a smaller
oracle than the tree already has. **The closed list of schedule shapes is six, not five**,
because the only enumeration in the tree is §22.5's six bullets and the counter family's
totality row must compare against a list the spec does not contradict. §4.4 is corrected in
place (Task 12); the cost is one counter pair (2 checks) and a pairs generator the driver owns
once for all three shipped triples.

**And the sixth bullet's implementation deliberately departs from the tree.** All three
shipped lanes write their `:1283` schedules as **literals**, with the comment "§22.5's
'deterministic random' bullet is about reproducibility, and a literal is the most reproducible
form there is". §4.4 makes it "finally random and printed". That argument is being overturned,
and the plan says so rather than letting it look like an oversight.

### F20 — adding `property-driver.sls` is three edits, not a manifest zoo; and one comment's stated reason for the manifest's order is false

**The complete set of build inputs that name `machine-gen.sls` today, and therefore the
complete set the new library must join:**

| # | location | what it is | must the new file appear? |
|---|---|---|---|
| 1 | `test/CMakeLists.txt`, `SOURCES` of `…chez.source` | provenance manifest + fingerprint input | **YES** |
| 2 | `test/CMakeLists.txt`, `SOURCES` of `…chez.aot` | same, and the `fingerprint/` copy | **YES** |
| 3 | `test/common/property-differential-tests.sps`'s `(import …)` | the library name | **YES** |

**There is no fourth category**, and each negative is measured: **no AOT compile list** (the
aot custom command's dependency list is a `file(GLOB_RECURSE …)` over both library roots, and
compile order is Chez's — `(compile-imported-libraries #t)` + `(compile-program …)` follows
the **import graph**); **no separate fingerprint manifest file** (the expectation is *derived
from* `SOURCES` by `byte_machine_expected_fingerprint`, keyed by a SHA-256 of the joined
list); **no mutation stage list naming files** (`BYTE_MACHINE_MUTATION_STAGE_DIRS` names
directories and `file(COPY)` copies each whole, so a new file under `test/support/harness/` is
staged with no edit, and Pass 39's verify command names roots); **no `.gitattributes` entry**
(`* text=auto eol=lf` covers it).

**The three silent failures, each measured, which is why the two `SOURCES` edits are not
optional and must be at the same index:**

| omission | source lane | AOT lane |
|---|---|---|
| left out of **both** | loads fine; the combined fingerprint never covers the driver. **Nothing goes red.** | the `GLOB_RECURSE` was taken before the file existed, so no reconfigure is forced and the `.so` may run **stale driver text** while the source lane runs the current text. **Nothing goes red.** |
| left out of **one** | the two lanes get different manifest keys and no longer visibly claim to run the same text | same |
| present at **different indices** | different combined values ⇒ different keys ⇒ two expectations | same |

**And the comment a plan would naturally cite for the placement states a false reason.**
`test/CMakeLists.txt:153-160` and `:756-758` both say a library is listed early "so the AOT
lane compiles it before anything that imports it". Traced through the module, `arg_SOURCES`
reaches exactly **five** places (`cmake/ByteMachineSchemeLane.cmake` 347, 359, 387, 403, 444) —
the existence guard, the duplicate-basename guard, the measured list
(`BYTE_MACHINE_FINGERPRINT_FILES`), the expectation, and
`byte_machine_lane_chez_aot_artifacts`, which is a **fifth fingerprint consumer** (it drives the
`copy_if_different` into `${object_dir}/fingerprint`) and not a compile step: the compile takes
`file(GLOB_RECURSE chez_library_sources …)`, never `arg_SOURCES`. So the substantive claim
stands — **no compiler invocation receives it** — and the count is five, in a finding whose
whole force is that it was traced. The real reason order matters is recorded correctly elsewhere
(`ByteMachineSchemeLane.cmake:106-108`, `fingerprint.sls:67-69`): it is the **fingerprint**,
not the compiler. This plan places `property-driver.sls` immediately after the
`machine-gen.sls` line in both lists and cites the fingerprint, not the compile order.

**And one thing `SOURCES` membership does NOT cost, said here because the plan spends a page on
the fingerprint and Pass 39 mutates two files that are already in these manifests.** AGENTS.md's
W9 rule — "keep a pass's provenance manifest off the file it mutates, unless self-reference is
the declared mechanism" — has as its failure mode a mutation reported caught by a generic
fingerprint mismatch rather than by its own decision. It is **inert here, for a measured
reason**: `harness.sls:709-722` and its guard at `:727` treat an unset or empty
`BYTE_MACHINE_FINGERPRINT_FILES` as "this process was not started by a lane registration" and
skip the check, and Pass 39's verify command (`SchemeMutationSuite.cmake:8561-8567`) invokes
the launcher directly and sets **no such variable**. So the fingerprint check is **inactive
under the mutation lane**, and a mutation to a manifest member is still discriminated by its own
label. `machine-gen.sls` and `property-differential-tests.sps` are already in both manifests and
already mutated; `property-driver.sls` joins them on the same terms.

**Two additions the design's CMake bullet does not name, and the second is blocking.** Both
registrations gain `ENVIRONMENT "BYTE_MACHINE_SOURCE_ROOT=${CMAKE_SOURCE_DIR}/src"`, because
every totality row reads `ir.sls` as a datum and every shipped datum reader **raises** when
that variable is unset. `rg -n 'BYTE_MACHINE_SOURCE_ROOT' test/CMakeLists.txt` prints **five**
lines today — four `ENVIRONMENT` lines (1664, 1674, 1693, 1703), all on the two census lanes,
and one comment (1654); the property registrations carry **no `ENVIRONMENT` line at all**. Under the mutation suite the variable is already set
process-wide (`SchemeMutationSuite.cmake:1509`), so **the failure appears only in the ordinary
CTest run and not under the mutation suite** — the harder direction to notice. And this does
**not** contradict decision 0033 item 3's "The registrations pass nothing": that clause is
about the **seed**, and the plan says so explicitly so a reviewer does not read a conflict.

### F21 — the timeout, and two numbers the tree records as expectations rather than measurements

`TIMEOUT 180` on both registrations. Measured today, the source lane end to end — 40
machines, emit + `load` + `eval` of a generated library each, both lanes, 256 bytes each, 89
checks:

```
/usr/bin/time -p … --program test/common/property-differential-tests.sps
-> real 0.30   user 0.26   sys 0.02
   summary … cases=2 failed-cases=0 checks=89 failures=0 … status=0
```

**0.31 s against 180 — a factor of 580.** The cost model, measured by differencing three
runs: process start + library expansion ≈ **0.20 s**; per emit + `compile-machine` +
`emit-machine` + `load` + `eval` ≈ **1 ms**; per single-byte trial ≈ **3 µs** for the pair.
Scaling §4.4's bounds — 64 emissions ≈ 0.06 s, 64 × 256 single-byte trials ≈ 0.05 s, plus
64 × 8 inputs × ~50 schedules ≈ 25 600 multi-step trials — predicts a source-lane total well
under 2 s even at 20× today's per-trial cost. **Emission still dominates, exactly as §4.10
says.**

**So the source registration keeps `TIMEOUT 180`**, and the plan says why rather than
re-deriving it: there is no evidence it needs raising and none that it can safely be lowered,
and lowering it would be a new decision. **The AOT registration is the one design §7's "the
timeout is measured, not guessed" is about** — it *compiles* rather than loads, no measurement
of it exists anywhere in the tree, and none of the eight reports could take it without writing
into the build tree. **Task 8 Step 4 measures it.**

**Two numbers this plan will not restate as measured.** `58 passes / 536 mutations` is a
**declared expectation** (`SchemeMutationSuite.cmake:1363-1364`) that the lane asserts at run
time; `rg -n -F "536 mutations" --glob '!build/**' .` returns **nothing**. And the newest
recorded `114/114` is Slice ⓪'s close note (2026-09-07), before Slice ① landed; Slice ①'s
Verification list still reads "predicted **536**; write the recorded number here, because 'as
measured' cannot fail" and the instruction was not carried out. **Task 1 Step 7 re-measures
both** and this plan's Verification section writes the recorded numbers.

*One timing source that looks like one and is not:*
`build/dev/Testing/Temporary/CTestCostData.txt`'s third field is CTest's exponentially-decayed
cost estimate, not seconds — it gives `0.539` for the mutation lane, which takes minutes. Do
not quote it. And the build tree's `LastTestsFailed.log` currently holds a failed mutation
lane from 2026-09-10: **treat the build tree as untrusted and reconfigure before measuring.**

### F22 — the design's Status header is stale, the parent plan's Status line is too, and a status line is an instruction

`docs/plans/milestone-7-design.md:4` still reads:

> Slice ⓪ delivered 2026-09-07 (PR #89); **Slice ① next.**

Slice ① merged as PR #92 on 2026-09-11 (`231f429`), and its own plan's Task 7 Step 2
instructed that correction. The commit updated `README.org` and `CHANGELOG.md`; the design's
header did not make it. `docs/plans/byte-machine-implementation-plan.md:3` stops at Slice ⓪
while `:2493` of the same file carries the full 2026-09-10 Slice ① disposition.

**This plan's documentation task corrects both in place** (Task 12 Steps 5–6). A status line
is an **instruction**, not a record: it tells the next reader what to do next, and one that
names a slice already merged sends them to the wrong work. This is the fourth consecutive
slice in which a status surface drifted, and the surfaces AGENTS.md enumerates are five — the
milestone plan, the parent plan, `CHANGELOG.md`'s `[Unreleased]` preamble, the milestone's
design document, and `README.org`. Task 12 Step 6 walks all five by name.

### F23 — decision 0033 item 5's invariant table carries two contradictions the driver would transcribe into defects, and five citations in the tree resolve to the wrong line

**Contradiction 1 — the `stopped`-from-`parser-finish!` qualifier.** 0033 item 5 row 1 says
"a `stopped` from `parser-finish!`, **which no row permits**, is a `§16.2:909` hole and is
reported as one." `§12.2:695` is the `stopped` row and its `finish!` cell reads **`Return
`stopped``**. The shipped runtime does exactly that, in `parser-finish!`'s sticky arm:

```
runtime.sls:1120      ((stopped) (make-parser-result 'stopped (parser-offset parser) 0
runtime.sls:1121                                     (parser-offset parser) #f))
```

What 0033 *means* is a `stopped` from a **running** `parser-finish!` — `lifecycle-before`
`ready` (`§12.2:691`, "Begin EOF processing") or `finish-ready` (`:694`, "Continue EOF
processing"), neither of which names a `stopped` status, and `§12.4:729` says EOF "must
terminate in `finished` or `error`". **The Layer 3 row 1 assertion is keyed on
`(lifecycle-before, operation)` and the hole is the pair `(ready | finish-ready, finish!) →
stopped`.** Written as 0033 words it, the driver reports a hole on **every legal sticky
finish of a stopped parser** — a transcription trap the record's own sentence sets.

**Contradiction 2 — the span row asserts a comparison against a value the API does not
expose.** Row 6 compares a span's fragments against "the input bytes the span covered", and
design §4.4 words it "between the span's **start** and end offsets". `§14:830` ("Starting a
span records the current cursor") is the only sentence defining the start, **and neither
Source column cites it** — because there is nothing to observe: `§10.4:514-517` declares a
span-data callback and an *optional* span-complete callback and **no start callback**;
`parser-active-span` answers only the **name**; `byte-machine-span-open/v1` writes the mark
into a private slot and `reserved-member-2` exports no reader. **There is no public
observation of a span's start offset.**

*What is observable, measured, and the three-conjunct form the driver ships instead:*
inside the span-data callback the runtime calls `(callback-commit! parser state offset)`
**before** invoking the callback, so `parser-stream-offset` read there is the fragment's
committed **end** offset; the callback's `from` is a **slice** offset re-anchored every feed
("§14:833 re-anchors the mark at every feed boundary, so it is a SLICE offset and never has
to mean anything between feeds"); and the **driver owns the schedule**, so
`abs_from = offset_before_this_feed + (from − feed_start)`. The row therefore asserts:
(i) **content at offsets** — each fragment's bytes equal the input's bytes at
`[abs_from, abs_to)`; (ii) **contiguity and order** — fragment *k+1*'s `abs_from` equals
fragment *k*'s `abs_to` within one logical span; (iii) **end anchor** — the last fragment's
`abs_to` equals `parser-stream-offset` read inside that span's **span-complete** callback
(`§14:841`: "Before invoking the completion callback, execution makes the span inactive").

**Conjunct (iii) needs a declared and bound span-complete callback, and §4.4 draws one in
half the draws** — so the row needs a **third inapplicability condition** beside 0033's two
(not at an error; not when the span-data callback is unbound): *no bound span-complete
callback ⇒ (iii) is dropped and (i)+(ii) stand.* Neither document says this. It is the single
most load-bearing gap in Layer 3, and Task 5 Step 4 writes it as a named condition rather than
discovering it as a flaky row.

**Two smaller findings in the same table, both settled in the design's favour:**
0033 files `§22.5:1285` under *"Across schedules"* while its own text reads "**for the same
schedule**" — design §4.4 files it under **Layer 1** and the tree agrees
(`differential-span-tests.sps`'s group is "same schedule: the two lanes agree exactly
(§22.4:1269, §22.5:1285)"). The driver's layer boundary is an API boundary — `compare-trial`
takes one schedule, `compare-across-schedules` takes a list — and putting `:1285` in the wrong
one leaves Slice ③'s single-trial fixture unable to check it. And 0033 row 2's Source column
drops `§11.1`, which design §4.4's own table carries: `§11.1:633`
(`0 <= start <= end <= bytevector-length(bytevector)`) is the *domain* half of
`start ≤ next ≤ end` and `§11.5:660-662` is the *definition* half. The plan carries all three.

**One digest in the same row must not be repeated.** 0033 row 2 cites "measured by the
design's review as `finished next 5 consumed 0 offset 5` and recorded in the parent's
`§12.3:711` disposition". `rg -n 'finished next 5|consumed 0 offset 5'` over the design, the
record and the parent plan returns **one hit: 0033 itself**. The parent's disposition records
those values for a **`paused-finish`** result and then broadens the *inapplicability*, not the
values. The **invariant is true** — every `make-parser-result` reachable from
`parser-finish!` passes the offset as `next` and the literal `0` as `consumed`, at fifteen
sites — so the row is kept and the **digest is dropped**: a number without its command is not
admissible, and this one describes a fixture the rewrite deletes.

**The citation drifts, all five, with the disposition of each:**

| citation | resolves to | disposition |
|---|---|---|
| `§22.5:1286` in three shipped comments (`differential-callback-tests.sps`, `differential-span-tests.sps` ×2) and one plan | a **blank line**; the sentence is `:1287` | out of scope — this slice rewrites neither file; **recorded**, not fixed |
| `§12.7:772` in two `interpret.sls` comments (`:378`, `:416`) | a **blank line**; the sentence is `:773`. **`:378` cites the range `:772-773`, which contains it, and is arguably not a drift; only `:416`'s bare `:772` is stale** | out of scope — §4.9's gate forbids touching `interpret.sls`; **recorded**, so nobody reads decision 0030's "Slice ⓪ corrects it there" as "corrected everywhere" |
| `§14:835` in the evidence base for the empty-fragment suppression | `:834`; `:835` is "A logical span may therefore produce zero or more data fragments" | **corrected in this plan** (F5) |
| `machine-gen.sls:83, :96, :120-131` in `SchemeMutationSuite.cmake:10111` as construction sites | none of the three is one; the real sites are 170, 183, 233, 241-242 | **corrected in place** — it is live tooling, and this slice deletes the file it cites |
| `checks=83 failures=30` in the same Pass 47 header | measured **`checks=89 failures=36`** for both mutants | **corrected in place**; the six extra checks are M4 Slice ③'s three accumulate counters and their three twins (83 + 6 = 89) |

**And one framing correction the plan must not repeat.** Slice ⓪ / decision 0031 is a **pure
narrowing** — `occupiable ⊆ R_old` by induction, so `unreachable-node` fires on strictly more
nodes and on no fewer. **Nothing became accepted.** The family `E →(eof) T →(byte) Z` moved
ACCEPTED → REJECTED. The "three machine families become legal" sentence belongs to decision
**0023** (Milestone 5) and 0031 explicitly amends it. The correct statement, for the
generator's header and for Task 12: *Slice ⓪ made this generator's oracle stricter, and the
acceptance rate Slice ② measures is measured against the stricter one.*

---

## 2. What this slice ships

One PR on `feat/m7-slice-2`, **two commits** (design §11): one source commit and one
documentation commit.

*How much of that partition the TREE fixes, stated precisely rather than waved at, because
claiming the tree fixes it when it does not is a false supporting argument for a correct
decision.* The source commit's contents are **not separable**, and the mechanism is measured:
five of Pass 39's six `FIND`s live in the two files this slice rewrites (F13), a stale `FIND`
fails the mutation lane **at declaration** with `pattern occurs 0 times … expected 1`, and
that lane is in the release selection. So the generator, the driver, the rewritten lane
program, the CMake registrations and every pin whose `FILE` the commit rewrites land together
with `EXPECTED_MUTATIONS`, and any split of them is red by construction.

**Two things inside that commit are *not* fixed by the tree and are folded in by
instruction, not by mechanism**, and saying otherwise would be the false argument:

- the **new** pins of Task 10 — adding mutations with their `EXPECTED_MUTATIONS` bump is
  green-to-green and *could* be its own commit;
- the two **retirements** of Task 9 — the same, once their tombstones carry their
  measurements.

Both are folded in by design §11's instruction ("② is **one** source commit unless the plan
finds a green partition"), and this plan does not claim to have found one, because the
partition that exists is not worth a second sweep: AGENTS.md requires the whole pass
re-swept after **each** fix, and two commits would mean two sweeps of a 60-odd-mutation pass.

**Three scoping decisions, settled before this plan was written and recorded here so the next
reader does not re-open them:**

1. **Slice ③ does not fold into Slice ②** (owner, 2026-09-11, closing design §11's open
   question). Design §2's cost, in one sentence: folding would give ②'s task list two tasks
   whose green means something else, because the saver and the minimizer have no oracle unless
   something fails and their test is therefore a *deliberate* failure rather than a
   differential.
2. **Slice ② writes no failure fixture.** Decision 0033 item 4 reads as though the lane saves
   one; 0033's own Consequences hand "the saver (item 4)" to Slice ③ and design §8 puts it
   there, and there is a hard dependency underneath: the fixture's body is "the machine as
   `§9.1` constructor calls", which is `(byte-machine test machine-print)`'s output, and the
   printer is Slice ③'s first bullet. **Slice ② has no printer, therefore no fixture,
   therefore no saver.** What ② ships instead is the driver shaped so ③ can add the saver
   without re-shaping it: `run-machine` takes an explicit `on-first-disagreement` parameter,
   `#f` in this slice, and the "at most once per machine" rule lives in the **driver** — not
   in the lane — because the fixture and the minimizer must see the same rule. **The
   disagreement is reported through the check's own detail** (`check-fail` is the only harness
   assertion whose detail the caller chooses; `check`'s is the fixed string `expected a true
   value` and `check-equal` builds its own), and Task 12 Step 3 records the disagreement
   against 0033 item 4 in the record itself — **otherwise the next reader takes item 4 as
   ②'s obligation.**
3. **The commit partition, above.**

**By file:**

- **`test/support/harness/byte-machine/test/machine-gen.sls`**, rewritten (263 lines today) —
  the declaration draws with the F4(b) key rule and the F4(a) key-space `default-branch`
  draw; the worklist over open slots with the F3 steering set as a **record parameter**
  (F18); the position-aware kind vocabulary (F7); all four matcher kinds; the EOF-route draw;
  the F8 dangling-target and orphan draws; the span pair with F5's `span-body` and F6's
  own-EOF-sink wording; the per-node witness field and the per-arm marker nodes of F9; the
  **exported draw tables** and the draw manifest. (The F8 draws are steering-record members
  whose **property-lane value is `0`** — built and measured here, turned **on** by Slice ④,
  whose §4.6 row they serve.) The nine by-construction validity arguments
  the file's own comments name (H1–H9, not the three 0033 counts) go with their comments —
  and two of them (`done` never byte-reachable, `pausep`'s continuation is `'start`) are
  **re-derived under new names** by `placed`, which is a re-anchoring rather than a deletion
  and is said so at the site.
- **`test/support/harness/byte-machine/test/property-driver.sls`**, new, library
  `(byte-machine test property-driver)` — the schedule alphabet and its six generators; the
  trial (feed, pause protocol, finish, optional reset); the three comparison layers; the
  counters as a pure fold with one label table; the rejection ledger; the emission seam; the
  `on-first-disagreement` hook. **No `check`, no harness import** (F18).
- **`test/common/property-differential-tests.sps`**, rewritten over the driver — the seed
  from `BYTE_MACHINE_PROPERTY_SEED` with the committed default, printed once and carried in
  every machine-level label; `machine-count` 40 → **64**; the accepted/rejected accounting
  with the **floor**; the structural equality of 0033 item 1; the **96** counter checks in a
  second `harness-case` entered only when the floor held (F12); the totality rows; the
  loop-over-loops sentinels; the two-run fingerprint reproducibility case; and the header
  naming `§12.7:770`'s open half as the value this lane cannot see.
- **`test/CMakeLists.txt`** — `property-driver.sls` at the same index in both `SOURCES`
  lists; `ENVIRONMENT "BYTE_MACHINE_SOURCE_ROOT=${CMAKE_SOURCE_DIR}/src"` on both; the
  source lane's `TIMEOUT 180` kept with its measurement beside it and the **AOT lane's
  measured** (F21).
- **`test/support/cmake/SchemeMutationSuite.cmake`** — four re-anchors by LABEL with their
  `REPLACE`s; two retirements with measured tombstones; `A` new pins; `EXPECTED_MUTATIONS`
  re-measured; the header's SUBSUMED entry for the p39 pair corrected, dated, retraction kept
  (F15); the two false `"observes a pause"` uniqueness comments corrected (F14); the stale
  `checks=83 failures=30` and the stale `machine-gen.sls:83, :96, :120-131` citations
  corrected (F14, F23); the `FIFTY-FIVE PASSES` banner corrected (F16).
- **Documentation** — design §4.4's span-pairing sentence, its "private error sink" and its
  schedule list corrected in place with dated notes (F5, F6, F19); design §4.10's "under a
  second" replaced by the measured number (F21); the design's Status header and the parent
  plan's Status line (F22); decision 0033's item 2 exceptions (F10) and item 5's two
  qualifiers (F23) annotated, never rewritten; the parent plan's dispositions appended;
  `CHANGELOG.md`; `README.org`.

**Not shipped, on purpose:** any file under `src/` at all — **not even `verify.sls`** (design
§4.9's gate, and this slice has no reason to touch it); the printer, the fixture or the saver
(Slice ③); the corruption catalogue or the independent oracle (Slice ④); a fix for
`§12.7:770`'s zero-width-machine-action half — the generator **draws that shape** thousands of
times per seed set and every trial passes, and drawing it does not make this slice the
receiver (the receivers are `compile.sls`'s `field-action` arm and `interpret.sls`'s
`field-step`, named in design §4.11 item 7 and written at both constructs); a fix for
`§9.3:392-393`'s `parser-result` enforcement (receiver: the next slice that changes
`make-parser-result`'s shape — the driver carries the feed/finish distinction itself instead);
a widening of `(byte-machine graph)`'s exports.

---

## Global Constraints

- **Authority order.** Decision 0033, then design §4.3/§4.4/§4.10/§7, then the parent plan.
  **Where an authority is wrong, stop and say so**: this plan carries **ten** of its
  instructions being wrong or under-specified — F5 (§4.4's span pairing is under-specified, not
  wrong, and the plan says which), F6 (§4.4's "private error sink" names a slot that does not
  exist), F10 (0033 item 2's "the shipped eight stay" and "each has the two halves" cannot both
  hold, and one of the eight reads the draw the same item forbids), F19 (§4.4's schedule list
  drops `§22.5:1282` and narrows `:1279`), F22 (two stale Status headers), F23 (0033 item 5's
  two qualifiers and five citation drifts), and **four further §4.4 sentences the shipped
  generator contradicts** — "drawn **uniformly**" (Task 6 Step 4's round-robin), "read from
  `ir.sls` **at run time** … the **generator's own** totality row" (F18's exported tables and
  program-side rows, and the design Appendix's "each derived from `ir.sls`" with it),
  "dispatches draw **one to four** cases" (F3 row 2's 1–2), and "in **half the draws**, a
  completion callback" read per span (Task 6 Step 2's machine-level coin). **All ten are
  corrected or tightened in place by Task 12 Step 1.** This matters beyond tidiness: design
  §4.6 defines Slice ④'s independent-oracle drive as "**§4.4's generator with its structural
  steering off**", so a stale §4.4 is the only specification Slice ④ has of the free mode.
  Slice ①'s plan carried two such findings and Slice ⓪'s three.
- **Design §4.9's gate at every step, re-taken at this slice's base**:
  `git diff 5ac363a..HEAD --stat -- src/ ':!src/byte-machine/verify.sls'` prints nothing, and
  — because this slice touches no `src/` file at all — `git diff --stat main..HEAD -- src/`
  prints **nothing** as well. That second command is this slice's own gate and is stated as
  such; one line of output from it means the plan is wrong.
- **No committed golden and no pinned fingerprint literal moves.**
  `git diff --stat main..HEAD -- test/fixtures` prints nothing.
- **The floor is measured, not transcribed** (F2). No rate from any of the three prototypes
  may become the literal. Task 2 is a **gate**: if the measured accepted count under the
  committed seed is below 32, 0033 item 2's own instruction fires and Task 2 Step 8's ladder
  runs before any of Tasks 3–7 lands.
- **A counter reads an observed value from the trial, never the draw** (0033 item 2). Four
  shapes this lane will present, all four forbidden: counting the draw (`(pair? fnames)` —
  shipped, F10; and `differential-sequence-tests.sps`'s `(check "at least one draw was a
  genuine multi-split (>= 2 cuts)" (> multi 0))`, where `multi` is folded from the drawn
  `cuts` — **do not copy it**); counting the loop that *emits* the checks; counting the entry
  (`parser-state-name` on a **fresh** parser is the entry node — measured `fresh-state start`
  — so a state-name counter must sample only **after** at least one operation); and counting
  the decoder by walking the drawn machine's node list.
- **Sentinels read observed values, and every loop carries a literal total and a derived
  total.** The shipped rule, from `differential-span-tests.sps`: "the literal catches a
  schedule list that silently shrank, the derived total catches a loop that stopped early,
  and neither catches the other." The property lane today has **no** loop sentinel at all —
  nothing asserts the 256-byte loop ran 256 times or that the machine loop ran 40. At 64
  machines × ~50 schedules that omission becomes load-bearing.
- **A census-shaped change gets a check total over its census.** Forty-six counter rows, seven
  families, six Layer-3 rows, six schedule shapes: each gets a literal, a derived length, and
  a totality row against its source (F9). Where a totality row cannot be derived — callback
  outcomes, span events, schedule shapes — the program **declares** the list with its `§`-line
  citation and says in the file that it is declared.
- **The pause protocol's guard is the rule that turns a bug into a crash.** Resume is reached
  only once **both** sides agree they paused. A driver that resumes on `(or ref-paused?
  gen-paused?)` converts every lane divergence at a pause into a `lifecycle-violation` raise.
  Measured, this is not theoretical: a first driver that fed one byte and called
  `parser-finish!` without the resume loop raised **941 times over 10 240 trials (9.2%)**,
  every one `(paused-feed finish)`; adding the loop took it to `raised=0`. **~9% of
  single-byte trials on freely drawn machines end `paused`.**
- **A pair that already reached `stopped`/`error` is deliberately not finished** — the shipped
  comment's reason survives verbatim into the driver: "`parser-finish!` on a sticky lifecycle
  short-circuits inside the shared `runtime.sls` wrapper before reaching either executor, so
  that comparison would only check the wrapper against itself." The same applies to the reset
  leg: the reset itself is shared wrapper code; what discriminates the lanes is the
  **re-parse after** it.
- **One recording closure per lane, never shared.** Stated three times in the tree, each time
  as a correction: "Slice ②'s plan asked for one closure shared by both parsers, which yields
  one interleaved list with nothing to compare it to."
- **A fragment is copied inside the callback's dynamic extent** (`§13:799`, `§28:1725`). The
  trace is a list of fresh bytevectors, never of `(bv from to)` triples.
- **`map` is not a feed schedule.** R6RS leaves `map`'s application order unspecified and Chez
  exercises it; every sequenced drive uses `for-each` or an explicit named `let`. `rfields`'
  `map` over field names is fine — pure reads.
- **`SITES` fails in both directions** (F17). Every per-arm `FIND` carries its own
  discriminating token; the resume helper stays single; no `FIND` is written without a
  lane-discriminating token.
- **Every per-member pin anchors on the interpreter-only half's FULL label plus
  ` -- expected a true value`** (F11), and no pin is a bare phrase.
- **Before committing any label, embed it in every pin's literal core and search.** A new
  label that *contains* a shipped pin's regex makes that pin resolve to two records of its own
  mutant's output while the lane, the runner and the two-direction sweep all stay green. Two
  collisions are already loaded: `"observes a pause"` (F14) and the reserved
  `"the same thirteen kinds"` label, on which the shipped ratchet pin "ir: node? admits a kind
  the matrix's table does not cover" is anchored — **the generator's own kind totality row must
  not print those words.**
- **No pin may be a substring of the three unconditional families**: the FAIL-CONTEXT line
  (`backend=`, `mode=`, `os=`, `architecture=`, `machine-type=`, `artifacts=`, and the
  `BYTE_MACHINE_TEST_NAME` / `BYTE_MACHINE_TEST_TMPDIR` values, which make `byte`, `machine`,
  `property`, `differential`, `chez`, `source`, `scheme`, `mutation`, `harness`, `cmake`,
  `direct` unconditional in this lane); the summary line (`status=`, `cases=`, `checks=`,
  `failures=`); and the two banner lines printed at the head of every run.
- **The seed line this slice adds is new stdout on every passing run.** 0033 item 3 requires
  the seed printed once at the suite's start, and **no program under `test/common/` calls
  `display` at all** today. The digits `20260823` will be on stdout of every run of this lane,
  and `EXPECT_OUTPUT_MATCHES` is unanchored: the seed line must introduce no token any pin can
  match.
- **`EXPECT_SURVIVES` is not available for the floor.** Design §7: "a declared survivor is
  *not* acceptable here — the witness is a mutant that rejects everything."
- **Prefer the comparison catch.** Every new mutant is judged by how many cases it fails and
  whether they fail identically. No `.*` between `expected` and `got` (CMake `.` spans
  newlines, so it bridges to a later record), the measured `got` spelled in full, `$` anchors
  nothing, `(` `)` `.` escaped.
- **Retiring a mutation needs a staged deletion and a measurement**, and both retirements get
  one (F13, Task 9). `git add -A` the deletion **before** applying any mutation by hand.
- **`git add -A` after any subagent measurement** commits files the subagent wrote. Review
  `git status --short` before every commit, and run any measurement that stages an edit in an
  **isolated scratch worktree**, never the live checkout.
- **Both lanes, always.** Every new case runs in `.chez.source` and `.chez.aot`, and the two
  lanes must report **identical counters** (design §7's oracle).
- **No red intermediate commit.** The source commit is one commit and is green at its head;
  Task 3's observed red exists in the working tree between steps, never in a commit.
- **`ctest` runs through a preset or `--test-dir build/dev`, never bare from the repository
  root** — a bare `ctest -R …` writes `Testing/Temporary/` into the source tree
  (`.gitignore:13-18` records that it reached a merged commit once).
- **Filter suite output for the failure signatures** — `CMake Error`, `wrong reason`,
  `UNCAUGHT`, `recorded limitation is stale`, `tests passed` — **and the exit status first**.
  The mutation suite prints "suite complete" on the way to failing.
- **Record vs instruction.** Design §4.4's span sentences, its schedule list, §4.10's timing
  sentence, both Status headers, the suite's SUBSUMED entry, the banner and the false
  uniqueness comments are **instructions**: corrected in place, dated. Decision 0033's
  **Context** is a record measured at `50516af` and is not touched; its **items** are
  instructions inside a record and get dated notes at the foot, never a rewrite.

---

## Task 1 — Re-take every measurement at the slice's own base

**Files:** none modified. Branch `feat/m7-slice-2`, cut from `main`. An isolated scratch
worktree for any measurement that stages an edit, removed at the end.

Every number in §1 was measured at `f3fbf4e`. If the base has moved they are re-taken
**before** anything is edited; if it has not, they are re-taken anyway, because a census
nobody re-ran is a census nobody checked.

- [ ] **Step 1.** `git log --oneline -1`; `git diff --stat <base>..f3fbf4e -- src/ test/`.
      **Expected:** the log line names the base; the diff prints **nothing**. Any output means
      §1's numbers describe a different tree and every step below re-measures before it is
      trusted.
- [ ] **Step 2.** The gate, both forms:
      `git diff 5ac363a..HEAD --stat -- src/ ':!src/byte-machine/verify.sls'` and
      `git diff --stat main..HEAD -- src/`.
      **Expected:** **no output** from either. The second is this slice's own gate and is
      re-run at the head of every task that touches a file.
- [ ] **Step 3.** The lane as it stands. **Both launcher constraints apply here, at the first
      command the executor runs** — `--program` must be **absolute** (the launcher sets
      `(source-directories '())`, and a relative path fails with
      `Exception in load-program: file "…" not found in source directories`), and
      `--object-guard` must name an **existing empty directory**, which this step creates:
      ```sh
      D=<scratch>; mkdir -p "$D/tmp" "$D/guard"
      /usr/bin/time -p env BYTE_MACHINE_TEST_TMPDIR="$D/tmp" chez --script \
        test/support/launchers/chez-source.ss --library-root test/support/harness \
        --library-root src --object-guard "$D/guard" \
        --program "$PWD/test/common/property-differential-tests.sps"
      ```
      **Expected, as literals:** `cases=2 failed-cases=0 checks=89 failures=0 … status=0`,
      and `real` under **0.5** (measured 0.30). The decomposition is the check:
      `89 = 1 (PRNG) + 40 (machine i verifies) + 40 (byte agreement) + 8 (counters)`, so
      `checks=89` **is** the statement that all 40 of 40 machines verified.
- [ ] **Step 4.** The counter census and the closed lists.
      **Expected, as literals:** `rg -c '"at least one|"the interpreter alone'
      test/common/property-differential-tests.sps` → **8**, of which **five** `at least one`
      and **three** `the interpreter alone`; `node?` **13** disjuncts; `matcher?` **4**;
      `field-operations` **7**; `field-predicates` **7**; `infallible-field-operations`
      **4** (`store clear set-mask clear-mask`); the callback-kind `memq` **4**;
      `accumulate-bases` `(10 16)`; `rg -n "'memq" test/` prints **nothing**.
- [ ] **Step 5.** The pin census, **by FILE**, with a single left-to-right lexer that skips
      `#` line comments, `#[=[…]=]` bracket comments, `"…"` strings and `[=[…]=]` bracket
      arguments — neither construct is recognisable without lexing the other.
      **Expected, as literals:** **526** `byte_machine_mutation` blocks; **48**
      `byte_machine_mutation_run` calls; **4** blocks whose `FILE` is `machine-gen.sls` and
      **1** whose `FILE` is `property-differential-tests.sps`; **6** blocks under `SPEC
      byte-machine.property.differential.chez.source`, all in Pass 39; **0** `FIND`-count
      mismatches across all literal-`FILE` blocks; and **no** variable-`FILE` block expanding
      to either rewritten file.
      **And the census reads every block's `REPLACE`, not only its `FIND`** — AGENTS.md's
      Slice ①-derived standard (PR #93): a pin whose `REPLACE` names a construct the slice
      renames or re-contracts goes stale without moving its `FIND`, and a stale `REPLACE` fails
      at nothing. This plan already found one by inspection (F13 LABEL 2's
      `(list 'feed-ready 'feed-ready)`); the mechanical pass is run here.
      **Expected, as a literal:** grep every block's `REPLACE` for the constructs this slice
      deletes or re-contracts — `accp`, `pausei`, `eofi`, `(make-uint-field 'n 8 25`,
      `parser-resume!`, `feed-ready` — and the hits are **exactly the five Pass 39 blocks**.
      **The bound that makes the `FIND`-only half sufficient, stated so it is not assumed:** a
      `REPLACE` is only ever substituted into its own block's `FILE`, and the only blocks whose
      `FILE` this slice rewrites are the **five** inside Pass 39. The six LABELs are F13's six, verbatim — a LABEL in the tree
      that is not in F13's list, or the reverse, stops the task and corrects this plan.
- [ ] **Step 6.** The totals arithmetic, reconciled to the last unit (F16).
      **Expected, as literals:** the `-v` filter prints **six** lines — 2235 and 2855 (indented
      calls inside the two wrapper-function bodies), 9817, 10041 and 10165 (`#` comments), and
      12602 (a `message()` string) — and the arithmetic is 530 raw − 3 comment − 1 string =
      **526**; 526 − 2 wrapper bodies (2235, 2855) = **524**; 524 + 12 expansions = **536** =
      `EXPECTED_MUTATIONS`; 48 − 2 + 12 = **58** = `EXPECTED_PASSES`. A census whose own total
      does not close is not a census.
- [ ] **Step 7.** Baseline the suite, and record the two numbers the tree does not (F21):
      `cmake --preset dev && cmake --build --preset dev && ctest --preset release
      --output-on-failure --no-tests=error`, then `ctest --preset release -R 'scheme-mutation'`
      captured to a log and filtered.
      **Expected, as literals:** `100% tests passed, 0 tests failed out of 114`; the mutation
      lane exit **0** and its own `scheme mutation suite complete (58 passes, 536 mutations)`;
      **0** occurrences each of `CMake Error`, `UNCAUGHT`, `wrong reason`,
      `recorded limitation is stale`. **Write both numbers into this plan's Verification
      section as measured** — they are recorded nowhere in the tree as measurements.
      Reconfigure first: the build tree's last recorded state is a failed filtered run.
- [ ] **Step 8.** Re-run the six Pass 39 mutants individually against a **scratch copy** of
      `src/`, `test/support/` and `test/common/`, under Pass 39's own verify command, and
      rebuild F13's two matrices.
      **Expected, as literals:** the FAIL-record counts `43 / 1 / 2 / 1 / 2 / 2`; the 6×6
      subset matrix **diagonal only**; the pin × mutant match-count matrix with diagonal
      `40 / 1 / 2 / 1 / 1 / 1` and exactly **three** off-diagonal non-zeros (`pause`, `accp`
      and `init`'s pins against the `bytetest` mutant, each **1**). Any other shape means F13's
      verdicts were taken against a different tree.
- [ ] **Step 9.** Re-open every `file:line` §1 cites into `src/`, `test/` and `docs/`.
      **Expected, as a literal:** **0** mismatches, or a correction made here before Task 2.
      Two are already known to need one and are corrected in Task 12 rather than here: the
      evidence base cites `§14:835` for the empty-fragment suppression, which is **`§14:834`**
      (`:835` is "A logical span may therefore produce zero or more data fragments"), and
      `§22.5:1286` / `§12.7:772` are **blank lines** that **five** shipped comments cite for the
      sentences at `:1287` and `:773` — three for `:1286` (`differential-callback-tests.sps:755`,
      `differential-span-tests.sps:545` and `:618`) and two for `:772`
      (`interpret.sls:378` and `:416`), all five reproduced. **Only one of the two
      `interpret.sls` hits is actually a drift**: `:378` cites the **range** `§12.7:772-773`,
      which contains the sentence; only `:416`'s bare `:772` is stale, and Task 12 Step 5
      records it that way.

**Exit:** Steps 1–9's literals reproduced or this plan corrected; the scratch worktree
removed; `git status --short` clean.

---

## Task 2 — The steering decision, and the floor gate

**Files:** none modified in the repository. All work in an isolated scratch worktree, removed
at the end.

**This is the slice's first decision, not its last.** Decision 0033 item 2 makes a measured
rate below half the machine count a **blocking** finding that "sends the draw back for steering
before the lane lands" (`0033` item 2, verbatim; §4.4 is where the draw lives, which is where
"back" goes). F1 measures §4.4's draw at 3 of 64. The steering set, its
classification and the floor literal are settled here, before a line of the generator is
written, and the measurement is taken **through a prototype of the draw this slice will
actually ship** — not through any of the three prototypes of §1, whose rates differ by 30×
(F2).

- [ ] **Step 1.** Stand up the prototype in the scratch worktree: the shipped
      `(byte-machine graph)`, `(byte-machine verify)` and `(byte-machine test prng)`, the draw
      of §4.4 with every steering of F3 as an independently switchable **flag**, driven by the
      launcher:
      `chez --script test/support/launchers/chez-source.ss --library-root <harness>
      --library-root <src> --object-guard <empty dir> --program <absolute path>`.
      Note the two launcher constraints measured: `--object-guard` must name an existing
      **empty** directory, and `--program` must be **absolute** (the launcher sets
      `(source-directories '())`).
      **Which prototype, and what that decides about Steps 2–3.** F2 measures three independent
      prototypes of this same paragraph at 15.0%, 12.55% and 0.5% — a 30× spread — and F2's own
      closing sentence says *the draw order alone moves it*: every steering changes how many
      values come off the PRNG, which re-rolls the whole seeded sequence. **A newly written
      prototype therefore cannot reproduce `prototype.md`'s counts ±0, by this plan's own
      finding.** So one of two, chosen here and not discovered at Step 3:
      - **start from `prototype.md`'s own `run3.sh` prototype, unchanged**, in which case
        Steps 2 and 3's counts are reproducible as **literals, ±0**; *or*
      - write a fresh prototype, in which case Steps 2 and 3 assert the **shape** and not the
        counts (each step says which shape), and F3's two tables are re-measured from it and
        corrected in this plan before Step 6 is read.
      **Do not present a second prototype's counts as literals of a third.**
      **Expected:** a run reporting `VARIANT=… SEED=… DRAWS=… ACCEPTED=… RAISED=…` with
      **`RAISED=0`** — any nonzero `RAISED` is a constructor contract violation the draw must
      respect before any rate means anything. The twenty-one construction-API refusals and the
      seven runtime refusals the evidence base enumerates are the checklist; **U21 is the one
      that is not obvious from the parameter names**: a `field-action`'s `error` slot must be
      a symbol **exactly when** the operation can fail, so a free draw of `operation × error`
      raises ~50% of the time, and `infallible-field-operations` is **not exported at all** —
      the draw re-derives `'(store clear set-mask clear-mask)` or derives it from the operand
      schema.
- [ ] **Step 2.** Reproduce the baseline, so the prototype is known to be measuring the same
      thing §1 did.
      **Expected, under seed `20260823` — as literals ONLY under Step 1's first option
      (`prototype.md`'s `run3.sh`, unchanged):** §4.4 as literally written accepts **3 / 64**,
      **19 / 200** and **251 / 2000**.
      **Under Step 1's second option the assertion is the shape, and only the shape:** the
      2000-draw histogram's top three codes are `zero-progress-cycle`, `non-eof-into-finish`
      and `eof-zero-progress-cycle`, and the 64-draw accepted count is **single-digit**. A
      materially different shape means the prototype is not §4.4's draw and Step 1 is redone. A
      different *count* under the second option is expected and is recorded, not chased.
- [ ] **Step 3.** Price **every** steering in **both** directions at 2000 draws, seed
      `20260823` — added to the baseline and dropped from the recommended set.
      **Expected, under Step 1's first option: F3's two tables reproduced, ±0** — the same
      seed through the same draw order gives the same counts.
      **Under Step 1's second option the expectation is per row: the top three rejection codes,
      and the sign and rough magnitude of each Δ** — `placed` the largest by a factor of two in
      both directions, `entry-bd` negative in direction 1 and positive in direction 2,
      `span-pair` negative in direction 1. The counts are then **re-measured**, F3's two tables
      **corrected in this plan**, and every later number that reads off them — Step 6's three
      variants, Step 8's ladder, F4's 46.1% — re-derived from the new table before Step 6 is
      read. Any row whose *sign* does not reproduce is a finding in F3, not in the prototype.
- [ ] **Step 4.** Classify each steering against 0033 item 1 using the **measured**
      discriminator: does the code it targets stay nonzero in the recommended set's histogram?
      **Expected, as literals:** `placed` leaves `eof-reachable-stop` at **70** per 2000 and
      `non-eof-into-finish` absent from the top six; `back-prog` leaves `zero-progress-cycle`
      at **297** and `eof-zero-progress-cycle` at **138**; `few-cases` leaves
      `overlapping-cases` at **761** and all four matcher kinds present (`m-exact` 472,
      `m-set` 432, `m-range` 372, `m-complement` 250 of 1128 accepted). A steering whose
      target code reads **0** is validity steering and is declined with its measurement, the
      way F4 declines `cbdefault`.
- [ ] **Step 5.** Measure the two **refused** steerings, so the refusal is measured rather
      than argued.
      **Expected, as literals:** `disjoint` gives **164 / 200 = 82.0%** with
      `overlapping-cases` at **zero** and complement matchers in **16** of 164 accepted
      machines; `distinct` gives **17 / 200 = 8.5%** and loses three of the four matcher
      kinds. Both are refused in writing, with these numbers, because 0033 item 2 requires a
      counter per matcher kind ≥ 1.
- [ ] **Step 6 (the `cbdefault` replacement — the measurement F4 owes).** Run three variants
      at 2000 draws and at 64 draws, seed `20260823`. **All three start from the SAME set, and
      `span-body` is OFF in all three**, so the only thing that differs between them is the
      `default-branch` draw:
      (a) `(span-pair placed back-prog cbdefault entry-bd few-cases)` — the recommended set as
      F3's direction-2 table defines it, **with** the hard `cbdefault` rule;
      (b) the same **without** it and with **nothing** in its place —
      `(span-pair placed back-prog entry-bd few-cases)`;
      (c) the same with `default-branch` drawn uniformly from `(cons #f declared-keys)` —
      F4(a).
      **Expected, as literals:** (a) **1128 / 2000 = 56.4%** (F3 direction 2's `T2`);
      (b) **922 / 2000 = 46.1%** (`S3`); (c) **between (b) and (a)**, with
      `invalid-callback-declaration` **present and nonzero** in its histogram.
      **Why (a) is 1128 and not 1160.** 1160 (`X1`) is the same set **with `span-body`**, and
      1128 (`T2`) is it without. Taking (a) = 1160 against (b) = 922 would price
      `default-branch` at 11.9 points — conflating `cbdefault`'s real price (**10.3 pts**,
      1128 → 922, which is exactly F3 direction 2's row) with `span-body`'s (**+1.6 pts**) —
      and would silently pre-consume **rung 1** of Step 8's own ladder, which is "re-measure
      with `span-body` included". `span-body` is **off** at the start of every rung of that
      ladder and rung 1 is what turns it on. Record (c)'s count at **64 draws** — that is the number the floor is
      set against. **If (c)'s histogram shows `invalid-callback-declaration` at zero, the
      replacement is validity steering too and Step 8's ladder runs.**
- [ ] **Step 7 (the span correction and the counters that can fire).** Measure, at 40 accepted
      machines × 256 single-byte trials, interpreter alone, with the pause protocol:
      the adjacent span pair; the adjacent pair over four-byte inputs; and the `span-body`
      shape of F5.
      **Expected, as literals:** span fragments observed in **0**, **0** and **4** machines
      respectively; `RAISED=0` on all three; and acceptance **higher** with `span-body`
      (1160 vs 1128 per 2000). Then repeat the `span-body` run under seeds **1**, **7** and
      **99**: **expected 0, 0 and 3** — which is the F5 finding and the reason Task 7 Step 5
      measures the span counter first through the real harness.
- [ ] **Step 8 (the gate).** Read the floor off Step 6(c) at 64 draws under the committed
      seed.
      **Expected:** **≥ 32**. If it is below 32, the ladder runs **in this order** and each
      rung is measured before the next is considered:
      1. re-measure with `span-body` included (F5: **+1.6 points**, and required anyway);
      2. **the remaining rejection classes in the recommended set, by size** (`overlapping-cases`
         761, `zero-progress-cycle` 297, `inconsistent-span-state` 163, `eof-zero-progress-cycle`
         138, `eof-reachable-stop` 70 per 2000) — F4's own rung 2. Every cheap lever over the
         first is one of the two **refused** matcher steerings of F3, so this rung has no move
         that does not cost a matcher counter, and taking one is a finding to record, not a
         silent trade;
      3. *(struck, and left in the ladder so nobody re-derives it)* — an earlier draft traded
         F8's dangling-target and orphan draws here. They **widen** the draw, so they can only
         make the floor worse; and they are **`0` in the property lane** (F8), because the row
         they serve is design §4.6's, which is Slice ④'s. There is nothing here to trade;
      4. **stop and escalate to the owner** with the numbers, as an amendment note on decision
         0033 — the only remaining lever is the span-pairing reframing, which is a *reading*
         of clause 1 and must be ratified in the record. **Do not lower the floor**: 0033 fixes
         it at half the machine count and a plan may not weaken a Gate 0 record.
- [ ] **Step 9 (the F8 draws, measured here and turned on in Slice ④).** `p` and `q` are
      steering-record members whose **property-lane value is `0`** (F8), so this step prices the
      **free** mode and hands the numbers forward; it does not move the floor.
      **The candidate set and the rule that picks among it, named so two agents ship the same
      generator:** try `p, q ∈ {1/64, 1/32, 1/16}`, nine pairs, at 2000 draws under the
      committed seed. **Choose the SMALLEST pair for which `missing-target` ≥ 20 per 2000 and
      `unreachable-node` ≥ 20 per 2000** — smallest because these draws exist to make three of
      §4.6's rows *fire*, not to dominate the free mode's material, and 20 per 2000 is one per
      100 draws, enough that Slice ④'s "fires ≥ 1 and stays silent ≥ 1" is not itself a coin
      flip. If no pair in the set reaches 20, widen the set upward by doubling and record that
      it was widened.
      **Expected, as literals:** with the draws on, `missing-target` and `unreachable-node`
      both **> 0** in the 2000-draw histogram (they are **0 / 8800** without them); with the
      draws off — the property lane's configuration — both back at **0**. Record both codes'
      counts and the chosen pair; the pair is written as a literal in the generator's header
      beside the steering set, and Slice ④ inherits it through Task 12 Step 7.
- [ ] **Step 10.** Write the decision down, in this plan and in the generator's header: the
      steering set, each member classified with its argument and its two-direction price; the
      two refusals with their measurements; `cbdefault` declined with the constructor comment
      quoted; and the floor literal with the command that produced it and the seed it was
      measured under.
      **Expected, as a literal:** every steering in the shipped set appears in the header with
      a classification and a number, and the count of steerings in the header equals the count
      in the code's steering record — asserted in Task 7 Step 7 as a totality row, not left to
      prose.

**Exit:** Steps 3–7's literals; a floor literal ≥ 32 measured at 64 draws under the committed
seed, or Step 8's escalation opened; the decision written; the worktree removed.

---

## Task 3 — Tests first: the lane rewritten over the driver's declared API, run against the SHIPPED generator

**Files:** `test/common/property-differential-tests.sps`, and
`test/support/harness/byte-machine/test/property-driver.sls` — its **signatures**, its Layer-1
core, and the **counter table's declaration** (`counter-keys`, `counter-labels`,
`make-counter-set`, `counter-ref`, and an `observe-counters` that is a **declared stub folding
nothing**). Tasks 4 and 5 fill the rest.

**How "red" is observed here, honestly — and what this task can and cannot run.** The rewritten
lane cannot load until the driver exists, and an import error is a raise, not a failed
comparison. So this task ships the lane's assertions **against the generator as it ships
today**: `gen-machine`'s current draw, still valid by construction, still taking a PRNG state
alone and still returning `(values machine fnames state)`.

**Two things are deliberately NOT in this task, because they cannot load here.**

- **The totality rows are Task 7 Step 2's**, not this task's. Every row compares `ir.sls`'s
  closed set against **the draw tables' keys**, and the draw tables are an export **Task 6
  Step 1 introduces**: the shipped `machine-gen.sls` exports exactly `gen-machine`
  (`machine-gen.sls:106`, 263 lines). Writing them here would fail at **import**, which is the
  raise this task's whole shape exists to avoid.
- **The counter fold is Task 4 Step 7's.** What Task 3 writes is the **table** — the 48 keys,
  the 96 labels, and the loop that asserts them — over a stub whose fold is the identity. The
  labels are data, and a table of data is exactly the part that must exist before the code that
  fills it.

So the program then loads, the trial runs, and:

- the floor check **passes** at 40 of 40 (the old generator's acceptance is 100% by
  construction — which is exactly what clause 1 removes);
- the Layer-1 comparisons and the accounting checks are **green** (the two lanes agree today);
- **all 96** counter checks read zero and are **red by comparison** — including the eight whose
  arms the shipped draw does produce, because the fold is stubbed. That the shipped draw
  produces them is already recorded by Step 1's green run of the unmodified lane; it is not
  this task's signal.

That is a measured red with numbers, and it is the honest one. **It exists in the working
tree between Task 3 and Task 6, never in a commit.**

- [ ] **Step 1 (the "before" half).** `ctest --preset release -R 'property\.differential'`
      on the **unmodified** tree.
      **Expected, as a literal:** `100% tests passed, 0 tests failed out of 2`. The count is
      the check — "green" cannot distinguish two lanes from one.
- [ ] **Step 2.** The seed plumbing (0033 item 3), written **before** anything reads it, and
      written to the contract rather than to the nearest shipped idiom. The parse, in order:
      read `BYTE_MACHINE_PROPERTY_SEED` through `adapter-environment-variable`; `#f` → the
      declared literal; **trim** (space, tab, LF, CR — reuse `harness-whitespace-byte?`'s set
      so the two agree, since `(rnrs)` has no `string-trim` and
      `rg -n 'string->number' test/ src/` prints **nothing**, so there is no shipped numeric
      env parse to copy); `""` after trimming → the declared literal; `(string->number t 10)`
      with the **radix passed explicitly** (bare `string->number` accepts `#x1f`, `#e10`,
      `1/2`, `1e3`, `+inf.0` and "decimal" is part of the contract); accept only
      `(and n (integer? n) (exact? n) (>= n 0))`; otherwise `assertion-violation` **with the
      raw value**, not the trimmed one, so the message shows what the developer set.
      **The polarity is the opposite of the two shipped precedents and the plan says so at the
      site**: for `BYTE_MACHINE_TEST_TMPDIR` and `BYTE_MACHINE_SOURCE_ROOT`, *unset* is the
      loud failure; for the seed, **unset is legal and malformed is loud**. Copying
      `(if (and d (not (string=? d ""))) d (assertion-violation …))` literally produces exactly
      the wrong program.
      **Expected, as literals, in cases:** unset → the literal `20260823`; `""` → `20260823`;
      `"  7  "` → `7`; `"0"` → `0`; and each of `"1/2"`, `"1e3"`, `"#x1f"`, `"-5"`, `"x"`
      raises. Measured and relied on: Chez's `getenv` answers `#f` for absent and `""` for
      empty (`(unset #f empty "" set "20260823")`).
- [ ] **Step 3.** The seed printed once at the suite's start — a bare `(display …)`, new
      practice in this tree (`rg -n '\(display ' test/common/*.sps` prints nothing today).
      **Expected, as a literal:** the line appears exactly **once** in a passing run's stdout,
      and **no token in it matches any pin of this SPEC lane** — checked by embedding the line
      in every Pass 39 pin's regex before the line's text is committed.
- [ ] **Step 4.** The per-machine labels, keeping the shipped agreement label's shape
      (0033 item 3): `(string-append "machine " (number->string i) " (seed "
      (number->string seed) ") byte agreement")`.
      **Expected, as a literal, with `machine-count` at 64 and the committed seed:**
      `machine 0 (seed 20260823) byte agreement`. Note the parentheses are CMake `MATCHES`
      metacharacters — the shipped pin works only because it anchors on the substring `byte
      agreement`, and F11's replacement escapes them.
      **The per-machine `verifies` checks GO** (all 40 of them): under clause 1 a rejected
      draw is *normal*, not a failure. **The floor is what replaces them**, and the plan says
      so here because the check count drops by 40 now (and by 64 once Task 7 Step 1 moves
      `machine-count`) at the same moment the counters add 96 and
      the arithmetic will not otherwise reconcile.
- [ ] **Step 5.** The accepted/rejected accounting and the **structural equality** of 0033
      item 1, written as **comparisons, never as a raise**. Three counters, each incremented
      **at the call site it counts**, never derived from one another:
      `accepted-count` in the `(verification-ok? v)` branch; `interpreted-count` in the same
      `let` that binds `make-interpreted-machine`'s result; `generated-count` at the
      `emit-and-load` call site. Plus `fed-unverified`, incremented in a `guard` around each
      hand-over, which reads the **executor's own refusal** and not the branch that called it.
      **Expected, as literals, in the lane:**
      `(check-equal "no draw reached an executor unverified" fed-unverified 0)`;
      `(check-equal "every accepted machine reached the interpreter" interpreted-count accepted-count)`;
      `(check-equal "every accepted machine reached the generated lane" generated-count accepted-count)`;
      and `(check-equal "every draw was accounted for" (+ accepted rejected) machine-count)`.
      *Why the guard*: if the filter is mutated away, the **first** rejected draw makes
      `make-interpreted-machine` raise `unverified-machine` before any counter runs, and the
      mutation is caught by a raise with a condition naming the constructor rather than the
      decision. With the guard it is caught by **two** comparisons that name it.
      *And one qualifier the plan must not overstate*: `make-interpreted-machine` refuses a
      **rejected verification result** correctly (`who=make-interpreted-machine
      code=unverified-machine`), but handed a **machine** instead of a result it raises a raw
      `(vector-ref "~s is not a vector")` with no `who`. The structural count is the real
      guard; the API's refusal is not, and the lane's comment says which.
- [ ] **Step 6.** The counter assertion loop, in its **own `harness-case`, entered only when
      the floor held** (F12), over the driver's declared label table:
      two `check`s per key (agreed, interpreter-only), each label the full text of F9's
      template.
      **Expected, as literals:** the loop's own `asserted` counter, read from the loop as it
      runs, equals **96**; and `(check-equal "and the table's length agrees" asserted (* 2
      (length (counter-keys))))`, whose right-hand side is `2 × 48`. **The two agree by
      construction, from F10's term-by-term derivation** — 92 census checks, +0 for the shipped
      pause pair, +0 for the shipped finish pair, +2 for `integer-accumulate`'s second arm, +2
      for the `declares a field` pair. Both are needed and neither catches the other — the literal
      catches a table that silently shrank, the derived total catches a loop that stopped
      early. A `for-each` over a label table registers checks whose labels are **data**, so
      the harness's duplicate-**case**-id guard does not protect them: two keys rendering the
      same label would be two checks, not an error, and only this pair of sentinels sees it.
- [ ] **Step 7.** The sentinel that closes the skip of Step 6, **registered in the FIRST
      `harness-case`** — beside the floor check and the structural equality, never inside the
      second case:
      `(check-equal "the counter pass ran over N accepted machines" <observed> <literal>)`,
      where `<observed>` is read from what the driver returned and **never** from the counter
      table's length.
      **The placement is the whole point and the plan states it rather than leaving it to the
      reader.** Inside the second case — the natural reading, since Step 6 defines that case one
      step up — the sentinel is skipped by exactly the condition it was written to witness, it
      emits no FAIL record, and Task 10 Step 4's "skip sentinel red under the floor mutant" is
      unachievable. In the first case it fires. A sentinel that cannot fail under the condition
      it names is the vacuity shape this project records, and this one is one line from being it.
      **Expected:** a literal fixed in Task 7 Step 4 from the same measurement that fixes the
      floor. Without it, a defect that always skips is invisible.
- [ ] **Step 8.** The loop-over-loops sentinels one level down, so L2 and L3 cannot silently
      shrink: schedules driven per input (**the literal Task 4 Step 1 computes from the six
      generators at §4.10's bounds — a literal, written down there, not left as "a literal"** —
      *and* the generator's own length, because a literal alone cannot catch a loop that
      stopped early and a derived length alone cannot catch a list that silently shrank),
      inputs per machine (**8**), single-byte trials per machine (**256**), machines
      (**64**), and one counter read from **what the executors returned** rather than from
      what the loop drove — the `differential-http-version-tests.sps` discipline
      ("`compared` counts runs the LOOP performed, `accepts` counts what the executors
      RETURNED. A loop that never ran, or an executor that stopped accepting, is caught by a
      different one").
- [ ] **Step 9.** The reproducibility case, raised "one level up" from the shipped PRNG case
      (design §7's oracle): the same seed in **two processes** yields the **same drawn
      machines**, compared by IR fingerprint through `harness-fingerprint-*`. Keep the shipped
      `"the same seed yields the same first draw"` case beside it — it is cheap and it is the
      one that still passes when the fingerprint plumbing is what broke.
- [ ] **Step 10 (before any label is committed).** Count the new check labels — it is roughly
      **100**, not the 96 counters alone — and embed **every** one in **every** pin of this
      SPEC lane, as substring and as regex, against a synthesised FAIL line
      (`byte-machine-harness: FAIL <group>.<case>: <label> -- <detail>`, with
      `detail = "expected a true value"` for `check` and the measured `expected …, got …` tail
      for `check-equal`).
      **Expected, as a literal: no hit**, for every new label against every pin, except the
      pin that owns that label. Two collisions are already loaded and are checked **first**:
      `"observes a pause"` (F14) and the reserved `"the same thirteen kinds"` (the generator's
      kind totality row must not print those words).
- [ ] **Step 11.** Run it. **Expected, as literals:** the program **loads**; the floor check
      green at `40` accepted of `40`; the Layer-1 comparisons and the four accounting checks
      green; **all 96** counter checks red with `expected a true value` (the fold is the stub of
      this task's file list); **no totality row present** — they are Task 7 Step 2's, for the
      import reason in this task's preamble. Record the exact `checks=` value and the exact
      failure count by check — Task 6 Step 11 and Task 7 Step 6 assert what they became, and
      "it got better" is not a measurement.

**Exit:** Step 1's `2/2`; Step 10's "no hit"; Step 11's recorded red counts, by check — the
program loading, the floor green at 40 of 40, the Layer-1 and accounting checks green, **all 96
counter checks red**, and **no totality row present** (they are Task 7 Step 2's).

---

## Task 4 — The driver: the trial, the schedule alphabet, the pause protocol, the emission seam, the counters

**Files:** `test/support/harness/byte-machine/test/property-driver.sls`. Same commit.

The driver is a **functional core**: it returns values and asserts nothing (F18). Everything
it inherits from the shipped lanes is inherited **with its comment**, because each of those
comments is a correction someone already paid for.

**Each step's checkable artifact, named once here so no step is judged by prose.** Step 1: the
three shipped triples reproduced (`37 / 30 / 45`) plus the per-input total written as a
literal. Step 2: `trial-result`'s accessor list, spelled in the step, exported and asserted by
length. Step 3: `rg -c 'parser-resume!'` over the driver → **1** (the `SITES` constraint of
F17(c), and Pass 39 LABEL 2's re-anchor target). Step 4: a trial reaching `paused-finish` at
least once over the shipped fixtures, recorded as a count. Step 5: the byte loop's bound read
back as **256** and the callback script demonstrably reset per byte (the second byte's first
invocation index is **0**). Step 6: the measured ~**1 ms** per emit+load, and the generated
`.sls` absent from every `SOURCES` manifest (`rg -c 'prop-' test/CMakeLists.txt` → **0**).
Step 7: `(length (counter-keys))` → **48** and `(length (counter-labels))` → **96**, with every
key carrying both halves. Step 8: `by-code` and `by-site` measured to **differ** on one real
run — they are not derivable from each other and a run where they agree has not shown that.
Step 9: `(run-machine …)` returns three values with `fixture-path` `#f` and the hook `#f`.
Step 10: `(disagreement->detail 'none)` and one tagged form, both rendered, both literals.

- [ ] **Step 1.** The schedule alphabet, once, for all six of `§22.5:1278-1283` (F19). Steps
      are `feed`, `feed-slice`, `finish`, `resume`, `reset` — the union of the four step
      vocabularies the three shipped script interpreters use. Generators:
      `schedule-splits` (every single split point, `len+1` two-slice schedules, `:1278`),
      `schedule-pairs` (every ordered pair, `(len+1)(len+2)/2` three-slice schedules,
      **`:1282`** — the bullet §4.4 drops), `schedule-empties` (leading, **intermediate** and
      trailing, `:1279`), `schedule-sub-slice` (`:1280`), `schedule-padded` (`:1281`), and
      `schedule-multi-split` (`:1283`, **seeded**, threading the PRNG state, **four per input** —
      §4.10's Bounds bullet fixes "four seeded multi-split schedules" and no other step states
      the number).
      **Expected, as literals, asserted in the lane:** the three shipped triples are
      reproducible from the one generator — span `6 + 21 + 10 = 37`, callback
      `5 + 15 + 10 = 30`, counted-span `7 + 28 + 10 = 45` (measured: the three lanes assert
      `thirty-seven schedules driven`, `thirty schedules driven` and `forty-five schedules
      driven`, and `differential-callback-tests.sps:744` spells its own decomposition
      "5 single splits + 15 pairs + 10 others") — and the driver's own per-input total is
      **computed here, from the six generators at §4.10's bounds** (inputs of length 0–6:
      `len+1` splits, `(len+1)(len+2)/2` pairs, the three empty shapes, one sub-slice, one
      padded, four multi-split), **written down as a literal in this step**, and then asserted
      in the lane **as that literal and as the derived length** (Task 3 Step 8's
      schedules-per-input sentinel, whose literal is set from here).
      *Two warnings carried into the code.* The shipped `with-empties` "inserts an empty feed
      before every real slice, including the last … so the final feed is still a DATA slice"
      — a genuinely **trailing** empty, fed after the machine has already stopped, is a
      separate scenario and the two are not folded. And `:1283` is **random and printed** here,
      against three shipped comments arguing a literal is the most reproducible form: the
      departure is deliberate (design §4.4) and is said so at the site.
- [ ] **Step 2.** The trial. `(run-trial ref-machine gen-machine trial-spec) → trial-result`,
      where `trial-spec` carries the schedule, the callback **script** (a list of outcomes per
      declared callback, indexed by invocation, identical in both lanes), which optional
      callbacks are bound, the declared field names **and widths**, and the span names.
      `trial-result` carries, **per lane**: one Layer-1 tuple per step; a callback trace per
      invocation; a raw fragment trace of fresh bytevectors plus `complete` markers; and a final
      `(lifecycle state-name active-span offset field-values)`.
      **The callback trace record is `(name state-name-before stream-offset outcome
      state-name-after status resume-ack error)` — seven fields, and the SCRIPTED `outcome` is
      the one a counter may never read.** It is carried for **replay** and for the Layer-1
      cross-lane comparison of `:1268` ("callback order and results"), where both lanes are
      handed the identical script and the comparison is lane-against-lane. Every
      `callback-outcome` counter reads one of the other six (F9): `continue` → `state-name-after`
      equals the node's continue target; `pause` → `status` `paused` plus `resume-ack` plus the
      post-resume state name; `declared-branch-key` → `state-name-after` equals the branch
      target for a declared key, resolved through the manifest's `key → node` mapping;
      `explicit-failure` → `error`'s `parser-error-code`, which `project-error` already
      compares. **The plan writes the record this way because the shorter one hands the
      executing agent exactly one convenient value, and it is the forbidden one** — F10's
      `(pair? fnames)` defect at eight more counters.
- [ ] **Step 3.** The pause protocol, preserved exactly, with its guard and its comment: feed
      both lanes the same slice; read `ref-paused?` **before** the disagreement check; then
      **disagreement first**, then **mutual pause** (resume both, compare the two acks,
      recurse from `(parser-result-next rr)`), then settled. Resume happens in **one** place
      — the re-anchor target of Pass 39's LABEL 2 (F13) and the `SITES` constraint of F17(c).
      **A side that paused alone is already a disagreement the first `cond` clause caught and
      must not be driven through `parser-resume!`**, which raises on anything but a paused
      parser.
- [ ] **Step 4.** The finish side, the same shape, returning `finished?`. Its header records
      that the finish-pause branch is **unexercised by the shipped lane** ("a byte-reachable
      pausep's continuation is always `'start`") and that **§4.4's free EOF-route draw makes it
      reachable** — so a *new* counter witnesses it and the comment is updated rather than
      inherited as still-true.
- [ ] **Step 5.** The 256 single-byte trials, preserved as design §4.4 requires: the loop bound
      **256**, a **fresh parser pair per byte**, the first-disagreement-wins rule, and the byte
      number wrapped around the phase tag so a disagreement replays without grepping which of
      the 256 it was. Once callbacks are drawn, the fresh pair also **resets the callback
      script** — stated explicitly, on `differential-callback-tests.sps`'s precedent ("a
      callback outcome is sticky through the lifecycle, so reusing one would make every later
      case observe the first").
- [ ] **Step 6.** The emission seam, preserved byte for byte and parameterised only on
      `tmpdir`: `<tmpdir>/prop-<i>.sls`; `(open-file-output-port genfile (file-options
      no-fail))` inside `call-with-port`; `(emit-machine (compile-machine m '()) 'gen-parser
      p)`; `(load genfile)`; `(eval 'gen-parser (environment '(generated gen)))`. The generated
      `.sls` is a **run-time artifact and never appears in a `SOURCES` manifest**.
      **Expected, measured:** ~**1 ms** per emit+load cycle; at 64 machines ~**256 KB** per
      lane per run in a directory nothing cleans (`rg -n "file\(REMOVE" cmake/
      test/CMakeLists.txt` prints nothing) — which is fine and gets one sentence.
      *If the generator ever varies the machine name*, generalise to the shipped
      `generated-machine` shape, whose comment records why `(environment (list 'generated
      name))` is the only form that consumes the name and is what raises loudly when a label
      and a `machine-name` diverge.
- [ ] **Step 7.** The counters as **one opaque value, a pure merge, and one declared label
      table** — never the shipped nine-threaded-accumulators shape, which does not scale to 46
      keys and gives Slice ③'s fixture nothing to reuse.
      `(make-counter-set)`, `(observe-counters counters trial-result)` (a pure fold),
      `(counter-ref counters key half)`, `(counter-keys)`, `(counter-labels)`. Every key has
      **both** halves. The lane folds over its 64 machines; Slice ③'s fixture folds over its
      one trial — which is what makes "the lane and the fixture read the same code" literally
      true for the counters too.
- [ ] **Step 8.** The rejection ledger: one record per rejected draw, in draw order, carrying
      `index` (with the seed, the whole replay key — **not** the PRNG state, which is not
      printable in a label), the **machine object** (Slice ④'s oracle walks the graph), the
      **whole diagnostic list** (not a code list — `:908` wants the source node and the edge
      role and `:909` compares jointly per start, and Slice ①'s `diagnostic-edge` /
      `diagnostic-path` carry both), the distinct sorted `codes`, and the distinct sorted
      `(code . node)` **pairs** — §4.6's comparison unit, kept sorted so the oracle's `equal?`
      is order-free. Beside it two aggregates that are **not** derivable from each other:
      `by-code` counts **machines**, `by-site` counts **diagnostics** (measured, they diverge
      by two to three: `overlapping-cases` 80 machines / 269 sites in one prototype run).
- [ ] **Step 9.** The `on-first-disagreement` hook: `(run-machine ref gen trial-specs counters
      on-first-disagreement) → (values counters verdict fixture-path)`, with the hook `#f` in
      this slice and `fixture-path` always `#f`. **The "at most once per machine" rule lives
      here**, not in the lane (§2 decision 2). The driver **does not** call `harness-begin` —
      Slice ③'s fixture must, or it reports `suite=(none)` and can exit **3** on a stray
      `BYTE_MACHINE_FINGERPRINT_FILES` instead of the 1/0 decision 0033 item 4 promises.
- [ ] **Step 10.** The disagreement value and its renderer: `'none` or a tagged form carrying
      the phase, the schedule index, the step index and the member or rule name; plus
      `(disagreement->detail verdict) → string`. The lane's check is
      `(check-equal "machine i (seed s) byte agreement" verdict 'none)`, whose detail is
      `expected none, got <verdict>` — and **`check-fail` is the only harness assertion whose
      detail the caller chooses**, which is why 0033 item 4's "the check's detail names the
      file" needs it. Slice ③ swaps the one for the other; the pin survives either way because
      it anchors on the `what`, not the detail. Said here so ③ does not re-shape the driver.

**Exit:** the driver loads; Step 1's three shipped triples reproduced from one generator;
the resume site occurs exactly **once**; no `check` and no harness import anywhere in the file.

---

## Task 5 — The driver: the three comparison layers

**Files:** `test/support/harness/byte-machine/test/property-driver.sls`. Same commit.

- [ ] **Step 1 (Layer 1, `§22.4:1264-1272` + `§22.5:1285`).** The tuple, widened from the
      shipped `rfields`' six-plus-fields to all nine members. The shipped lane reads **four
      fully, three partly and two not at all** — measured bullet by bullet, against design
      §3's "five fully, two partly, three none", which counts bullet `:1272` twice (5+2+3=10
      over nine bullets):

      | bullet | today | after |
      |---|---|---|
      | `:1264` status | fully | unchanged |
      | `:1265` next / consumed | fully | unchanged |
      | `:1266` offset | fully | unchanged |
      | `:1267` final state **and** fields | **partly** — fields only when `fnames` is non-empty; `parser-state-name` is **never read** | `parser-state-name` **and** `parser-active-span` added |
      | `:1268` callback order and results | **not at all** — every parser is built `(make-parser cm '() #f)` | the per-lane callback trace |
      | `:1269` span fragment ranges/content | **not at all** | the per-lane fragment trace |
      | `:1270` pause continuations | partly — the protocol, never a positive sentinel | plus a positive sentinel and the post-resume state name |
      | `:1271` error projection | fully | unchanged — **and not narrowed** |
      | `:1272` stop / finish / **reset** | partly — `parser-reset!` is **never called** | reset on half the trials, compared by the parser **after** |

      **`parser-state-name` is added on `:1267`'s own text** ("final state and fields") and
      `parser-active-span` on **decision 0028's** warrant, not on `:1267`'s — 0028 says in
      terms that "what nothing in `:1264`-`:1272` compares is whether the span is *active*".
      Both are decided by name here because design §4.4's member list omits both while citing
      the bullet that asks for "final state".
      **`project-error` is not narrowed**, and the file's own warning says why: "Do not narrow
      this list on the argument that both lanes 'build it from the same declaration'; that was
      the assumption the defect broke." Six members, `parser-error-state-id` deliberately
      excluded and exposed separately as `error-state-id`. Once callback failures are drawn,
      `parser-error-detail` is asserted **per lane, never across lanes** (decision 0024).
      The reset leg's compared value is the parser after: lifecycle `ready`, state name the
      entry, every field back at its **declared initial** (not zero), `parser-active-span`
      `#f`, stream offset 0 — and then a **re-parse**, because the reset itself is shared
      wrapper code.
- [ ] **Step 2 (Layer 2, `§22.5:1287` and `:1289`).** Three comparators, each with the
      **negative sentinel** that keeps it from being a statement about a constant:
      - `coalesce-fragments`, **one** implementation, using the span lane's **totality** rule
        ("one concatenation per logical span, emitted even when it is empty — the normalized
        form has to be TOTAL, or a span that produced no fragment in one schedule and one
        empty fragment in another would normalize to two different shapes and the invariance
        below would be about nothing"). The tree has **two** coalescers with different
        alphabets and different totality (the counted-span one drops a trailing zero-length
        run); the driver owns one and states which.
      - the coalesced trace and the callback trace **invariant** across every schedule of one
        input; the **raw** trace provably **not** — `(> (length raws) 1)`. For a *drawn*
        machine the raw count can legitimately be 1 (a span that never straddles a boundary),
        so this one is **aggregated across the seed set** and asserted as an anti-vacuity
        counter, never per trial. That is a departure from the fixed-machine shape and is said
        so at the site.
      - on a malformed input, `(status, absolute-offset, error-code)` invariant across
        schedules with the **trace omitted**, and the callback prefix compared **within** a
        schedule only — plus the sentinel that the prefix *is* schedule-dependent, without
        which "compare only three fields" is a restriction that costs nothing and proves
        nothing. **"Error category" is `parser-error-code`, not the declaration name** — the
        shipped comment's reading, and load-bearing for a drawn machine whose declaration
        names are drawn and whose codes are not.
      **Expected, as literals, on the named fixtures:** `coalesce-fragments` over `spanfull`'s
      37 schedules yields **one** coalesced trace, `equal?` across all 37; the **raw** trace
      differs across those 37 (`(> (length (distinct raws)) 1)` → **`#t`**, the negative
      sentinel), while the same expression on the `eopen`/`eclose` pair — a span that never
      straddles a boundary — reads **`1`**, which is exactly the case the
      aggregate-across-the-seed-set treatment exists for and is why it is asserted there and not
      per trial; and on a malformed input the three-field tuple is `equal?` across schedules
      (**`#t`**) while the callback prefix is **not** (**`#f`**). Four booleans, asserted, not
      described.
- [ ] **Step 3 (Layer 3, rows 1–5).** Six rows, `check-invariants` returning `'none` or a
      tagged violation, plus `invariant-rows` so a totality sentinel can assert the count is
      **6**. Each row's exact form, with the trap it avoids:
      - **row 1**, the `§12.2` table: keyed on **`(lifecycle-before, operation)`**, never on
        the status alone (F23) — the `§16.2:909` hole is the pair
        `(ready | finish-ready, finish!) → stopped`. The "Contract condition" cells are a
        **raise the driver catches and whose `code`, `who` and `detail` it compares**, through
        `(byte-machine private conditions)`'s four exports. The **driver** is what catches and
        compares, so it is the **driver's** `(import …)` that gains the line; the property
        program needs it only if Task 7 grows a check that reads a condition directly, and
        nothing in Tasks 3 or 7 does. **No CMake edit either way**, measured:
        `src/byte-machine/private/conditions.sls` is in `BYTE_MACHINE_CORE_PRIVATE`
        (`test/CMakeLists.txt:162`), which reaches `CORE_EMIT` through
        `CORE_GRAPH` → `CORE_VERIFY` → `CORE_ALL`.
        `poisoned` and `busy` are **not driven** and the row says so rather than asserting
        them vacuously: `poisoned` needs a nonlocal escape out of a callback and `busy` needs
        a callback re-entering the parser, and a script drawn from
        `{continue, pause, key, failure}` does neither.
      - **row 2**, the cursor arithmetic: branches on **feed- vs finish-originated**, which the
        driver knows because it made the call — `§9.3:425`'s "accessors enforce where fields
        such as `next` are meaningful" is **not implemented** for `parser-result-next` /
        `-consumed`, and the parent plan **defers** it to "the next slice that changes
        `parser-result`'s shape", which this slice is not. The `finished next 5 consumed 0
        offset 5` digest is **dropped**, not repeated (F23).
      - **row 3**, sticky feeds: `consumed` 0, `next = start`, offset unchanged. **At least one
        feed must be issued with a nonzero `start`**, or `next = start` is indistinguishable
        from `next = 0` — which the sub-slice and padded schedules of Step 1 already supply and
        which the shipped lane's zero-length recovery feed does not.
      - **row 4**, `[0, 2^width)`: needs the **width** per field, which the driver gets from
        the generator's `uint-field` records (`uint-field-width` **is** exported from
        `(byte-machine graph)`). A **u64** field exceeds the host fixnum range and the tree has
        a shipped precedent that this is a real case.
      - **row 5**, `finished` only from `parser-finish!` or a sticky feed after it: a
        `finished` status from `parser-feed!` is legal **only** when `lifecycle-before` was
        already `finished`; otherwise the trial is a `§16.2:908` hole and is reported as one.
        Both executors carry an **unconditional** finish arm reachable from a feed
        (`runtime.sls`'s `((finish) …)` and `compile.sls`'s emitted `case` arm), and the
        verifier's `:908` block over `node-out-edges` is the only thing that keeps a feed from
        reaching one — which is why the invariant is a verifier-completeness property and not
        a runtime one.
      **Expected, as literals — the per-row smoke result, which row fires and which stays
      silent:** on `spanfull` driven to completion, `check-invariants` returns `'none`, and each
      of rows 1–5 reports **applicable** at least once, through an `applicable` count per row
      exported beside `invariant-rows` so that "held" and "never driven" are distinguishable —
      a row that was never applicable is the vacuity this task's own totality sentinel exists to
      catch. Then, with each row's comparison inverted **by hand, one at a time**: **exactly
      that row** reports a violation and the other four stay `'none`. Five runs, five
      single-row results. An inversion that reddens two rows is a coupling to fix **here**,
      because at Task 10 Step 3 the same inversion becomes a pin and a pin that reddens two
      rows is a pin that matches two records.
- [ ] **Step 4 (Layer 3 row 6, the span row, with its third inapplicability condition).** The
      three conjuncts of F23: content at absolute offsets; contiguity and order within one
      logical span; and the end anchor read from `parser-stream-offset` **inside the
      span-complete callback**. Absolute coordinates come from the **driver's own bookkeeping**
      (`abs_from = offset_before_this_feed + (from − feed_start)`), because the callback's
      `from` is a **slice** offset re-anchored every feed and **there is no public observation
      of the span's start offset**.
      **Three inapplicability conditions, all three named:** not at an error (`§14:839`); not
      when the optional span-data callback is unbound (the fragment step short-circuits — the
      `(unbound-callback? f)` disjunct, beside `(>= from to)`, which is `§14:834`'s
      empty-fragment suppression in the same guard); and **not when no span-complete callback
      is bound**, in which case conjunct (iii) is dropped and (i)+(ii) stand. **The third is
      this plan's addition and neither governing document carries it.**
      **Expected, as literals, on the shipped pair that exists precisely to separate them** —
      `counted-machine.sls`'s `spanfull` and `spanbare`, which differ in exactly the completion
      declaration: on `spanfull` all **three** conjuncts are applicable and all three hold; on
      `spanbare` conjunct (iii) reports **inapplicable** and (i) and (ii) hold. And the proof
      that the condition is load-bearing rather than defensive: **with the third condition
      removed, `spanbare` reports a violation.** Run both directions.
- [ ] **Step 5.** The driver's header: the three layers, the counters' contract, and — in the
      same paragraph or with a pointer to it — **the blind spot**. The lane program, Slice ③'s
      fixture and the minimizer all read this library, and a header only in the lane program is
      a claim with one end. The sentence, sourced: all three layers are blind to an
      agreed-wrong value that satisfies every invariant, and one is in the tree today —
      `§12.7:770`'s zero-width-machine-action half, the position kind of a **failed**
      zero-width action reached over a **reexecute** edge, which the row fixes at `boundary`
      and which **both** lanes report as `byte`. **This generator draws that shape** (a
      fallible field action with an error edge, entered over a reexecute edge) and will drive
      it thousands of times per seed set; every trial will **pass**, because Layers 1 and 2
      compare the lanes against each other and they agree, and because Layer 3 reads statuses,
      cursors, offsets, fields and span bytes and reads **no position kind**. Drawing the shape
      does not make this slice the receiver: the receivers are `compile.sls`'s `field-action`
      arm and `interpret.sls`'s `field-step`, named in design §4.11 item 7 and written at both
      constructs, and §4.9's gate is what proves this slice touched neither.

**Exit:** `invariant-rows` has **6** members and an `applicable` count each; one coalescer;
every Layer-2 comparator has its negative sentinel **asserted as a boolean, on a named
fixture**; each Layer-3 row inverted by hand reddens **exactly itself**; `spanbare` reports
conjunct (iii) inapplicable and reports a violation without the third condition; the header
names the blind spot and the driver's own layer boundary puts `§22.5:1285` in Layer 1.

---

## Task 6 — `machine-gen.sls` rewritten to the decided draw

**Files:** `test/support/harness/byte-machine/test/machine-gen.sls`. Same commit.

The file is 263 lines today and exports exactly `gen-machine` (`machine-gen.sls:106`). It is
rewritten, not edited. **The steering set is Task 2's, not this task's**; this task implements
it.

**Every construction step of this task carries a checkable artifact, not a description.** The
skeletons are near-identical by design (F17(b)), so the cheap check is a count: after Step 4,
`rg -c` over the file gives **13** kind arms, **4** matcher arms, **7** field operations and
**7** field predicates, each counted by its **own discriminating token** — which is the same
token F17(b) requires the per-arm `FIND`s to carry, so the count and the pins are checking each
other. The exported identifier list is spelled out in Step 1 and asserted as a literal. And the
prototype's `RAISED=0` probe (Task 2 Step 1) is **re-run against the real generator after
Step 4 and again after Step 7**, because those are the two steps that add constructor calls,
and a contract violation that escapes the draw is caught by a raise — the thing this plan
prefers to catch by comparison everywhere else and cannot here.

- [ ] **Step 1.** The exports and the signature. `gen-machine` takes a PRNG state **and a
      steering record** (F18) and returns the machine, a **draw manifest** and the threaded
      state. The draw tables are **exported** so the property program's totality rows can
      compare them against `ir.sls` (F18, §4.10's placement against §7's).
      The manifest carries: the `uint-field` records (names **and** widths — Layer 3 row 4);
      the callback declarations; the span declarations; the `name → (family . member)` decoder
      for node kinds, matcher kinds, operations and predicates, **and the callback
      declarations' `key → branch-target node name` mapping together with each callback node's
      continue target and declared pause continuation** — without those three the
      `callback-outcome` family has no witness but the script, which is the draw (F9); the
      witness field per `field-action` node and the marker bits per `field-branch` arm (F9);
      and the drawn callback script, carried for **replay and the Layer-1 cross-lane comparison
      only, never as a counter's operand**. **The manifest is a decoder, not an observation** — the comment says so,
      and says where the line is: it becomes the forbidden shape the moment a counter
      increments without a trial having produced the name.
      Where the driver needs the machine's own **content** rather than the generator's claim,
      it imports `(byte-machine private ir)` — the shipped precedent
      (`kind-position-census-tests.sps`'s own comment gives the reason verbatim) and **no CMake
      change**, because `private/ir.sls` is already in both manifests inside
      `BYTE_MACHINE_CORE_PRIVATE` → `CORE_GRAPH` → `CORE_VERIFY` → `CORE_ALL` → `CORE_EMIT`
      (`test/CMakeLists.txt` 161, 734, 783, 807, 938).
      **Expected, as a literal:** the file's `(export …)` form names exactly
      `gen-machine`, the steering-record constructor and accessors, and the draw tables — the
      list is written out **here, in this step**, and Task 7 Step 2's totality rows import it by
      that spelling.
- [ ] **Step 1b (the call-site migration — the step no other task owns).** Step 1 changes both
      `gen-machine`'s argument list **and** its second return value, and Task 3 wrote the lane
      against the shipped contract. **No task after this one lists "update the call sites" in
      its file list, so it is listed here, with both forms written out**, and it lands in the
      same edit as Step 1 or the tree does not run at all:
      - `test/common/property-differential-tests.sps` — from
        `(let-values (((m fnames s2) (gen-machine s))) …)` to
        `(let-values (((m manifest s2) (gen-machine s steering))) …)`, with every downstream
        reader of `fnames` re-pointed at the manifest's field records (the lane's own use of
        `fnames` is F10's `(pair? fnames)` witness, which Task 7 Step 3 replaces outright);
      - `test/support/harness/byte-machine/test/property-driver.sls` — the driver takes the
        **manifest**, not `fnames`, and Tasks 4 and 5 are written against manifest fields the
        shipped generator never returned (field **widths** for Layer 3 row 4, the callback
        declarations, the span declarations, the `key → node` mapping, the decoder). Those
        tasks' code is therefore written against a contract that **does not exist until this
        step**, which is why the three tasks land in one commit and why this step is named.
      **Expected, as literals, immediately after the migration and BEFORE Step 11's re-run:**
      the program **loads**; `rg -c 'fnames' test/common/property-differential-tests.sps
      test/support/harness/byte-machine/test/property-driver.sls` → **0**; and the run's
      `checks=` and failure count recorded, so Step 11's numbers have a predecessor to be
      compared against rather than appearing from nowhere.
- [ ] **Step 2.** The declaration draws, in a fixed order so the PRNG stream is stable. One or
      two `uint` fields at drawn widths from `{8,16,32,64}` and drawn initials in range. One or
      two node-invocable callbacks, **kind drawn from `{event, decision}`** for callback
      *nodes* (`verify.sls:1648-1650` — "callback node invokes a span callback" — makes any
      other kind on a node invalid), `required?` drawn, **branch keys drawn only for
      `decision`** (F4(b), structural on `§10.3:504`), keys drawn **without replacement** from
      a small pool that excludes `continue` and `pause`, and **`default-branch` drawn from
      `(cons #f declared-keys)`** (F4(a)). Span declarations: **one or two**, drawn — §4.4's own
      count, with §4.4's own reason (`§10.4:519` limits *active* spans to one, not declarations,
      and the wrong-end and overlap shapes need two names) — and a **single machine-level coin**
      for the completion callback, named on **every** span or on none. A `span-complete`
      declaration no span names is `unreferenced-callback-declaration`, and §4.4's "in half the
      draws" read *per span* would produce exactly that; the shipped `counted-machine.sls`'s
      `complete?` flag is the precedent, and **Task 12 Step 1 writes the machine-level reading
      back into §4.4**, because an uncorrected §4.4 is the only specification Slice ④ has of the
      free mode (design §4.6 defines its drive as "§4.4's generator with its structural steering
      off").
      **Which optional callbacks are bound is itself a draw — §4.4's "Optional callbacks are
      bound in half the draws" — and it is drawn here**, per declaration, as a fair coin.
      Nothing else draws it, and the F4(a) `default-branch` draw is observable *only* through
      the unbound-optional-decision path: an unbound optional decision callback takes its
      default branch (`§9.3:419`), so a lane that binds every optional callback never exercises
      the slot this plan spent F4 on. Error declarations: the machine default plus one or
      two more.
      **One open question this draw now touches deliberately.** The shipped generator declares
      `over-decl` "only on machines that draw the accumulate node", and its comment says why:
      "an unreached declaration would sit in the source errs table but not in the encoding's
      reached-declaration table, which is **decision 0022 item 7's open question**". A free
      declaration draw **will** produce unreached error declarations. **This plan's decision:
      allow it, and say so** — 0022 item 7 is a question about the *encoding*, the lane
      compares the two executors against each other, and an accepted machine with an unreached
      declaration is a legal machine the suite should be driving. The comment moves from
      "avoid this by accident" to "this is drawn on purpose, and here is the record it
      exercises", and Task 12 Step 4 annotates 0022.
- [ ] **Step 3.** The worklist. One open slot at the entry; a node budget of **8** fresh nodes
      beyond the fixed terminals; each slot filled by a fresh node of a drawn kind, a back-edge
      to an allocated node, or a fixed terminal; budget exhaustion forces terminals. **A fixed
      terminal is emitted only if some slot referenced it** — the structural rule that takes
      `missing-target` and `unreachable-node` to zero, measured independently by two
      prototypes.
      `placed` is the kind vocabulary: **`finish` only at an `eof-target` slot; `stop` only at
      a slot that is `byte?`-and-not-`eof?` and is not `span-end-next`** (F7's table). The
      slot classes (`byte`, `eofonly`, `both`) are derived from `verify.sls`'s own
      `node-out-edges` / `node-eof-target` shape and propagated — the entry is `both`; a
      dispatch's cases and fallback are `byte` and its `eof-target` `eofonly`; accumulate's
      three byte arms are `byte`; counted consume's `next` is `byte`; a pause continuation and
      a callback's pause continuation are `both`; a span end's `next` is `both`; every other
      zero-width successor inherits its host's class.
      **The model is approximate and the code must say so rather than claim exactness**:
      measured, `eof-reachable-stop` survives at **70 diagnostics per 2000 draws** with
      `placed` on. That residual is a **validity rejection the verifier decides**, which is
      the correct outcome — and it is the measurement that proves `placed` is not a second
      verifier.
      `back-prog` is the back-edge rule: a back-edge is offered only over a slot reached by
      **consuming a byte**.
- [ ] **Step 4.** Per kind, every slot the constructor has, respecting every category-U
      constraint (Task 2 Step 1's checklist) so `RAISED` stays **0**:
      byte dispatch 1–2 cases (`few-cases`) over **all four** matcher kinds, each an
      `(make-edge target mode)` with mode from `{advance, reexecute}`, plus a fallback edge and
      an EOF route; sequence dispatch 1–3 alternatives of 1–3 bytes, a mismatch **edge**, an
      EOF route; field action an operation from `field-operations` with operands **inside the
      width** and its `error` slot drawn from **`(memq op infallible-field-operations)`** —
      re-derived as `'(store clear set-mask clear-mask)` because the list is **not exported at
      all**; field branch a predicate from `field-predicates` with `range`'s operands ordered;
      accumulate a drawn field, a base from `{10,16}`, a digit target, a non-digit **edge**, a
      **mandatory** overflow error, an EOF route; callback node a drawn declaration, a continue
      target, a target for **exactly** the declaration's branch keys (the key set must equal
      the declaration's, exactly — an `event` node's `branch-targets` is `'()`), and a pause
      continuation; span start and end a matched pair; counted consume a drawn field, a next,
      an EOF route — **and no `error` slot** (F6: a fifth argument lands silently in
      `source-label`); pause a continuation; stop, finish nothing; error a drawn declaration
      name.
      **The kind draw is round-robin with a random phase, not uniform**, and so are the matcher,
      operation and predicate draws. Measured reason: at 64 draws under the committed seed a
      uniform draw leaves **`clear` absent entirely** and five more operations at exactly one
      machine, and item 2 requires an **observed** value, which is strictly rarer than
      presence. Round-robin changes no totality row and encodes no validity — the sets are
      still read from `ir.sls` by the program's own rows — and it is the cheapest way to make
      item 2 satisfiable at any machine count. **§4.4 says "drawn uniformly"; Task 12 Step 1
      writes the round-robin rule and this measured reason back into it**, because §4.4 is the
      only specification Slice ④ has of the free mode.
      **Expected, as literals, at the end of this step:** `rg -c` over the file, counted by each
      arm's **own discriminating token** (the same token F17(b) requires its `FIND` to carry, so
      the count and the pins check each other), gives **13** kind arms, **4** matcher arms,
      **7** field operations and **7** field predicates; and Task 2 Step 1's probe, re-run
      against **this** generator, reports **`RAISED=0`** over 2000 draws.
- [ ] **Step 5.** The EOF-route draw: every input-reading node draws from
      `{#f, a finish, an error, an existing node}` — §4.4's four-way choice, and a draw over
      values the slot already admits rather than a widening of it. **This is the only accepted
      producer of a reachable `finish`** (F7), so the finish counter is driven by an EOF trial.
- [ ] **Step 6.** The span shape, re-worded per F5 and F6: a span start, **one advancing
      one-case byte dispatch between start and end carrying its OWN private EOF error node**,
      and the matching end. The comment names the shipped precedent verbatim
      (`counted-machine.sls`: "`body`'s EOF route is its OWN truncation node: the shared one is
      reached with no span open, and pass 7 rejects one node carrying both states") and records
      that §4.4's "the end has a private error sink" names a slot `make-span-end-node` does not
      have, and that a fifth argument there raises a **raw arity error with no `who`** while the
      same mistake on `make-counted-consume-node` is **silent**.
- [ ] **Step 7.** The coverage steerings of F9, each stated as such at its site: a **witness
      field per drawn `field-action` node** with an operand drawn so the change is visible, and
      a **marker `field-action` node on each `field-branch` arm** writing distinct bits into one
      marker field. Both are demonstrated rather than assumed — `parser-state-name` **never
      names** a zero-width node — and refusing them means item 2 cannot be discharged for
      fourteen of the forty-six counters. The operand constraints are per member, because the
      operand must separate a member from its **siblings**: the shipped precedent is
      `field-access-tests.sps`'s `cov-machine`, whose comment records `mask-all 12` **surviving**
      and `mask-all 14` **catching**.
      **Expected, as literals:** the probe re-run reports **`RAISED=0`** over 2000 draws — this
      step adds constructor calls and an operand that must stay inside the field's width, which
      is category-U territory; and, read from the manifest as a derived count against the drawn
      node count (never off the source), every drawn `field-action` node has exactly **one**
      witness field and every `field-branch` arm exactly **one** marker node.
- [ ] **Step 8.** The `matcher-kind/byte-complement` draw, in the order F9 fixes: first draw
      the complement's inner matcher and then draw the sibling cases **from inside** the
      complemented set (a complement of `{b}` plus an exact case on `b` covers all 256 bytes
      with no overlap); if that still starves the counter, draw a complement as the **only**
      case of its dispatch. Both are coverage steering, neither touches clause 1's validity
      principle, and **the acceptance rate is re-measured after either**, because a steering
      that pushes rejections above half the machine count sends the draw back (0033 item 2).
- [ ] **Step 9.** The F8 draws: with probability `p` a slot names a symbol that is never built;
      with probability `q` an allocated node is attached to nothing. **Both are members of the
      steering record, and the PROPERTY LANE'S VALUES ARE `0`** — the row they serve is design
      §4.6's ("each rule fires ≥ 1 and stays silent ≥ 1 across the draws"), §4.6's drive is
      "§4.4's generator **with its structural steering off**", and §4.6 is **Slice ④'s**.
      Slice ② builds and measures the draws; Slice ④ turns them on. Nothing in 0033, §4.3,
      §4.4, §4.10 or §7 asks **this** lane to produce either code, and charging them to the one
      gate 0033 makes blocking would be spending the floor's budget on another slice's oracle.
      **Expected, as literals, measured through this generator in the scratch worktree — not in
      the lane's own ledger:** with `p` and `q` at Task 2 Step 9's chosen pair, `missing-target`
      **> 0** and `unreachable-node` **> 0** over 2000 draws (both are **0 / 8800** without
      them); with `p = q = 0`, the lane's configuration, both back at **0** — which is also this
      step's proof that the steering record actually reaches the draw. The chosen pair is a
      literal in the generator's header and is handed to Slice ④ by Task 12 Step 7.
- [ ] **Step 10.** Delete the nine by-construction validity arguments with their comments, by
      name so nothing survives the rewrite silently: **H1** distinct case bytes; **H2** a case
      targeting `start` forced to `advance`; **H3** the same for `pausep`; **H4** the first case
      pinned to `stop`; **H5** `reject` reachable via the fixed fallback; **H6** `pausep` added
      only when a case drew it; **H7** `done` joining only as the entry's `eof-target`; **H8**
      `pausep`'s continuation `'start`; **H9** `accp`'s cycle-free shape. Decision 0033 and
      design §2 count **three**; the file's own comments name **nine**, and the six they do not
      count are precisely the ones a reader would assume survive.
      **Two of the nine are re-derived, not deleted, and the code says which.** H7 ("`§16.2:908`
      holds by construction") and H8 ("`§16.2:909` holds by construction") are exactly what
      `placed` re-expresses, under a different name and as a *vocabulary per slot* rather than
      as two hand-written special cases — **a re-anchoring, not a deletion**, and measured the
      two are worth ~20 percentage points of acceptance between them.
      Delete the four coverage pins **P1–P4** (`reexecute` on the pinned case; a pinned digit
      case; the initial `25`; overflow's own declaration) and the two dead vectors
      `base-targets` and `pause-targets`, which nothing reads.
      **Preserve two lessons whose code goes.** X1: a free case's mode was pinned to
      `reexecute` once and the mutant that unpinned it **SURVIVED** the whole release
      selection — "an unwitnessed pin reads as a load-bearing constraint and is not one". X3:
      the accumulate draw's two numbers are drawn **unconditionally** so the state after does
      not depend on the branch — a **seed-stability discipline** the new draw inherits, and one
      the plan states as a rule: *every conditional draw takes the same number of values from
      the stream on both arms.*
- [ ] **Step 11.** Re-run Task 3's lane against the rewritten generator.
      **Expected, as literals:** `RAISED`-equivalents **0** (no contract violation escapes the
      draw); the accepted count at 64 draws under the committed seed **equal to Task 2 Step 6's
      measurement, ±0** — if it differs, the shipped draw is not the prototyped draw and the
      difference is found before the floor literal is written; and the failure count from
      Task 3 Step 11 reduced to **the counter keys still reading zero, each named** (the
      totality rows are not in the tree yet — they arrive at Task 7 Step 2, which is where
      their own red is measured). "It got better" is not a measurement: the artifact is the
      **list of still-zero keys**, which Task 7 Step 6 then asserts is empty.

**Exit:** `gen-machine` takes a steering record; the draw tables are exported with the list
spelled in Step 1; **Step 1b's call-site migration landed and `fnames` occurs 0 times in either
consumer**; `rg -c` gives 13 / 4 / 7 / 7 arms; `RAISED=0` after Steps 4 and 7; `p = q = 0` in
the lane's steering record; the nine constraints are gone by name with two re-anchored under
`placed`; Step 11's accepted count matches Task 2's, ±0.

---

## Task 7 — The lane closed out: the floor literal, the counters green, the totality rows, the header

**Files:** `test/common/property-differential-tests.sps`. Same commit.

- [ ] **Step 1.** `machine-count` 40 → **64** (design §4.10). Every count downstream re-rolls:
      the seed sequence, the per-machine labels, and every pin whose witness is a drawn shape.
- [ ] **Step 2.** The totality rows, in the **program** (F18), one per family, each with the
      mandatory **seeded "found it" guard** before any comparison — a lookup that returned `#f`
      would make the comparison compare two empties and pass. Four rows derive their set from
      `ir.sls` as a datum with the shipped readers (`kind-predicates-in-source`'s shape for
      `node?` and `matcher?`; `defined-list` for `field-operations` and `field-predicates`);
      the fifth needs the **new extractor** of F18 — walk to `(define (make-callback-declaration
      …) …)`, then find the `(memq VAR '(…))` form in its body — because
      `rg -n "'memq" test/` prints nothing and §4.10 promises a row for a shape no mechanism
      reads. The remaining three families (callback outcomes, span events, schedule shapes)
      have **no source list in the tree**: their rows compare against a **declared** list with
      its `§`-line citation, and the file says it is declared.
      **Expected, as literals:** `node?` **13**, `matcher?` **4**, `field-operations` **7**,
      `field-predicates` **7**, callback kinds **4**, callback outcomes **4** (`§13:805-808`),
      span events **5** (`§14:830-836`), schedule shapes **6** (`§22.5:1278-1283`); each row's
      "found it" guard green; and **the kind row's label is not `"the same thirteen kinds"`**
      — that text is the anchor of the shipped ratchet pin "ir: node? admits a kind the matrix's
      table does not cover", and a second check printing it makes one pin resolve to two
      `(case, check)` pairs.
- [ ] **Step 3.** The shipped eight become **ten** (F10): `finished` and `field` gain
      interpreter-only twins, and `field`'s **witness changes** from `(pair? fnames)` — the
      draw — to a field value read back through `parser-field-ref` from **both** parsers and
      differing from its declared initial. The `finished` counter's comment records that it is
      a **conjunction its name does not show** (the EOF draw must have routed a finish **and**
      a byte must have left both parsers `ready`), which is the argument for its twin.
      The two witnesses hard-wired to the old draw are re-expressed: `"commits a digit"` from
      `(not (= a 25))` to "differs from the field's **declared** initial", and
      `"overflows the field"` from the exact string `"field overflow"` to
      `parser-error-node-name` equal to the drawn accumulate node's overflow error node —
      which `project-error` already compares. **Both labels survive unchanged**, so the two
      shipped accumulate pins keep their text.
      **And the shipped label IS its family member's counter** (F10): no second
      `node kind pause`, `node kind finish` or `node kind integer-accumulate` label is minted.
- [ ] **Step 4 (the floor literal).** Write it, from Task 2 Step 6(c) re-measured through
      **this** lane and **this** generator under `BYTE_MACHINE_PROPERTY_SEED`'s committed
      default, and write the command beside it in the file.
      **Expected, as literals:** the measured accepted count at 64 draws; the literal set **no
      lower than 32** and **no higher than the measured count**; and the comment naming the
      seed it was measured under (0033 item 3). Beside it, the sentence F1 requires: *the floor
      does not measure what it is for on its own — a draw steered to a single error node per
      machine would clear it while every counter of item 2 read zero; what stops that is the
      counters.* Then set Task 3 Step 7's sentinel literal from the same run.
- [ ] **Step 5 (the span counter, measured FIRST).** Before any other counter is called green,
      run the lane under the committed seed **and under three more** and read the
      span-fragment counter's **observed** value in both halves.
      **The gate is the committed seed.** Decision 0033 item 2 asserts each counter "≥ 1 over
      the seed set"; item 3 fixes one committed default that "CI and every pin run"; design
      §7's Oracle reads "every counter ≥ 1 in both halves **under the committed seed**". This
      plan raises no single-seed contract into a four-seed release gate — that would be an
      invented criterion, and 0033 is a Gate 0 record a plan may not tighten any more than it
      may weaken.
      **Expected, as literals:** **≥ 1 in both halves under the committed seed.** Under seeds
      **1**, **7** and **99** the counter's value in both halves is **recorded beside it**, in
      the file, as a diagnostic — not asserted.
      **The stop conditions, and what each one means.** A **zero under the committed seed**
      stops the task: either the `span-body` shape of Task 6 Step 6 did not land, or the
      schedule sweep is not reaching the span. A **zero under a non-committed seed** is
      **recorded with its number** and sends the drawn multi-byte inputs and the schedule sweep
      back for measurement — it is **not** declared a defect in this slice, because F5's own
      table measures **4 / 0 / 0 / 3** at 40 machines × 256 single-byte trials **with the
      `span-body` shape already applied**: the shape landed and two seeds still read zero, so
      the two named causes are not an exhaustive disjunction and a rule that says "stop"
      on them would pre-classify its own failure. This is still the single most likely way the
      oracle goes red for a reason that is not a defect, and measuring it first is what tells
      the two apart.
- [ ] **Step 6.** Every remaining counter, both halves, under the committed seed, **each read
      from the trial**.
      **Expected, as literals:** all **96** checks green; and the **second** most likely to
      flap, measured, named here so it is checked next: the per-operation and per-predicate
      counters, which at 64 draws under a uniform draw left `clear` **absent** and five more at
      one. Round-robin (Task 6 Step 4) is what fixes them; this step is what proves it did.
- [ ] **Step 7.** The steering totality row: the count of steerings named in the generator's
      header equals the count in its steering record, asserted rather than left to prose
      (Task 2 Step 10).
- [ ] **Step 8.** The lane header, with the blind-spot paragraph of Task 5 Step 5 (or a pointer
      to the driver's). Design §7's Oracle makes this a **scored item**: "*Nothing agreed-wrong
      is claimed:* the header names `§12.7:770`'s open half as the value this lane cannot see."
- [ ] **Step 9.** Run both lanes.
      **Expected, as literals:** `ctest --preset release -R 'property\.differential'` →
      `100% tests passed, 0 tests failed out of 2`; and the **counter values identical** between
      `.chez.source` and `.chez.aot` (design §7's oracle: "the source and AOT registrations
      green with identical counters"), compared by capturing both runs' output rather than by
      both being green.
      Record the new `checks=` value. It is **not** a free number, and the decomposition has to
      close against the **measured** baseline rather than against a remembered one. Task 1
      Step 3 measures `checks=89` and decomposes it as `1 (PRNG) + 40 (machine i verifies) +
      40 (byte agreement) + 8 (counters)` — so there are **40** `verifies` checks to remove, not
      64, and the agreement checks **grow** by 24 when `machine-count` goes 40 → 64:

      | term | value |
      |---|---|
      | baseline | **89** |
      | the per-machine `verifies` checks go (all 40, at `machine-count` 40) | **−40** |
      | the shipped eight counters are absorbed into the counter table | **−8** |
      | the per-machine agreement checks grow 40 → 64 | **+24** |
      | the counter table arrives (F10) | **+96** |
      | the floor, the structural equality and the accounting | **+4** |
      | the totality rows | **~+16** |
      | the sentinels | **~+8** |
      | Layers 2 and 3 | **~+16** |
      | | **≈ 205** |

      The plan predicts **200–260** and the tree overrides the prediction.
      **The discipline that keeps it there** is the shipped one: one `bad` accumulator per
      machine, asserted once, never a `check` per trial. A `check` per trial would be
      64 × (256 + 8 × ~50) ≈ **24 000+** checks and an unreadable mutant output.

**Exit:** the floor literal written with its command and its seed; Step 5's span counter ≥ 1
in both halves under the committed seed and the other three recorded; all **96** counter
checks green; both lanes green with identical
counters; the new `checks=` recorded.

---

## Task 8 — CMake: the manifests, the environment, the measured timeouts

**Files:** `test/CMakeLists.txt`. Same commit.

- [ ] **Step 1.** Insert
      `"${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/property-driver.sls"` into
      **both** `SOURCES` lists, at the **same index** — immediately after the `machine-gen.sls`
      line in each. The reason is the **fingerprint**, not compile order: `SOURCES` reaches
      four consumers (the existence guard, the duplicate-basename guard, the measured list, the
      expectation) and **no compiler invocation**, and `harness-fingerprint-combine` is
      order-sensitive by design, so `measured[i]` must correspond to `declared[i]`. **Do not
      cite `test/CMakeLists.txt:153-160`'s "so every AOT lane compiles it before anything that
      imports it"** — that reason is false (F20) and repeating it would be a false supporting
      argument for a correct placement.
      **Expected, as literals:** after reconfigure,
      `rg -n "property.differential" build/dev/test/CTestTestfile.cmake` shows **16** entries
      in `BYTE_MACHINE_FINGERPRINT_FILES` (15 today), all **distinct basenames**, and **one
      shared `BYTE_MACHINE_EXPECT_FINGERPRINT_FILE` key for the two lanes**. Two different keys
      means the insertion indices diverged.
- [ ] **Step 2.** Add `ENVIRONMENT "BYTE_MACHINE_SOURCE_ROOT=${CMAKE_SOURCE_DIR}/src"` to
      **both** registrations, with the precedent comment's reason
      (`test/CMakeLists.txt:1654-1655`: "under the mutation suite it must read the STAGED
      tree"). Add one sentence stating that this does **not** contradict decision 0033 item 3's
      "The registrations pass nothing" — that clause is about the **seed** — so a reviewer does
      not read a conflict.
      **Expected, as a literal:** without this line the rewritten lane **raises at startup**
      under `ctest` and **passes** under the mutation suite (which sets the variable
      process-wide at `SchemeMutationSuite.cmake:1509`) — the harder direction to notice, which
      is why the step exists. Verify by running the source lane through `ctest` **and** through
      the mutation lane and requiring both green.
- [ ] **Step 3.** Keep `TIMEOUT 180` on the **source** registration, with the measurement in a
      comment beside it: **0.31 s wall at 40 machines, a factor of 580**, and the cost model
      (≈0.20 s fixed, ≈1 ms per emit+load, ≈3 µs per single-byte trial pair). There is no
      evidence it needs raising and none that it can safely be lowered; lowering it would be a
      new decision.
- [ ] **Step 4 (the measurement design §7 actually asks for).** Measure the **AOT** lane. It
      **compiles** rather than loads, no measurement of it exists anywhere in the tree, and
      design §4.10's "both lanes stay under the shipped 180 s timeout with margin" asserts
      something about a lane nobody has timed.
      ```sh
      cmake --preset dev && cmake --build --preset dev
      ctest --preset release -R '^byte-machine\.property\.differential\.chez\.aot$' \
            --output-on-failure --no-tests=error
      ```
      **Expected:** CTest's own per-test `Passed <seconds> sec`. Record it. Set the AOT
      `TIMEOUT` from it with the same kind of margin the source lane has, or keep 180 and say
      the measured number is why. **Do not read
      `build/dev/Testing/Temporary/CTestCostData.txt`** — its third field is CTest's decayed
      cost estimate, not seconds (it gives 0.539 for a lane that takes minutes).
      Take the source lane's number the same way, in the same run, so the two are comparable:
      `ctest --preset release -R 'property\.differential'` prints both.
- [ ] **Step 5.** Correct design §4.10's "the shipped lane runs in under a second" in place
      with the two measured numbers (Task 12). It is a **bounds justification the plan acts
      on** — an instruction, not a record.
- [ ] **Step 6.** Confirm nothing else was needed, by running the three negatives rather than
      asserting them: no AOT compile list exists (`chez-compile.ss` is given no library list;
      `(compile-imported-libraries #t)` + `(compile-program …)` follows the import graph); no
      checked-in fingerprint manifest exists (the expectation is a **build output**, derived
      from `SOURCES`); and the mutation suite stages **directories**, so the new library is
      staged with no edit — verified by running the mutation lane and confirming it resolves
      `(byte-machine test property-driver)` from `${STAGE_DIR}/test/support/harness`.

**Exit:** one shared fingerprint key across the two lanes; both lanes carrying
`BYTE_MACHINE_SOURCE_ROOT`; both timeouts justified by a number measured in this task; the
three negatives verified rather than assumed.

---

## Task 9 — Pass 39's six mutations, decided by LABEL

**Files:** `test/support/cmake/SchemeMutationSuite.cmake`. Same commit.

F13 decides all six. This task executes those verdicts and **measures the two retirements**,
which is the one edit a clean sweep cannot see.

**One ordering dependency, named here because the checkbox order otherwise hides it.** Steps 5
and 6 measure each retirement against "every mutation remaining in Pass 39 **and every new
mutation this slice adds**" — and the new mutations are written in **Task 10 Step 2**, which
runs after this task. Executed in checkbox order, Steps 5–6 would take the accept/refuse
decision against the **four survivors alone**, which is precisely the coverage-claim-instead-of-
collision-claim shape AGENTS.md's retirement rule exists to stop, and an incorrect outcome here
is invisible downstream because no sweep can see a retirement. **So:**

- **Step 4 gains a precondition**: the thirteen kind pins and the four matcher pins of Task 10
  Step 2 are **drafted first** — at minimum the `integer-accumulate` one, which is LABEL 5's
  candidate replacement — and Steps 5–6 measure against the drafted set as well as the
  survivors;
- and **Task 11 gains Step 0**, which re-runs Steps 5 and 6's measurement over the **full
  post-Task-10 mutant set** and freezes the tombstones' numbers from that run. A retirement is
  **refused** if the witness list is empty against that full set, not against the four
  survivors.

- [ ] **Step 1 (LABELs 1–4, the re-anchors).** For each, change what F13 says and nothing
      else, and read the `FIND` and the `REPLACE` **together** afterwards, asking what single
      decision separates them:
      - **LABEL 1** — `FILE`, `FIND` and `REPLACE` untouched (`compile.sls` is outside this
        slice); the **pin** re-anchored onto the rewritten agreement label, naming one machine
        index with its parens escaped, and its comment naming the seed it was measured under.
      - **LABEL 2** — `FILE` becomes the driver library's path; `FIND` re-anchors onto the
        driver's **single** resume site; the `REPLACE` is rewritten so it echoes the ack the
        real call would have returned for the lifecycle it fakes, because the new draw can
        reach `paused-finish` and `(list 'feed-ready 'feed-ready)` would then change **two**
        things.
      - **LABEL 3** — `FIND` onto the `pause-node?` / `make-pause-node` row of the kind table;
        `REPLACE` removes that row (**not** a `#f` hard-wire, which no longer exists); the pin
        becomes the **full interpreter-only label plus ` -- expected a true value`**, never
        `"observes a pause"`.
      - **LABEL 4** — `FIND` onto the EOF-route member list; `REPLACE` removes the finish
        member.
      **Expected, as literals:** each re-anchored `FIND` occurs **exactly once** in its
      declared `FILE`; each mutant exits **1**; each pin matches **exactly 1** record of its own
      mutant's output and **0** of every other Pass 39 mutant's.
- [ ] **Step 2 (LABEL 4's nesting, measured before it is pinned).** Two mutants can zero the
      same counter: the `finish-node?` **kind** draw arm removed, and the finish **member** of
      the EOF-route set removed. Measure the subset relation **in both directions** over their
      normalised FAIL-record sets.
      **Expected:** either two sets each owning a unique record — in which case both pins are
      written — or a containment, in which case **one is kept and the nesting is recorded in
      the tree beside it, named by mutation LABEL**, because the session ledger is git-ignored.
      The tree's own reason for expecting containment is `machine-gen.sls`'s header ("done
      (finish) joins the graph only when drawn as the entry eof-target, so it is never
      byte-reachable") and F7's census says the same: the EOF route is the only accepted
      producer of a reachable finish.
- [ ] **Step 3 (the three corrections in this file that are not pins).** All three are
      **instructions**, corrected in place:
      - `SchemeMutationSuite.cmake:537-542`'s "Pinned to 'observes a pause' … otherwise unused
        in this program" and `:8613`'s "unique to this one check" — **measured false**, two
        labels contain the phrase and the pin matches twice (F14);
      - `:1398-1411`'s SUBSUMED entry `p39 pause draw, eof draw < inverted dispatch byte test
        (two)` — **measured false in both directions** (F15). Corrected **dated, keeping the
        retraction**, with a note that `:1483-1489`'s "still declined" describes a remedy the
        tree already contains (M4 Slice ③'s interpreter-only counters), and that it did **not**
        weaken the agreed guard because both halves are asserted;
      - `:10107-10112`'s `checks=83 failures=30` → **`checks=89 failures=36`** for both
        `hv-first` and `hv-last`, and its `machine-gen.sls:83, :96, :120-131` citations, none of
        which is a construction site and all of which point into text this slice deletes —
        replaced by **construct names**, not new line numbers.
      Plus the same false claim's twin at `test/common/position-kind-tests.sps:439` ("the
      property lane … fixes two declarations with distinct codes" — it fixes **three**, two
      sharing the code `unexpected-byte`, and applying the mutation that comment justifies
      reddens **14** records of the property lane).
- [ ] **Step 4 (stage the deletion).** **Precondition, from this task's preamble:** Task 10
      Step 2's thirteen kind pins and four matcher pins are **drafted first** — at minimum the
      `integer-accumulate` one, which is LABEL 5's candidate replacement — so that Steps 5 and 6
      measure against the drafted set as well as the four survivors. Then delete Pass 39 blocks
      5 and 6, put draft tombstones in their place, leave `EXPECTED_MUTATIONS` **unmoved**, and
      `git add -A`.
      **Expected, as a literal:** `git status --short` shows **nothing unstaged**. Stage first:
      `git checkout --` to undo a hand-applied mutation wipes the task's own unstaged
      implementation, and this task applies mutations by hand for the next three steps.
- [ ] **Step 5 (the retirement measurement, LABEL 5).** For every mutation remaining in Pass 39
      **and** every new mutation drafted under this task's precondition, apply its
      `FIND`→`REPLACE` to a **scratch copy** of the staged tree, run Pass 39's verify command,
      and save stdout+stderr. Restore in a `finally`. **The numbers are provisional until
      Task 11 Step 0 re-runs this over the full post-Task-10 set** — the tombstone is written
      here and its numbers are frozen there.
      **Expected, per mutation:** the `FIND` count equals its declared `SITES` — any other
      value stops the step. Then grep every captured output for the check LABEL 5 owned — the
      rewritten lane's **digit-commit** anti-vacuity label, in full — and print the LABELs whose
      output contains it.
      **Expected: a NON-EMPTY list**, written verbatim into the tombstone. **If the list is
      empty the retirement is REFUSED** — the digit arm has lost its only witness and LABEL 5 is
      **re-anchored** onto the integer-accumulate kind's draw arm instead.
      Then measure the replacement pin: with `pin` = the accumulate draw-arm mutation's
      `EXPECT_OUTPUT_MATCHES` and `out` = each captured output,
      `len(re.findall(pin, out, re.DOTALL))`. **Expected, exactly: `1` for its own output and
      `0` for every other.** And confirm the replacement mutant **separates the arm**: its
      output must contain at least one record no other Pass 39 mutant's contains. An empty set
      means the replacement is subsumed and the retirement is refused.
- [ ] **Step 6 (the retirement measurement, LABEL 6, plus its two refused re-anchors).** The
      same shape over the **overflow** label, and **additionally**, before retiring, run the
      two candidate re-anchors so the tombstone's refusal is measured rather than argued:
      - force the drawn field initial to **0**. **Expected:** the overflow anti-vacuity check
        still **passes** — six base-10 digits overflow a u8 from 0 and §4.4 draws inputs up to
        six bytes — i.e. the mutation does not witness the decision. Record the observed counter
        values.
      - force it to **`(- (expt 2 width) 1)`**. **Expected:** the **commit** check fails and the
        **overflow** check passes — a different decision, LABEL 5's territory.
      **If the first unexpectedly zeroes the overflow counter, LABEL 6 is re-anchored onto the
      initial draw and not retired**, and this plan says so rather than the task discovering it.
- [ ] **Step 7 (the tombstones).** Write both, at the site, each carrying: what the construct
      was; why the decision no longer exists (for LABEL 5, the mutation's **own stated reason**
      — "byte-trial feeds ONE byte to a fresh pair" — against §4.4's 0–6-byte inputs under every
      split point); that this is a decision a later fix made **unobservable**, not one a
      refactor relocated, so there is no new reader to re-anchor onto; for LABEL 6, the two
      **measured refused re-anchors**; and the Step 5/6 numbers with the date, the seed and the
      command. Only then move `EXPECTED_MUTATIONS`.
- [ ] **Step 8.** Correct the banner, **as literals and not as a description** — this is the
      one surface no test can check, and "correct it to the real pass count" is the prose
      expectation this project records as getting reported as passing without being run.
      Measured today: `:9` reads `# FIFTY-FIVE PASSES, BECAUSE FIFTY-FIVE DIFFERENT WITNESSES
      ARE NEEDED`, `:177` reads `See "FIFTY-FOUR PASSES..." above`, and `EXPECTED_PASSES` is
      **58** (`:1363`).
      **→ `:9` becomes `# FIFTY-EIGHT PASSES, BECAUSE FIFTY-EIGHT DIFFERENT WITNESSES ARE
      NEEDED`; `:177` becomes `See "FIFTY-EIGHT PASSES..." above`.**
      **Expected afterwards, as a literal:**
      `rg -c 'FIFTY-FIVE|FIFTY-FOUR' test/support/cmake/SchemeMutationSuite.cmake` → **0**.
      The banner's own text names the defect: "a banner left at the old number is the one
      surface no test can check." This slice edits the constants anyway and is the natural
      receiver.
- [ ] **Step 9.** The header narrative entry, at the **top** of the running narrative (it reads
      newest-first), in the form the file already uses, stating the retirements separately from
      the additions: `"Milestone 7 Slice ②: … TWO removed (their decisions no longer exist;
      tombstones at the site), <A> added. Mutations 536 − 2 + <A> = <N>."`

**Exit:** four re-anchors each matching exactly once; two tombstones each carrying a
non-empty witness list, a 1/0 replacement measurement and a non-empty separating set, or a
refusal recorded and the mutation re-anchored instead — **all three numbers provisional until
Task 11 Step 0 re-runs them over the full post-Task-10 mutant set, which is where they are
frozen**; the three corrections dated; the banner reading `FIFTY-EIGHT` at `:9` and `:177` with
`rg -c 'FIFTY-FIVE|FIFTY-FOUR'` → **0**; the narrative current.

---

## Task 10 — The pins this slice adds

**Files:** `test/support/cmake/SchemeMutationSuite.cmake`. Same commit.

**Where the new blocks go, measured against the runner rather than derived from the general
rule.** `byte_machine_mutation()` **appends** to the accumulating list,
`byte_machine_mutation_run()` runs whatever has accumulated, and
`byte_machine_mutation_reset()` **zeroes** it — `MutationRunner.cmake:87-127`
(`byte_machine_mutation`), `:247-249` (`byte_machine_mutation_reset`, whose whole body is
`set(_bm_mutation_count 0 PARENT_SCOPE)`) and `:252` onward (`byte_machine_mutation_run`, which
refuses outright when `_bm_mutation_count EQUAL 0`). Pass 39 is, measured: `byte_machine_mutation_reset()` at
`SchemeMutationSuite.cmake:8559` → `set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND …)` at
`:8561-8567` → six `byte_machine_mutation(` blocks at `:8569-8664` →
`byte_machine_mutation_run(…)` at **`:8666`** → the **next** pass's
`byte_machine_mutation_reset()` at **`:8669`**.

**So: new blocks go BETWEEN Pass 39's `reset()` (`:8559`) and its `run(…)` (`:8666`) — i.e.
immediately after the existing sixth block and before the run.** The general rule this plan
inherits — "after the previous pass's `byte_machine_mutation_run`, never before a `reset()`" —
is the rule for opening a **new** pass, and applying it to a **join** puts the blocks between
`:8666` and `:8669`, where the next pass's reset discards them: never staged, never verified,
never counted by `byte_machine_mutation_totals`, so `EXPECTED_MUTATIONS` would not close
against the harness's own total. Placed after `:8669` instead they join **Pass 40** and run
under Pass 40's verify command, which does not execute the property program at all, so every
pin would be judged against the wrong output. Slice ② **joins** Pass 39 (F16), so the join is
the case that governs.

**Expected, as literals, after the edit:** `byte_machine_mutation_run(` occurs **exactly
once** between `:8559` and the next `reset()`; and the run's reported per-pass mutation count
is **4 + A** (six blocks less Task 9's two retirements, plus the additions).
`EXPECTED_PASSES` stays **58**.

- [ ] **Step 1.** The verifier-filter mutation: the verdict test in the lane program replaced
      by the unconditional form. **Pin:** `"no draw reached an executor unverified"` —
      the check's own words, from Task 3 Step 5's `fed-unverified` comparison, so the catch is a
      **comparison and not a raise**. Measured expectation: under the mutant, `fed-unverified`
      reads the rejected count and `interpreted-count` exceeds `accepted-count`, so **two**
      comparisons name the decision.
- [ ] **Step 2.** The **thirteen** kind pins and the **four** matcher pins, one per member of
      `node?` and `matcher?`, each removing that member's row from the generator's draw table.
      **Every `FIND` carries its arm's own discriminating token** and the arms share no
      `let`-binding vocabulary that makes a one-line anchor ambiguous (F17(b)); **every pin is
      the interpreter-only half's full label plus ` -- expected a true value`** (F11); and each
      pin's comment names the seed it was measured under.
      **Two questions the partition of F12 forces, asked of every arm-removal mutant, because
      no other step asks them.** The counter loop lives in a **second** `harness-case` entered
      only when the floor held, so **any** mutant that drops the accepted count below the floor
      suppresses **all 96** member labels — and then its own pin, which F11 mandates be an
      interpreter-only counter label living in that second case, matches **zero** records and
      the mutation reads UNCAUGHT or wrong-reason. Two of this task's own mutants are
      candidates:
      - **the acceptance rate.** F3 measures single kind-vocabulary changes at **±2.6 to −44.5
        points**. **Expected, per arm-removal mutant, as a literal:** the **floor check is still
        green** under that mutant (so its counter case runs) and the mutant exits **1** by a
        **failed comparison**, not by a raise. An arm whose removal reddens the floor is
        re-pinned on the floor's own label, or the arm is drawn at a rate that keeps the floor,
        and the choice is recorded at the site.
      - **the byte-dispatch arm against the `entry-bd` steering.** `entry-bd` forces the entry
        to be a byte dispatch (F3 row 6) and this family removes the byte-dispatch row from the
        kind table — a contradiction the generator may resolve by **raising or by looping**
        rather than by failing a comparison, against this plan's own "prefer the comparison
        catch". **The fallback, named here rather than discovered:** drop `entry-bd` under that
        one mutant (a steering-record value, so the mutation can set it), or carry the
        byte-dispatch counter in the **first** `harness-case` beside the floor. Measure which
        before pinning.
      **Expected, as literals:** each `FIND` occurs **1** time; each pin matches **1** record of
      its own mutant's output and **0** of every other Pass 39 mutant's. (No cross-SPEC
      requirement here: a pin is judged only against its own pass's verify-command output, and
      Pass 39's command at `SchemeMutationSuite.cmake:8567` is the only one in the suite that
      runs this program — Task 11 Step 3 carries the two literals.)
- [ ] **Step 3.** The script pin (the callback script answering `continue` unconditionally —
      witnessed by the branch and failure outcome counters), the schedule pin (the split-point
      sweep collapsed to one feed — witnessed by the schedule-shape counter), and **six**
      invariant pins, one per Layer-3 row, each inverting that row's comparison.
- [ ] **Step 4 (the floor pin, and the case partition it requires).** The witness is **a mutant
      that rejects everything**, not a deleted check — `EXPECT_SURVIVES` is refused here by
      design §7. Its `FILE` is the generator (a draw that produces only invalid machines) or
      `verify.sls`; since this slice touches no `src/` file, **the generator** is the carrier.
      **Pin:** the floor check's own label.
      **And this is the pin that forces F12's partition.** A rejects-everything mutant zeroes
      **every** counter as well as the floor, so without the partition all 96 counter pins are
      also satisfied by it — nesting **by construction**. With the floor and the structural
      equality in their own `harness-case` and the counter loop in a second case entered only
      when the floor held, the mutant produces **none** of the member labels.
      **Expected, as literals, measured:** under the floor mutant, **exactly two checks red in
      the FIRST `harness-case`** — the floor check and Task 3 Step 7's skip sentinel, which
      lives in that first case precisely so it can fail here (inside the second case it would be
      skipped by the condition it exists to witness, and this expectation would be
      unachievable) — and **0** occurrences of any per-member counter label in the mutant's
      output. A nonzero count there means the partition did not land and every counter pin is
      non-discriminating against it.
- [ ] **Step 5.** For every new pin, the pair (`EXPECT_STATUS`, `EXPECT_OUTPUT_MATCHES`) is the
      discriminator, and every regex metacharacter is escaped — `(`, `)`, `.`, `[`, `]`, `*`,
      `+`, `?`, `|`, `^`, `$`. Note `$` anchors the **end of the whole captured output**, not a
      line, and `.` matches newline, so **no `.*` between `expected` and `got`**: it bridges to
      a later record.
- [ ] **Step 6.** Every `REPLACE` is regenerated **from the post-edit source**, mechanically,
      never hand-edited from the old text — that is how a `REPLACE` silently starts changing two
      things. Read each `FIND` and `REPLACE` together and name the single decision that
      separates them.
- [ ] **Step 7.** Judge every **nesting** the new families create, in both directions, before
      any pin is committed: every per-kind arm against the verifier-filter mutation; the
      kind/EOF-route pair of Task 9 Step 2; and each Layer-3 inversion against the others.
      **Expected:** each pair either owns a unique record on both sides, or the containment is
      recorded in the tree beside the surviving pin, named by LABEL, with the measurement —
      and the **kind** of containment stated, because a nesting **by construction** is
      genuinely closed while a subset with zero unique records may mean the spec is
      under-specified rather than the pin unfixable.
- [ ] **Step 7b (the Global Constraint "prefer the comparison catch", measured rather than
      preferred).** From Task 9 Step 5's captured outputs — which already exist, for every
      mutation — record for **each new mutant**: its **FAIL-record count**, and the count of
      **distinct** records among them.
      **Expected, as literals:** **no new mutant fails more than 8 records**, and **no new
      mutant fails ≥ 4 records identically** (the same normalised `(case: what)` text). A
      mutant outside either bound is a **crash or a broad breakage to re-shape**, not a pin to
      keep, and is re-shaped here.
      **The precedent that earns the bound**, from AGENTS.md: Slice ⓪b's
      `(car (node-out-edges n))` failed **109 of 116** cases *identically* with a green pin —
      the mutation reported caught, the sweep clean, and nothing had been discriminated. Task 9
      Step 5 captures the data; without this step nothing asks the question of it, and ~27 new
      mutations is the plan's largest unmeasured surface.
- [ ] **Step 8.** Re-sweep the whole pass after **each** fix, not once at the end. Adding a
      *check* widens pins just as adding a mutation does, and a first attempt can collide with
      a third mutant.
- [ ] **Step 9.** Count `A`, move `EXPECTED_MUTATIONS`, and **re-measure from the harness**.
      **Expected, as literals:** `EXPECTED_MUTATIONS_new = 536 − 2 + A`; `EXPECTED_PASSES`
      unchanged at **58**; the lane's own totals line
      (`scheme mutation suite complete (58 passes, <N> mutations)`) reporting the same `<N>`.
      F16's lower bound is **27**, giving 561 — **a prediction the tree overrides**, and the
      nesting measurements of Step 7 can reduce it.

**Exit:** every new block placed **between** Pass 39's `reset()` and its `run(…)`, with
`byte_machine_mutation_run(` occurring exactly once in the pass and the run reporting **4 + A**;
every new pin matching exactly once in its own mutant's output and zero elsewhere in its pass;
every arm-removal mutant leaving the **floor green** and exiting 1 by comparison; Step 7b's
FAIL-record and distinct-record counts inside their bounds; the floor mutant reddening exactly
the floor check and the skip sentinel in the **first** case and producing no member label;
`A` measured; the totals closing.

---

## Task 11 — The sweep, the match-count matrix, and the label audit

**Files:** none modified unless the sweep finds something. Same commit if it does.

- [ ] **Step 0 (the retirement measurement, re-run over the full mutant set).** Re-run Task 9
      Steps 5 and 6's measurement — the witness list for each retiring LABEL's check, the 1/0
      replacement-pin count, and the separating set — over the **complete post-Task-10 mutation
      set**, not the four Pass 39 survivors it was first taken against. Task 9's numbers are
      provisional until this step; the tombstones' numbers are **frozen from this run**, with
      this run's date and command.
      **Expected:** the same accept/refuse verdict Task 9 recorded. **A verdict that flips here
      is the finding** — a retirement accepted against four survivors and refused against the
      full set was accepted on an incomplete measurement, and no sweep downstream can see it.
- [ ] **Step 1 (the two-direction sweep, against a control at the base).** Re-judge every Pass
      39 pin against every **other** Pass 39 mutant's captured output, through
      `byte_machine_mutation_verdict`'s own logic, **in both directions**.
      **The control is Task 1 Step 8's matrix, taken at this slice's own base** — diagonal
      `40 / 1 / 2 / 1 / 1 / 1`, with exactly **three** off-diagonal non-zeros (`pause`, `accp`
      and `init`'s pins against the `bytetest` mutant, each **1**). The step's body **compares
      the two**, which is the comparison that separates an introduced collision from inherited
      debt and is the reason AGENTS.md asks for a control at all.
      **Expected, as literals:** **0** in every off-diagonal cell at HEAD; every cell that is
      **0 at HEAD and nonzero at the base** is a fix this slice made — the three known ones —
      and is named in the print-out; any cell **nonzero at HEAD and zero at the base** is this
      branch's doing and **stops the commit**. Print both matrices, the way F13's is printed, so
      the record is a matrix rather than a claim.
- [ ] **Step 2 (the per-pin match count — the check the sweep cannot make).** For every
      mutation `m` in Pass 39 after the rewrite, with `out(m)` its own captured output and
      `pin(m)` its `EXPECT_OUTPUT_MATCHES`: `len(re.findall(pin(m), out(m), re.DOTALL))`.
      **Expected, literally `1` for every `m`. Not "≥ 1", not "matched".** And for every
      ordered pair `m ≠ n`: **literally `0`**.
      The current matrix has **two** diagonal violations (`bytetest` at 40, `pause` at 2) and
      **three** off-diagonal non-zeros; a matrix with any non-`1` diagonal cell or any non-`0`
      off-diagonal cell **stops the commit**.
      The `bytetest` diagonal is the one that needs a disposition and F11 takes it: the pin
      **names one machine index** with its parens escaped, re-measured after the rewrite —
      not the alternative reading of the rule, because a plan that reinterprets design §7's
      oracle to fit the tree is weakening it.
- [ ] **Step 3 (the cross-SPEC direction, closed by construction and recorded as such).**
      **Expected, as literals, and this is the whole step:**
      `rg -n -- '--program.*property-differential-tests.sps' test/support/cmake/SchemeMutationSuite.cmake`
      → **one line, `8567`**, inside Pass 39's `set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND …)`;
      and `sed -n '164,170p' test/support/cmake/MutationRunner.cmake` shows
      `byte_machine_mutation_run_spec` taking `BYTE_MACHINE_MUTATION_VERIFY_COMMAND` whenever it
      is set and **ignoring the mutation's `SPEC`**, with the variable `set()` **48 times** and
      never unset. **Together those two say a pin is judged only against its own pass's
      verify-command output**, so a `compile.sls` mutant declared under another SPEC can never
      produce a property-lane record, let alone match a Pass 39 pin. The direction is closed by
      construction, not by a sweep.
      **The measurement that looked like it said otherwise, kept as a note.** Running the
      property program **by hand** under `compile: an error declaration is resolved by code
      alone` (Pass 46) gives `exit=1` and **14** FAIL records including the overflow counter
      (F15). It is true and it is interesting — it says the property lane would catch that
      mutation if it were declared under this SPEC — and it is **not** a collision: nothing
      runs the two together. Record it beside the pins with that sentence, and do **not** write
      a required exit criterion on it.
- [ ] **Step 4 (the label audit, run again after the fix wave).** Re-run Task 3 Step 10 over
      the labels as they finally stand — a fix wave moves labels, and a label audit run once
      before the fixes is an audit that did not see them.
      **Expected, as a literal: no hit**, for every check label against every pin of this SPEC
      lane, except the pin that owns it.
- [ ] **Step 5 (what a clean sweep does NOT say, recorded in the tree beside the pins).**
      AGENTS.md: "A whole-pass sweep re-judges the pins that EXIST; it cannot notice a decision
      no pin names." A clean Step 1 says nothing about Task 9's two retirements, and nothing
      about a construct in the rewritten generator that no pin names. Write that sentence
      beside Pass 39's header, with the two retirements named, so the next reader does not read
      a clean sweep as coverage.

**Exit:** Step 0's re-run verdicts matching Task 9's, and the tombstones' numbers frozen from
it; an all-zero off-diagonal matrix and an all-one diagonal at HEAD, printed **beside Task 1
Step 8's base matrix**, with every changed cell accounted for in one direction or the other;
Step 3's two literals recorded; Step 4's "no hit"; Step 5's sentence in the tree.

---

## Task 12 — Both ends, the records, and the status surfaces

**Files:** `docs/plans/milestone-7-design.md`, `docs/decisions/0033-property-suite-contract.md`,
`docs/decisions/0022-structured-parser-error-record.md`,
`docs/plans/byte-machine-implementation-plan.md`, `CHANGELOG.md`, `README.org`. The
**documentation commit**.

**Record vs instruction, applied once here and then per item.** A design paragraph a slice
cannot follow is an **instruction**: corrected in place, dated. A decision record's **items**
are instructions inside a record: corrected in place with a dated note at the foot and a
header bullet. A decision record's **Context** is a measurement of the tree it was decided
against and is **not touched** — where this plan's numbers differ, the difference is stated
here and in the note, never written back into the Context.

- [ ] **Step 1 (design §4.4: SIX corrections and one tightening, in place, under one dated
      note — plus the design Appendix's matching line).** §4.4 is not a record of what was
      measured; it is the paragraph a slice implements, and design §4.6 makes it **the only
      specification Slice ④ has of the free mode** ("§4.4's generator with its structural
      steering off"). A sentence the shipped generator contradicts is therefore an instruction
      that will mis-direct the next slice, and every one of them is corrected here — **or the
      reason it is left standing is written down, per item**. An earlier draft of this plan
      corrected three and left four standing; they are enumerated so the count is checkable.

      1. **The span sentence, tightened rather than corrected** (F5 + F6, merged because they
         are one sentence seen from two sides). §4.4 reads "a matched start/end pair **whose
         end has a private error sink** and a non-terminal successor". Two things are true at
         once: `make-span-end-node`'s parameter list is `name span next source-label`
         (`src/byte-machine/private/ir.sls:620`), so **the end has no error slot** and the sink
         cannot attach there (a fifth argument raises a **raw arity error with no `who`**, and
         the same mistake on `make-counted-consume-node` is **silent**); and §4.4's own warrant
         for the sink — "a shared sink joins `none` with `(active s)` (decision 0029 item 2)" —
         is a claim about a node reached **with a span open**, i.e. an input-reading node
         *inside* the span. **§4.4 therefore already presupposes the body node.** The pairing
         sentence **stands**; it gains, explicitly: *start → one advancing one-case byte
         dispatch carrying its OWN private EOF error node → end*, with the `counted-machine.sls`
         precedent named and the measurement beside it (**0 / 0 / 4** fragment machines;
         acceptance **1160 vs 1128**). The note says the sentence's own "private error sink"
         clause is what implies the body, and that the adjacent realisation was the prototype's,
         not §4.4's.
      2. **"Kinds are drawn *uniformly* from `node?`'s thirteen disjuncts"** → the
         **round-robin-with-a-random-phase** rule, with its measured reason: at 64 draws under
         the committed seed a uniform draw leaves `clear` **absent entirely** and five more
         operations at exactly one machine, and item 2 requires an **observed** value, which is
         strictly rarer than presence (Task 6 Step 4).
      3. **"read from `ir.sls` *at run time* — the S2 technique … so a fourteenth kind reddens
         *the generator's own* totality row"** → the draw tables are **hand-written tables in
         `machine-gen.sls`, exported**, and the totality rows live **in the property program**,
         deriving `ir.sls`'s set and comparing it to those keys. F18's operand argument is the
         reason and goes with it: *if the generator drew from the runtime-read list, the row
         would compare `ir.sls` against `ir.sls` and close nothing.* **The design's Appendix
         carries the same stale description — "the generator's draw tables (kinds, matchers,
         operations, predicates, callback kinds, **each derived from `ir.sls`**)" — and is
         corrected the same way**, or the two documents disagree with each other.
      4. **"dispatches draw *one to four* cases"** → **one to two**, and it is a **bound**, not
         a steering (F3 row 2). **And the bound is ADDED to §4.10's Bounds bullet here**, in
         Step 2 — F3 row 2 argues it "belongs in the same list", and measured, §4.10's list is
         "sixty-four machines per seed set, a node budget of eight, inputs of at most six bytes,
         eight inputs per machine, four seeded multi-split schedules" and does **not** contain
         it. Asserting it is already there would be a false supporting argument for a correct
         classification.
      5. **"each naming a span-data callback and, *in half the draws*, a completion callback"**
         → a **single machine-level coin**, named on every span or on none (Task 6 Step 2), with
         the reason written back: the per-span reading produces
         `unreferenced-callback-declaration`, and the shipped `counted-machine.sls` `complete?`
         flag is the precedent. **The "one or two span declarations" count and "Optional
         callbacks are bound in half the draws" stand unchanged** and are implemented as
         written (Task 6 Step 2) — said here so the correction is not read as licence to drop
         them.
      6. **The schedule list** (F19): `§22.5:1282`'s split-point pairs are **absent** and
         `:1279` is narrowed by dropping "intermediate", while all three shipped
         schedule-bearing lanes implement both and pairs are **50–62%** of every shipped
         schedule set (callback 15/30, span 21/37, counted-span 28/45) → **six** shapes, not
         five. And the sixth bullet's "finally random and printed" **overturns** three shipped
         comments arguing a literal is the most reproducible form; the departure is deliberate
         and is said so rather than left to look like an oversight.

      **Expected, as literals, and enumerated rather than sampled:** design §4.4 cites
      `§22.5:1278-1283` and names **six** shapes;
      `rg -c 'drawn uniformly|one to four cases|at run time|in half the draws, a completion'
      docs/plans/milestone-7-design.md` → **0**;
      `rg -c 'each derived from .ir.sls.' docs/plans/milestone-7-design.md` → **0**;
      `rg -n 'private error sink' docs/plans/milestone-7-design.md` returns the corrected
      wording only.
- [ ] **Step 2 (design §4.10 and §7).** Replace "the shipped lane runs in under a second" with
      the **two measured numbers** of Task 8 Step 4 (source and AOT), because §4.10 asserts
      something about "both lanes" and no measurement of the AOT lane existed anywhere in the
      tree. Note beside §4.10's totality-row bullet that the **callback-kind `memq` has no
      shipped extractor** and that this slice writes the third one (F18), and beside §7's CMake
      bullet that the registrations also need `BYTE_MACHINE_SOURCE_ROOT` (F20) — §7's bullet
      names only the manifest and the timeout.
      Note beside §4.10's placement bullet that **§7 puts the totality rows in
      `machine-gen.sls` and §4.10 puts them in the property program**, that this slice follows
      **§4.10**, and why: a row inside a library reads a file at run time and fails by a
      **raise** rather than a comparison, and the S2 operand argument needs the draw table
      declared on the **other** side of the comparison from `ir.sls`.
      **And add the dispatch case count to §4.10's Bounds bullet** — Step 1 item 4's other
      half. Measured, the bullet today reads "Sixty-four machines per seed set (forty today), a
      node budget of eight, inputs of at most six bytes, eight inputs per machine, four seeded
      multi-split schedules" and carries no case count; F3 row 2 classifies "1–2 cases" as a
      **bound, not a steering**, on the argument that it "belongs in the same list", and that
      argument is only true once it is **put** there.
      **Expected, as a literal:** §4.10's Bounds bullet names **six** numbers — machines, node
      budget, input length, inputs per machine, multi-split schedules, **and dispatch cases**.
- [ ] **Step 3 (decision 0033, four dated notes at the foot, items untouched above).**
      - **item 2**: "the shipped eight stay" and "each has the two halves the shipped lane has"
        cannot both hold — the shipped eight are **five agreed and three interpreter-only**,
        and `finished` and `field` have no twin, so the eight become **ten** (F10); and one of
        the eight — `"at least one generated machine declares a field"` — reads **the draw**
        (`(pair? fnames)`), which the same item forbids, so its **witness changes** and its
        label survives;
      - **item 5 row 1**: "a `stopped` from `parser-finish!`, **which no row permits**" —
        `§12.2:695` permits exactly that, for the sticky arm; the invariant is keyed on
        `(lifecycle-before, operation)` and the `§16.2:909` hole is the pair
        `(ready | finish-ready, finish!) → stopped` (F23);
      - **item 5 row 6**: the row needs a **third inapplicability condition** — no bound
        span-complete callback — because there is **no public observation of a span's start
        offset** and the end anchor is the only one available (F23); and the
        `finished next 5 consumed 0 offset 5` digest is a number whose command is nowhere and
        whose fixture this slice deletes, so it is **not repeated**;
      - **item 4**: the fixture, the saver and the path in the check's detail are **Slice ③'s**
        — 0033's own Consequences hand "the saver (item 4)" to ③ and design §8 puts it there,
        and the printer ③ owns is a hard dependency. **Slice ② ships the driver shaped so ③ can
        add the saver without re-shaping it** (the `on-first-disagreement` parameter, the
        at-most-once rule in the driver, `check-fail` as the only assertion whose detail the
        caller chooses) and writes **no fixture**. Without this note the next reader takes
        item 4 as ②'s obligation.
      Also note, against item 5's filing of `§22.5:1285` under "Across schedules", that the
      sentence reads "for the same schedule" and the driver puts it in **Layer 1**, with the
      design and the shipped tree; and that item 5 row 2's Source column drops `§11.1`, which
      design §4.4 carries and the plan keeps.
- [ ] **Step 4 (decision 0022, one dated note).** Item 7's open question — an error declaration
      in the source `errs` table but not in the encoding's reached-declaration table — was
      **avoided on purpose** by the shipped generator and is now **drawn on purpose** (Task 6
      Step 2). Record which slice made the change and why, so the next reader of 0022 finds the
      receiver rather than re-deriving the avoidance.
- [ ] **Step 5 (the stale citations, all of them, with their dispositions).**
      Corrected in place: `SchemeMutationSuite.cmake:10111`'s three `machine-gen.sls` line
      citations (Task 9 Step 3) — replaced by **construct names**, because this slice deletes
      the text they point into and a new line number would be stale within the same commit.
      **Annotated, not rewritten** (records): `milestone-4-design.md`'s `machine-gen.sls:119-139`,
      `:129`, `:9-49`, `:105-118`.
      **Recorded as out of scope with their reasons**: `§22.5:1286` cited in three shipped
      comments and one plan for a sentence at `:1287` (this slice rewrites none of those
      files); and `§12.7:772` cited in two `interpret.sls` comments for a sentence at `:773`
      (§4.9's gate forbids touching `interpret.sls`) — the latter recorded so nobody reads
      decision 0030's amendment "Slice ⓪ corrects it there" as "corrected everywhere", which
      is exactly the scope claim inheriting the scope of its measurement.
- [ ] **Step 6 (the five status surfaces, by name).** AGENTS.md enumerates five and this is the
      **fourth consecutive slice** in which one drifted:
      1. **the milestone's design document** — `milestone-7-design.md:4` still reads "Slice ⓪
         delivered 2026-09-07 (PR #89); **Slice ① next**" although Slice ① merged as PR #92 on
         2026-09-11 and Slice ①'s own plan Task 7 Step 2 instructed the correction, which the
         commit did not make. **A status line is an instruction, not a record**: it tells the
         next reader what to do next, and one naming a merged slice sends them to the wrong
         work;
      2. **the parent plan's Status line** (`:3`), which stops at Slice ⓪ while `:2493` of the
         same file carries the full 2026-09-10 Slice ① disposition;
      3. **the parent plan's dispositions section** — Slice ②'s appended, **never inserted**;
      4. **`CHANGELOG.md`**'s `[Unreleased]` preamble, plus an entry naming
         `(byte-machine test property-driver)` — a new public test-support library, on
         `error-projection`'s precedent;
      5. **`README.org`**'s status paragraph — the surface no other step names and the one
         whose drift is unbounded.
      **Expected, as a literal:** all five name Slice ② and none names a slice that is not the
      next one.
- [ ] **Step 7 (what is handed forward, written down rather than remembered).** Into the parent
      plan's disposition and into Slice ④'s reading list: the **seventeen** diagnostic codes a
      free draw supplies for free and the **thirteen** it never produces (F8) — the difference
      between Slice ④ writing thirty catalogue entries and writing thirteen; the rejection
      ledger's shape and the two aggregates that are not derivable from each other; and the
      three of §4.6's eight oracle rows (`:885` duplicates, `:887`/`:905` resolution, `:897`
      unreachable) that are satisfiable **only** because of the dangling-target and orphan
      draws — **built and measured in Slice ②, `0` in the property lane, and turned ON by
      Slice ④**, with Task 2 Step 9's chosen `p` and `q` and the counts they produced. This
      hand-forward is the *whole* of Slice ②'s obligation to those rows: §4.6 is Slice ④'s
      section, its drive is "§4.4's generator with its structural steering off", and no
      authority asks this lane's own ledger to contain either code.
- [ ] **Step 8 (design §7's Oracle, discharged item by item and recorded).** *Coverage is
      observed* — Task 7 Steps 5–6's **96** green, and the accepted count ≥ the floor. *Both lanes*
      — Task 7 Step 9's two lanes green **with identical counters**, compared by capturing both
      outputs and not by both being green. *Reproducibility* — Task 3 Step 9's two-process
      fingerprint equality. *Nothing agreed-wrong is claimed* — the header of Task 5 Step 5 /
      Task 7 Step 8. *No mechanism* — §4.9's gate, and this slice's stronger form
      (`git diff --stat main..HEAD -- src/` prints nothing at all).
- [ ] **Step 9.** Commit: `docs: Slice ② — the property suite's records, the corrected
      instructions, and the five status surfaces`.

**Exit:** design §4.4's **six** corrections (one of them a tightening) and the Appendix line
landed; §4.10's two measured numbers and its Bounds bullet's sixth entry landed; 0033's four notes
and 0022's one at their records' feet with the items corrected in place above them; all five
status surfaces naming Slice ②; the hand-forward written down; the Oracle discharged item by
item with its evidence.

---

## Task 13 — The whole-branch review, and the close

- [ ] **Step 1.** Run the review in a **detached worktree at the branch head** — never
      `isolation: worktree`, which checks out `main` as it stood at launch and would report on a
      tree without any of this slice's work, with plausible line numbers. Subagents told they
      may edit to test a hypothesis will edit whatever tree they are given, and a `ctest` run
      alongside such a workflow reports numbers that are not about your tree.
- [ ] **Step 2.** Put AGENTS.md's sentence in the reviewer's prompt **verbatim**: *check what
      this claims the code or the spec DOES against the code and the spec, not against the
      prose.* That sentence caught three false supporting reasons in Milestone 4's Gate 0 and
      the retirement error in Slice ⓪; the reviews that lacked it caught none. **This branch
      carries at least four claims of exactly that shape already** — `test/CMakeLists.txt`'s
      compile-order reason (F20), the suite header's SUBSUMED entry (F15), the two
      `"observes a pause"` uniqueness comments (F14), and `position-kind-tests.sps:439`'s
      "two declarations with distinct codes" — so the reviewer is told they exist and asked
      whether the branch added any more.
- [ ] **Step 3.** Ask the four questions this slice's shape invites, none of which any single
      task owns:
      1. **Is any steering a second verifier?** For each, does its target code still appear in
         the ledger's histogram at the end of a real run — measured from the run, not from
         Task 2's prototype.
      2. **Does any counter read the draw?** Walk all 46 rows and ask, of each, which trial
         value it read. Four forbidden shapes are named in the Global Constraints and two of
         them are shipped in the tree today.
      3. **What did decision 0033 decide that this tree does not contain?** Item by item, item
         4 included — this slice deliberately does not discharge it and the note must say so.
      4. **What in the rewritten generator does no pin name?** A clean sweep cannot answer this
         and reads as though it did.
- [ ] **Step 4.** Re-run every count the documents quote, from the tree rather than from a
      commit message. **Expected, as a literal:** every quoted number reproduced, or a
      correction made — a count restated in two places will disagree with itself.
- [ ] **Step 5.** Fold the findings, then re-run **Tasks 7, 9, 10, 11 and 12's** measurements.
      A fix wave moves counts; a sweep run once at the end is a sweep that did not see the
      fixes; and Step 4 edits documents whose citations Task 12 Step 5 had already resolved.
- [ ] **Step 6.** Re-open every cross-document `file:line` as the **last** step before the
      final commit, after the fix wave. **Expected, as a literal:** N citations re-opened,
      **0** mismatches. A citation into a file the same commit also edits is stale on arrival,
      and this branch edits five such files.
- [ ] **Step 7.** Open the PR. **PR #88's two-run Chez-cache verification is still
      unperformed** — Slices ⓪ and ① both merged without the `ci` label at the owner's word —
      so this is again the first PR that can discharge it, and its body says whether it did.
      Label it `ci` only when the branch is final; a later push does not re-run the labelled
      job.
- [ ] **Step 8.** The closing ritual **on the owner's go-ahead**: check mergeable and CI, then
      squash-merge, fast-forward local `main`, delete the branch locally and remotely, and
      reflect — durable facts to memory, project standards to `AGENTS.md`, anything the code
      should say about itself into a comment at the site.

---

## Verification

Run at the head of the source commit and **again after the review's fix wave**.

1. `cmake --preset dev && cmake --build --preset dev && ctest --preset release
   --output-on-failure --no-tests=error` — `100% tests passed, 0 tests failed out of 114`,
   both Chez modes. (One command, not two: the two modes are two registered lanes inside the
   one selection — 59 `source`-labelled and 46 `aot`-labelled of 114 — and no preset, cache
   variable or flag selects a mode.)
2. `ctest --preset release -E scheme-mutation` — `0 tests failed out of 113`.
3. The mutation lane — **exit 0 first**, `58` passes, and the mutation count Task 10 Step 9
   recorded (predicted `536 − 2 + A`; **write the recorded number here, because "as measured"
   cannot fail**). Filtered for `CMake Error`, `wrong reason`, `UNCAUGHT` and
   `recorded limitation is stale`, each expected **0 occurrences**. The exit status leads
   because it is the only summary a run that then fails cannot print — the suite prints
   "suite complete" on the way to failing.
4. The two property lanes — `ctest --preset release -R 'property\.differential'` →
   `100% tests passed, 0 tests failed out of 2`, with the per-test seconds recorded and the
   **counter values identical between the two lanes**, compared by capturing both outputs.
5. The lane's own accounting, read from its output: the accepted count under the committed
   seed **≥ the floor literal**; `accepted + rejected = 64`; `fed-unverified = 0`;
   `interpreted-count = generated-count = accepted-count`; all **96** counter checks green in
   **both** halves; the span-fragment counter **≥ 1 in both halves under the committed seed**
   (the pass criterion), with its value under seeds `1`, `7` and `99` **recorded** beside it as
   a diagnostic rather than asserted (0033 item 2 and design §7's Oracle both gate on the
   committed seed).
6. The totality rows — `node?` 13, `matcher?` 4, operations 7, predicates 7, callback kinds 4,
   callback outcomes 4, span events 5, schedule shapes 6, each with its "found it" guard green.
7. `git diff --stat main..HEAD -- src/` — **no output**. This slice's own gate, stronger than
   §4.9's, because Slice ② touches no `src/` file at all.
8. `git diff 5ac363a..HEAD --stat -- src/ ':!src/byte-machine/verify.sls'` — **no output**
   (design §4.9's gate across the milestone).
9. `git diff --stat main..HEAD -- test/fixtures` — **no output**.
10. The pin matrix — every diagonal cell **1**, every off-diagonal cell **0**, printed. The
    cross-SPEC direction is **closed by construction, not measured**: Task 11 Step 3's two
    literals (`SchemeMutationSuite.cmake:8567` is the only verify command in the suite that
    runs this program; `MutationRunner.cmake:164-170` shows the runner ignores `SPEC` whenever
    `BYTE_MACHINE_MUTATION_VERIFY_COMMAND` is set, which all 48 passes set).
11. The diagnostic census unmoved — thirty codes over fifty-six sites, `(unreachable-node 1)`,
    the per-constructor table `14 / 30 / 11 / 1`. This slice changes no verifier code and the
    census is the check that says so from the other side.
12. Every cross-document `file:line` re-opened — **0** mismatches. This item runs **last**,
    after items 1–11 and after any fix wave, because the fixes move the lines.

## Exit

- Validity is `verify-machine`'s verdict: every draw is verified, only accepted machines reach
  an executor, rejected draws are counted by code and kept, and the structural equality
  (`interpreted-count = generated-count = accepted-count`, `fed-unverified = 0`) is asserted by
  **comparison** and not by a raise.
- The steering set is decided, classified member by member against 0033 item 1, and priced in
  **both** directions; `cbdefault` is declined as validity steering with
  `make-callback-declaration`'s own comment quoted, its replacement drawn from the slot's
  vocabulary, and the measured consequence of the bare refusal (46.1%, ~29.5 of 64) recorded
  rather than glossed.
- The floor literal is **measured through this lane and this generator under the committed
  seed**, is no lower than 32 of 64, carries the command and the seed beside it, and carries
  the sentence saying what it does not measure on its own.
- Forty-six family members over seven families, plus `integer-accumulate`'s second arm and the
  `declares a field` pair — **48 keys, 96 checks** — read **observed** values in **both** halves and are
  ≥ 1 under the committed seed — the span-fragment counter measured first, and its values
  under three further seeds recorded as a diagnostic rather than gated on; the per-operation
  and per-predicate counters second — with the shipped eight becoming ten and the one that read
  the draw given an observed witness.
- The three comparison layers are in one library the lane reads now and Slice ③'s fixture and
  minimizer read next: Layer 1 over all nine of `§22.4:1264-1272` plus `parser-state-name` and
  `parser-active-span`, Layer 2 with **both** its negative sentinels, Layer 3's six rows keyed
  on `(lifecycle-before, operation)` and carrying the span row's **third** inapplicability
  condition.
- §4.4's span pairing is corrected — the counter it exists for was unsatisfiable and is now
  measured — and its "private error sink" is re-worded onto the node that has one.
- Pass 39's six mutations are decided **by LABEL**: four re-anchored with their `REPLACE`s,
  two retired with tombstones carrying a staged-deletion measurement, a 1/0 replacement count
  and a non-empty separating set — or refused and re-anchored, with the refusal measured.
- `A` new pins are measured, every pin matches **exactly once** in its own mutant's output and
  zero elsewhere in its own pass — the cross-SPEC direction being closed by construction, with
  its two literals recorded rather than swept — the rejects-everything mutant produces no member
  label because the harness cases are partitioned, and `EXPECTED_MUTATIONS` closes at
  `536 − 2 + A`.
- The inherited `"observes a pause"` defect is fixed and its two false comments corrected; the
  suite header's SUBSUMED entry for the p39 pair is corrected, dated, with the retraction kept;
  the banner and the stale cross-file citations are current.
- Both registrations carry `property-driver.sls` at the same index and
  `BYTE_MACHINE_SOURCE_ROOT`; the source lane's timeout is justified by a measurement and the
  **AOT lane's is measured for the first time**.
- This slice wrote **no fixture and no saver**, and decision 0033 item 4 says so at its foot.
- No file under `src/` changed at all, and the design, the parent plan, `CHANGELOG.md` and
  `README.org` all say what the tree says.
