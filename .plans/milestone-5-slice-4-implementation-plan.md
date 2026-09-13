# Milestone 5 — Slice ④ (retention, the EOF and reset legs, and the close-out) Implementation Plan

Authority: `milestone-5-design.md` §9, then decision `0024` (the callback-error
vocabulary, whose last bullet is this slice's other end), then `§25:1589`,
`:1591` and `§27:1694` in the parent plan.

This is the **last slice of Milestone 5**, so it carries two jobs that no earlier
slice had: it writes the milestone's close note, and it is the named receiver of
every obligation the milestone deferred to "the close-out". §4 below lists them;
they are not optional, and the paragraphs that name them say so in as many words.

Everything below was measured at `2fce5be` (`main`, release 106/106, 54 passes /
466 mutations). Every `§N:LINE` in this plan was resolved by opening the plan at
that line — the discipline `AGENTS.md` gained after Slice ③ shipped fifty-five
citations that pointed one line too high.

---

## 1. Six findings that change the work

### F1 — Slice ③ already discharged most of ④'s two legs, and the design does not know it

Design §8 allocates `§25:1589`'s six legs explicitly: *"this slice discharges
boundaries, pause, completion and error, and Slice ④ discharges EOF and reset
(§9). Neither slice discharges `:1589` whole, and saying so is how the milestone
avoids each believing the other covered a leg."*

That sentence was written before ③ ran. Measured in the tree today, ③ shipped
both legs it had disclaimed:

- `differential-span-tests.sps`, `harness-group "a span on the EOF chain
  (§12.4:729, §14:834)"` — two cases;
- `harness-group "reset clears span state (§12.5:739)"` — one case, which also
  asserts the post-reset **fragment shape** ("with the whole payload in one
  fragment"), not merely that `parser-active-span` answers `#f`;
- and `record-span` calls `parser-finish!` on **every one of the 37 schedules**,
  so a feed-then-EOF sequence is driven thirty-seven times.

The design's own protection against double-counting has failed in the *other*
direction: not both slices believing the other covered a leg, but one slice
covering a leg it disclaimed, leaving ④'s scope overstated on four surfaces.

**What is genuinely uncovered**, measured case by case rather than assumed:

1. **A span open when `parser-finish!` is called**, closed by a node on the EOF
   chain. Every existing EOF case opens *and* closes inside finish. This is the
   only shape in which a span's fragments come from `parser-feed!` and its
   completion from `parser-finish!`, and it is legal: `§14:843` forbids
   *reaching* a successful stop/finish with a span active, not entering finish
   with one open.
2. **Reset while parked between the span-end substeps** (`completion-pending`) —
   a different parked state from mid-span, and the one `§14:841` says retains an
   internal continuation.
3. **Reset of a poisoned parser with a span open.** `§12.2:698` makes reset the
   one operation a poisoned parser may run, and `parser-reset!` calls
   `byte-machine-span-close/v1` unconditionally after its `busy` guard.

Task 1 states the recogniser, runs it, and closes only the measured remainder.
It does not re-cover what ③ covered, and it does not skip the legs on the
strength of ③'s group titles.

### F2 — the retention oracle must be reachability-based, not slot-based

Design §9 layer 3 says an oracle *"that excludes only the user-context slot will
report a false violation"*, which reads as an instruction to enumerate slots and
exempt three of them. Enumerating is the **weaker** oracle, and the parser's own
growth is the argument: it was ten slots at Gate 0 and is sixteen now, three of
them added by ③ and ①b after §9's first measurement.

A slot walk also has a gap §9 does not name. `§13:799` exempts exactly three
carriers — callback closures, user context, callback error detail — and slot 2,
the executor closure, is on **neither** list: it cannot retain a fed bytevector
(it is built by `compile`/`load` and closes over the machine, never over a feed),
but it is not exempt either, so a slot-walking oracle must justify skipping it
and a reachability oracle need never mention it.

The weak-reference probe is total: it covers retention paths nobody enumerated —
a closure the runtime allocates mid-feed, a cons inside a result, a slot a later
milestone adds. **The oracle drops every application-side reference and collects;
the three exempt carriers are handled by the fixture not putting the bytevector
in them, and by Task 3's case demonstrating what happens when one does.**

### F3 — decision `0024`'s pointer into design §9 is stale by two Appendix rewrites

`0024` closes with *"What this hands to Slice ④"* and cites
`milestone-5-design.md:876-881` for the oracle's third layer, calling itself
"the deferral's second end". Measured: §9's exemption boundary is now at
**`:980-985`**, and `:876-881` lands in §8's work list — `make-span-start-node`
and the span-state paragraph. The deferral's second end no longer points at the
deferral.

This is a **record**, so the correction is a dated note plus a header-block
bullet in `.decisions/README.md` (`.decisions/README.md` §1) — never a
rewrite. It is also the exact failure the memory `citations-into-files-you-edit`
names: a `file:line` into a file the citing change does not control is stale on
arrival, and no link checker sees it.

### F4 — two obligations name "Milestone 5's close-out" as their receiver, and this is it

- **`§9.3:392-393`'s `parser-result` re-baselining** (plan `:2119-2124`). *"The
  next slice that touches `parser-result`'s shape owns it; failing that,
  **Milestone 5's close-out must either schedule it or dispose it explicitly**,
  and this paragraph is what the close-out is to be checked against."* Slice ③
  did not touch the shape, so it falls here.
- **`§12.7:770`'s zero-width-machine-action half** (plan `:2195-2204`). *"Owed by
  whoever next touches the field/accumulate emitted arms, and failing that by
  Milestone 5's close-out … Deferring it is a choice, and this paragraph is what
  the close-out is to be checked against."*

Each must be **scheduled or disposed in writing**. "Milestone 6 will get to it"
is a disposition only if Milestone 6's artifact records it.

### F5 — a deferral addressed to a ROLE is recorded only where that role will look

The lesson this slice was asked to fold in, and F4's second item is its live
instance. `§12.7:770`'s zero-width half is owed by *"whoever next touches the
field/accumulate emitted arms"* — and that obligation lives in the parent plan,
a document that person has no reason to open. They will open
`compile.sls`'s emitted field-action/field-branch arm and `interpret.sls`'s
`field-step`.

An obligation addressed to a **role** ("whoever next touches X") is recorded when
it is written into the artifact that role will actually reach, which for a
role-receiver is the **source site**. An obligation addressed to a **step**
("Milestone 6's counted consume") is recorded in that step's plan. The parent
plan is where the disposition is *adjudicated*; it is not where the receiver
looks. Task 6 writes both, and this is the general rule the slice adds to
`AGENTS.md`.

### F6 — two mutation passes are both numbered 49, and this slice adds a pass

Measured: `SchemeMutationSuite.cmake` carries `# --- Pass 49:` twice — the
Milestone 3 Slice ③ sequence-determinism golden and the Milestone 5 Slice ①b
`parser-field-ref` pass. A reader who cites "Pass 49" reaches one of two
different passes, and the memory `mutation-spec-is-a-label` is about exactly this
class of confusion: the label is navigation, and a wrong one reads as a real
address.

This slice adds a pass and must pick its number. Picking the next free integer
without resolving the collision bakes it in.

### F7 — "the reference fixture" survives on two surfaces, and means something else

Two surfaces still describe this slice as shipping *"the reference fixture and
the retention oracle"*: the parent plan `:2123` and the ledger. The **reference
fixture** is `§21`'s HTTP fixture, a **Milestone 8** deliverable governed by
`§21.5:1181-1187`. What this slice ships is `§27:1694`'s *callback/span lifetime
**reference***, a document. The parent plan's `Status:` line and the milestone
design were both corrected during Slice ③'s closing sweep; these two were missed.

---

## 2. What this slice ships

1. The measured remainder of `§25:1589`'s EOF and reset legs (F1).
2. `§25:1591`'s retention oracle, in design §9's three layers, reachability-based
   (F2), with its negative control designed alongside it rather than added once
   it goes green.
3. `§27:1694`'s callback/span lifetime reference — the **first `§27` deliverable
   in the tree**; `.reference/` holds only a `.gitkeep` today, so this
   establishes the shape the other ten inherit.
4. The close-out: both F4 obligations disposed, the milestone close note, and the
   four status surfaces.

---

## Global Constraints

- **Authority order.** Design §9, then decision `0024`'s closing bullet, then the
  parent plan. Where an authority is wrong, **stop and say so** — this milestone
  has corrected eleven such defects, and §1 above adds six more.
- **The retention lane imports `byte-machine` source, so it MUST carry mutation
  pins.** This is the difference from ③'s liveness-probe lane, whose exemption
  rests entirely on importing none. Do not copy that lane's "no pin" comment.
- **The mutation suite declares no `SITES`**, so every `FIND` is pinned at
  exactly one occurrence in *both* directions, and a broken `FIND` fails at CMake
  **configure** time.
- **A new pass goes after the previous pass's `_run`**, with its own
  `byte_machine_mutation_reset()` and `BYTE_MACHINE_MUTATION_VERIFY_COMMAND`. A
  `reset()` placed first discards the preceding pass.
- **A mutant can HANG the suite** — the runner has no per-mutant timeout. Any
  fixture that re-enters the runtime must bound itself.
- **`collect` is not free.** ③'s probe lane runs a full collection per arm and
  fits in its 120s budget with room; a retention oracle that collects once per
  schedule over 37 schedules does not automatically. Measure before enumerating.
- **Both lanes, always.** A retention defect that exists only under AOT
  compilation is exactly the kind ③ brought the probe forward to rule out.

---

## Task 1 — Measure `§25:1589`'s EOF and reset legs, then close the remainder

**Measure first, in writing.** State the recogniser before running it: for each
of the six legs, which `harness-group` in which file covers it, and which case.
Record the four ③ covers, the two it disclaimed but covered anyway, and the three
shapes in F1 that nothing covers. A leg is discharged by a case that would fail
if the behaviour changed — not by a group title that names it.

**Then close the three measured gaps**, in `differential-span-tests.sps` beside
③'s own groups rather than in a new file: they are the same fixtures, and a
second span lane would be a second thing to keep in step with `§22.5`.

1. A span open at `parser-finish!`, closed on the EOF chain: the fragments come
   from the boundary flush, the completion from finish, and the lanes agree.
2. Reset while parked in `completion-pending`, then re-parse — the assertion is
   the *fragment shape* after reset, as ③'s reset case does, because
   `parser-active-span` cannot see a stale mark.
3. Reset of a poisoned parser with a span open, which `§12.2:698` permits and
   `parser-reset!` handles after its `busy` guard.

**Deliverable.** The measurement table in the slice's commit message and, if any
leg turns out uncovered in a way that changes design §9's allocation, a dated
correction to design §8's "four of the six legs" sentence — it is an
*instruction*, so it is corrected in place.

## Task 2 — The retention oracle, layers 1 and 2

Reachability-based (F2), building on `test/common/liveness-probe-tests.sps`,
whose three findings design §9 says this slice inherits:

- the allocation happens inside a procedure that **returns only the weak pair**;
- the negative control's strong reference lives at **module level and is cleared
  by assignment**, never captured by a `harness-case` thunk;
- both directions are asserted **in one case**, so a probe answering a constant
  fails one arm.

**Layer 1.** Feed a freshly allocated bytevector through a span machine that
delivers fragments, drop the test's own reference, collect, assert `bwp`.

**Layer 2, the negative control, designed here and not later.** A fixture whose
callback deliberately retains its slice in a place the guarantee **does** cover,
so the oracle must *fail* on it. Without this, layer 1 passes against a runtime
that retained everything, which is the vacuity design §9 names as the whole
reason this slice exists.

Run it in **both lanes** and over a small, measured set of schedules — not all
37 unless the timing budget says it fits.

## Task 3 — Layer 3, the exemption boundary, as an executable case

`§13:799` exempts three carriers, and decision `0024` item 4 gives the
explicit-failure path a populated `parser-error-detail`, so the parser's stored
error transitively holds application data that `§13:799` **permits** to retain
the bytevector.

Ship the case that demonstrates it: a callback that fails with a detail holding
its own slice, after which the bytevector is **still reachable and that is
correct**. It is the third arm of the discrimination — retained-and-forbidden,
dropped-and-required, retained-and-permitted — and it is what stops a later
reader from "fixing" the oracle into reporting a violation.

Note at the site that `§12.7:777` does not compare detail across lanes, so this
case asserts reachability per lane rather than agreement between them.

## Task 4 — `§27:1694`, the callback/span lifetime reference

The first `§27` deliverable. Place it at `.reference/callback-span-lifetime.md`.

It documents what an application may and may not hold: the input range is valid
only for the dynamic extent of the span-data callback (`§13:799`); the three
exempt carriers and what exempt means; that machine-field access from a callback
is read-only (`§13:801`); that fragment boundaries are not semantic token
boundaries (`§14:836`); and that a pause after the data fragment retains only an
internal `completion-pending` continuation, never the bytevector (`§14:841`).

It states `§13:826`'s enabling condition explicitly — the verifier's restriction
on pauses while a span is active is *"what makes the no-retention contract
possible"*, shipped as `span-active-at-pause` and `span-active-at-exit` in
`verify.sls` — because design §9 warns that `:1590` and `:1591` are not
independent and a reader of the reference will assume they are.

**Written against the code, not from this plan.** The status-surface standard
applies with full force to a document whose entire purpose is to be believed.

## Task 5 — Mutation pins for the retention lane

The lane imports project source, so it is pinnable and must be pinned. At
minimum:

- a mutation that makes the runtime **retain** across a `parser-feed!` return in
  a non-exempt place, caught by layer 1;
- a mutation that makes the oracle **blind** — the negative control's own
  assertion — caught by the lane's two-directional shape.

Resolve F6's duplicate `Pass 49` before choosing this slice's pass number, and
say in the header which pass it follows. Re-measure `EXPECTED_PASSES` /
`EXPECTED_MUTATIONS` from the harness; do not compute them.

## Task 6 — The two close-out obligations, written where their receivers look

**`§12.7:770`'s zero-width half.** Disposed or scheduled in the parent plan
*and* written at the two source sites its role-receiver will open — the emitted
field-action/field-branch arm in `compile.sls`, and `field-step` in
`interpret.sls` — each naming the reproduction and what it costs (a widened
return or a new executor message, plus a `position-kind-tests.sps` row per
producer and a re-measure of every pin anchored on a `byte` verdict from a failed
zero-width action).

**`§9.3:392-393`'s `parser-result` re-baselining.** Scheduled against a named
milestone or disposed with a reason, checked against plan `:2119-2124`.

**And the general rule into `AGENTS.md`** (F5): an obligation addressed to a role
is recorded at the site that role will reach; one addressed to a step is recorded
in that step's plan; the parent plan adjudicates but is not where either receiver
looks.

## Task 7 — Record corrections

- Decision `0024`: a **dated note** correcting `milestone-5-design.md:876-881` to
  the current §9 location, plus its header-block bullet in
  `.decisions/README.md`. The record above the note is not touched (F3).
- The two surviving "reference fixture" conflations (F7): parent plan `:2123` and
  the ledger. Both are prose about *this slice's scope*, so both are corrected —
  the plan paragraph is a dated disposition and takes a note, the ledger is
  untracked working state and is simply rewritten.

## Task 8 — The milestone close note and the four status surfaces

**As an appended disposition, not a `§25` subsection.** Milestone 4 set this
precedent for a stated reason: an insertion at `§25` renumbers every
`§section:line` citation below it, and this repository has just spent a slice
correcting fifty-five citations that moved by one.

Disposition **every** Milestone 5 exit criterion **against the tree**, not
against the slice plans that claimed to discharge it — `§25:1581`-`:1584`,
`:1589`, `:1590`, `:1591`, and the two obligations from Task 6. Milestone 1 and
Milestone 4 each closed with no close note at all; both gaps were found later by
someone else.

Then the four surfaces — `README.org`, the parent plan's `Status:` line,
`CHANGELOG.md`'s `[Unreleased]`, and this milestone design's `Status:` — plus the
ledger. **Audit them with something that measures.** Re-count every total from
the tree. Open the plan at every `§N:LINE`. Narrow every "every", "the only" and
"never". Slice ③'s sweep produced fourteen false claims in prose minutes old.

---

## Verification

`release` green, the mutation suite at its new totals, and seven things checkable
rather than asserted:

1. **The oracle fails on the negative control** — demonstrated by running it, not
   argued. Layer 1 without layer 2 is the vacuous test this slice exists to
   avoid.
2. **The oracle passes on the exemption case** and says why, so a later reader
   cannot "fix" it into a false violation.
3. **Both lanes**, source and AOT, for every retention assertion.
4. **Each of `§25:1589`'s six legs names the case that covers it**, and each named
   case fails if the behaviour changes.
5. **`span-active-at-pause` and `span-active-at-exit` are asserted as the
   enabling condition of `:1591`**, not merely as `:1590` topology rejections —
   `§13:826` makes them the reason the contract is possible.
6. **No `# --- Pass N` integer appears twice** in `SchemeMutationSuite.cmake`.
7. **Every `§N:LINE` written by this slice resolves to the sentence it cites**,
   checked by opening the plan at that line — in the reference document above
   all, whose readers cannot check it themselves.

---

## Exit

Milestone 5 closes. The named receivers for everything it did not do are written
where those receivers will look, and the close note is checkable against the tree
rather than against this plan.
