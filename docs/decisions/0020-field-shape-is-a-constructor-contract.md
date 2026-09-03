# 0020: Field shape is a constructor contract; operands and cross-references are the verifier's

Date: 2026-08-31
Status: accepted
Milestone: 4, Gate 0 (milestone-4-design.md §4.3)

> **Amendments** — later notes at the foot of this file reach back into the text
> above them. Nothing above a note is rewritten.
>
> - **2026-09-02 (Milestone 4, Slice ①b)** — **amends item 6**: `machine-tag` is
>   NOT unforgeable, `pass-schema`'s IR-version check is NOT unreachable, and the
>   `EXPECT_SURVIVES` this item instructs Slice ①b to declare is **not declared**.
>   Both premises were measured false and the check is pinned in both directions.
>   See the foot of this file.

## Context

Measured against the tree at `a942327`, the commit Milestone 3 closed on. The
Milestone 4 design (`0a267de`) adds no code, so every line cited below is the
shipped one.

Milestone 4 adds one declaration constructor and three node constructors —
`make-uint-field` (§9.1:283), `make-field-action-node` (§9.1:301),
`make-integer-accumulate-node` (§9.1:302-304) and `make-field-branch-node`
(§9.1:305-306) — and with them the first construction-time values the parent
plan gives closed domains: widths (§10.2:489), initial values (§10.2:490),
seven operations (§9.1:326-334), seven predicates (§9.1:336-346), and `base`.
Which mechanism rejects each is a real choice, because the two are observably
different. `byte-machine-contract-violation` **`raise`s**
(`conditions.sls:19-20`), so a constructor rejection is non-continuable, stops
at the offending call, and builds nothing; a diagnostic is a value
`verify-machine` accumulates into a list, and no compilation or emission
proceeds while one exists (§16.1:878).

**Decision 0017's reasoning does not transfer, and the difference is one line
of §16.2.** 0017's Context turns on an absence: "§16.2's list of required
checks — an itemized enumeration with no open-ended qualifier — has **no**
invalid-matcher entry at all" (0017:16-17), so a matcher-validity *diagnostic*
would have been an addition to that list. §16.2:889 is the opposite case: it
names the field items outright — "invalid field widths, initial values,
constants, masks, and operations". Closing them at the constructor therefore
*removes* an entry §16.2 lists, where 0017 merely declined to add one. One item
is the exception that proves the reading: **predicates** appear in no §16.2
bullet at all, so for them 0017's argument applies unchanged — and lands in the
same place this record puts the other four.

**The precedent that does transfer is `make-edge`.** It `memq`-checks `mode`
against `(advance reexecute)` at construction (`ir.sls:200-204`, the check at
`:202-203`) even though §16.2:896 lists "invalid transition advancement modes"
among the verifier's required checks — and, measured, `verify.sls` carries no
arm for it: its only `edge-mode` reads are inside `pass-zero-progress`
(`verify.sls:266`, `:268`, `:320`), where they classify progress rather than
validate a mode, and none of its fourteen diagnostic codes names one. §16.2:896
is discharged wholly at the constructor today. Two other shipped constructors
supply the shapes M4 reuses: `make-byte-dispatch-node`'s `(or (symbol?
eof-target) (eq? eof-target #f))` (`ir.sls:230-231`) is the target-or-`#f`
slot, and 0017 point 1's range checks are local shape.

A reader who finds §16.2:889 and `make-edge` and no record will
reverse-engineer a rule from them, and the two point opposite ways
(`docs/decisions/README.md:8-10`).

This is **one** record and not two. The `error`-slot rule below is the single
constructor check whose soundness is *supplied by the verifier* — `store` and
`set-mask` cannot fail only because pass 6a range-checks their operand against
the referenced field's width — so its enforcement is the constructor/verifier
split, and splitting the record would put the two halves of one argument in two
files.

## Decision

1. **The constructor checks closed-set membership and the local shape of the one
   value being built, and nothing else.** `width` in `{8, 16, 32, 64}`;
   `initial` an exact integer in `[0, 2^width - 1]`; `operation` in the closed
   seven of §9.1:326-334; `predicate` in the closed seven of §9.1:336-346;
   `base` in `{10, 16}`; `arguments` a proper list; `name`, `field`, `next`,
   `true-target`, `false-target`, `digit-target` and `overflow-error` symbols;
   `eof-target` a symbol or `#f` (§9.1:318); `error` a symbol or `#f`, item 5
   below fixing which one a given `operation` requires; `nondigit-edge` an
   `edge?`. Each is a `byte-machine-contract-violation`, on the `make-edge`
   precedent. `initial` is in this list and the field-action `constant` is not,
   for one reason worth stating because the predicate is identical:
   `make-uint-field` receives the width in its own argument list (§9.1:283), so
   the bound is local; a field-action node names its field by symbol, so the
   bound is somewhere else.

2. **`arguments` is checked as a proper list and no further; the schema is not
   read at construction.** This single line fixes the whole boundary for the
   `arguments` slot. Everything that requires the §9.1:326-346 schema —
   which position holds the field, how many positions there are, what each one
   means — is the verifier's, because §9.1:348 assigns exact arity to it and
   nothing can be read out of `arguments` before arity is known. The
   consequence that will look wrong to a reader of 0017: **`low <= high` for
   the `range` predicate is the verifier's**, though 0017 point 1 rejects `low >
   high` in `make-byte-range-matcher`. There, `low` and `high` are named
   parameters; here they are the second and third elements of a list whose
   length the constructor is not entitled to assume.

3. **The verifier's half is a new pass — pass 6a, §16.3:924's "Field and
   callback type checking" — and it is everything relational:** exact arity
   against the operation or predicate, the `field` argument naming a declared
   field, `constant` and `mask` within the *referenced* field's declared width,
   `low <= high` for `range`, duplicate field names, and portable field names
   (§10.1:480). "6a" is this design's label; the source name follows the
   unnumbered-pass convention `verify.sls:190-200` records. **The number is a
   false friend:** the shipped file numbers passes by implementation order, not
   by §16.3's own item numbers, and that numbering skips §16.3 items 6 and 7
   (this pass, and span-state dataflow) entirely, so `verify.sls`'s own PASS 6
   (`verify.sls:340`) is EOF shape, §16.3 item 8, not this pass — a reader who
   greps `PASS 6` lands there, not here.

4. **§16.2:889's five items split three and two.** Widths, initial values and
   **operations** are discharged at construction — a raised contract violation,
   never a diagnostic, carrying no diagnostic code at all. **Constants** and
   **masks** stay diagnostics, in pass 6a, under `invalid-field-operand`. That
   is the exact split, and it is not a departure from §9.1:322, whose sentence
   states its own criterion: "Constructors validate only local shape and return
   immutable-by-API descriptors (from Milestone 3 that validation includes
   rejecting an empty byte set, a range with `low > high`, and an empty sequence
   — decision 0017). Cross-reference, graph, and semantic checks belong to
   `verify-machine` so callers can accumulate structured diagnostics." That
   parenthetical names the very check item 2 reverses for the `range` predicate
   — `low > high`, moved here from `make-byte-range-matcher`'s named parameters
   to a list position the constructor may not read. Accumulation is what
   cross-reference checks are *for*, and every item on the constructor side is
   evaluable from the one value being built while every item on the verifier
   side needs a second object — the field declaration — to evaluate at all. What
   callers lose is the ability to collect a width or an operation error beside
   other diagnostics; they get a raise at the offending constructor instead.
   That is 0017's Consequences trade taken again, for consistency, and not
   re-litigated per constructor.

   §9.1:348 is a third pointer sitting under the very tables this record cites
   four times, and it needs the same treatment: "The verifier enforces exact
   arity, declared-field references, operand range, and `low <= high`; it
   rejects arbitrary operation names or extra arguments." Arity and extra
   arguments are pass 6a's, per item 2; declared-field references and operand
   range are pass 6a's, per item 3; **"arbitrary operation names" is the one
   clause pass 6a does not carry**, and it is discharged instead by item 1's
   closed-set check on `operation` — the same split this item already makes for
   §16.2:889's "operations" bullet, reasoned identically. §9.1:322's own
   sentence assigns cross-reference, graph, and **semantic** checks to
   `verify-machine`, three categories where the paragraph above engages only the
   first: membership in a plan-fixed closed set of seven symbols (§9.1:326-334)
   is local shape under any of the three, the same reasoning already given for
   `operation`'s sibling `predicate`, and for `width` and `base`.

5. **The `error` slot of `make-field-action-node` names a target node, and is
   `#f` exactly when the operation cannot fail.** Not "may be" — exactly. The
   partition is a property of the operation symbol alone, so it is a second
   closed-set lookup on a value item 1 already closes, and it stays inside "the
   local shape of the one value being built". A sharper, per-call partition is
   conceivable — `add (field 0)` cannot fail regardless of the field's current
   value — but item 2 already forbids reading `arguments` at construction, so an
   instance-level rule has no argument value available to inspect and is
   unimplementable here; the operation symbol is the only thing the constructor
   may partition on.

   Reasoning over all seven operations against their §9.1:326-334 schemas, a
   field of width `w`, its maximum `M = 2^w - 1`, and the invariant that a
   stored value is always in `[0, M]` — closed, not merely asserted: the base
   case is item 1's `initial` check, already bounding the field to that range at
   construction, and the inductive step is exactly the four operations below
   shown to preserve it, the three checked operations' error edge refusing any
   commit that would not, and §15's checked multiply-add doing the same for
   integer accumulate. The set of writers is itself closed: those are the only
   constructs in §10.6's node repertoire that write a field, and §13:801 bars
   the one other candidate — "Machine-field access from a callback is
   read-only". Nothing else can move a field out of `[0, M]`:
   - `store (field constant)` — writes `constant`, which pass 6a has already
     bounded by `M`. **Cannot fail.**
   - `clear (field)` — writes `0`, in range at every width. **Cannot fail.**
   - `set-mask (field mask)` — `v | mask` with both operands in `[0, M]`; an
     OR of two `w`-bit values sets no bit above `w-1`, so the result is in
     `[0, M]`. **Cannot fail.**
   - `clear-mask (field mask)` — clears bits, so the result is `<= v <= M` and
     `>= 0`. **Cannot fail**, and unlike `set-mask` it does not even need the
     mask bound.
   - `increment (field)` — `v + 1` exceeds `M` at `v = M`. **Can fail.**
   - `decrement (field)` — `v - 1` is below `0` at `v = 0`. **Can fail.**
   - `add (field constant)` — `v + constant` exceeds `M` for in-range operands.
     **Can fail.**
   Four safe, three failing, which is exactly §10.6:560's "Underflow, overflow,
   or an out-of-range result takes an explicit error edge" once the third
   disjunct is discharged by pass 6a. **`#f` is required and not merely
   permitted** because a spurious target is not caught anywhere downstream:
   `pass-reachability` (`verify.sls:252-258`) walks `all-out-targets`
   (`verify.sls:88-91`), a purely syntactic graph walk with no notion of which
   operations can fail, and `milestone-4-design.md` §7's census row 3 (the
   `node-out-targets` row, `:1396` at the time of writing — not the
   Appendix's census row of the same number) — feeds a
   field-action node's `error` into `node-out-targets` whenever it is a symbol —
   so an `error` target on a safe operation is *reached* by that walk exactly
   like a real one and trips no `'unreachable-node` diagnostic, or any other
   check.
   Nothing downstream distinguishes a live error target from a dead one; the
   constructor is the only place able to catch a spurious target at all, which
   is why `#f` is required and not merely permitted. That a spurious target is
   worth catching is the premise the old §16.4:947 argument supplied and this
   one must state outright: it is a node that ships, is walked by every pass, is
   counted by the census, and is entered by no execution — the dead weight
   §16.4:947 exists to keep out, arriving by a route that section cannot see.
   The rule completes a
   three-way pattern across the three new constructors, and nothing else is left
   open in it: integer accumulate's `overflow-error` is mandatory, because
   §15:864-868's multiply-add can always fail; field action's `error` is
   conditional, by this rule; field branch has no error slot at all
   (§9.1:305-306), because a predicate over an in-range field and a bounded
   operand is total and §10.6:582 already requires it: "Every possible result
   must have an explicit target."

6. **No unreachable duplicate arm is admissible anywhere in Milestone 4, and
   the `base` arm of milestone-4-design.md §8 task 3 is dropped.** Where the
   constructor closes a set, the pass records the assignment in place — the way
   `pass-overlap` records its permanent non-extension (`verify.sls:178-184`) —
   and carries no arm and no code. The reconciling rule is not "walk cost" and
   not "new pass versus new clause": **a duplicate guard is admissible exactly
   when a caller can still reach it through the public API.** The tree states
   that criterion itself, at the very guards that §8 task 3 cites as its
   precedent: `normal-ir.sls:99-102` keeps the trie's `assertion-violation`s
   that `pass-sequence-ambiguity` has made redundant "because normalize-machine
   is a public entry point that does not itself verify: a caller who skips
   verification must fail loudly here". Those guards are reachable, and they
   raise rather than diagnose. A pass-6a arm for `base` is neither:
   `verify-machine` is handed a `machine`, a machine holding a `base` outside
   `{10, 16}` cannot be constructed, and the design's §4.6 gives `base` no
   diagnostic code to report. So it would ship dead, split one decision's
   mutation witness across two sites that `SITES` asserts exactly and that fail
   in both directions (`AGENTS.md:147`; `MutationRunner.cmake:59-62`), and owe
   an `EXPECT_SURVIVES` for a check the tree already has a reachable rejection
   for. `pass-schema`'s §16.2:884 IR-version check also survives, but not as an
   instance of that rule: it duplicates nothing, so the rule above does not
   reach it either way. It is the sole rejection site for that requirement —
   `make-machine` stamps `machine-ir-version` as a constant (`ir.sls:351`, into
   slot 1 at `:365`) and `machine-tag` is unforgeable (`ir.sls:41-43`) — so it
   closes a listed-and-unimplemented gap rather than re-closing one, and it pays
   for its unreachability with an `EXPECT_SURVIVES` Slice ①b is to declare, its
   reason measured on the staged tree only when that slice runs it
   (`milestone-4-design.md` §6 task 3's `EXPECT_SURVIVES`-with-a-measured-reason
   resolution, `:990-994` at the time of writing), not measured here.

## Consequences

- **Slice ①b's constructor work is fully specified and its verifier work is
  fully bounded.** `make-uint-field` validates width, name, and `initial`
  against the width, and nothing else; the field pass carries duplicate and
  portable field names and must **not** re-check widths or initials — a machine
  whose field failed construction never exists, so the arm would be item 6's
  dead code. Exit criterion §25:1568's declaration-time share is therefore
  discharged by a **raised condition** at `2^w`, at all four widths, and never
  by a diagnostic; a unit lane asserting a diagnostic there is asserting the
  wrong mechanism.
- **Slice ② inherits its constructor list, its pass-6a list, and the shape of
  its own test matrix.** The four-safe/three-failing partition of item 5 is the
  design's §7 task 8 preflight property seen at construction time, so the
  width-by-operation matrix has four operations with no error target and no
  failure column and three with both; that shape is settled here and is not the
  implementing task's to choose. Field branch has no error slot to design.
- **Slice ③ loses one arm and gains no code.** Its constructor takes `base` in
  `{10, 16}` plus local shape and nothing relational — there is no machine to
  resolve a field against at construction. §16.2:904's *base* half is
  discharged by an in-place note beside the pass, not by a clause inside pass
  6a's field walk; its *incompatible field* half stays as the design's §4.6
  settles it, folded into the declared-field-reference check. The milestone's
  Exit limitation 3 (§16.2:904 discharged by a check with no independent
  content) stands and is now true of both halves.
- **The diagnostic-code budget holds at two, and this split is what makes it
  hold.** `invalid-field-declaration` covers duplicate and nonportable field
  names (①b); `invalid-field-operand` covers arity, undeclared field
  reference, constant range, mask range, and `low > high` (②, reused by ③ with
  no addition). Width, initial value, operation, predicate and `base` carry no
  code, which is the whole of the saving: five closed sets that §16.2:889 and
  :904 would otherwise have made five diagnostic surfaces.
- **Not touched.** Nothing here changes the diagnostic *record* — widening it to
  §16.4's seven fields is Milestone 7, and the offending field name rides the
  existing `node` slot. Nothing here reaches execution: §15:856's
  check-before-commit is an execution property that item 5 only reads, and
  §25:1569 remains true by construction rather than by rollback. And nothing
  here revisits decision 0017 — its four points stand exactly as written; this
  record establishes only that its *argument* is unavailable where §16.2 speaks.

---

## 2026-09-02 (Slice ①b) — item 6's unreachability premise is false, and no `EXPECT_SURVIVES` is declared

Item 6 says `pass-schema`'s §16.2:884 IR-version check "pays for its
unreachability with an `EXPECT_SURVIVES` Slice ①b is to declare", resting on two
premises: that `make-machine` stamps `machine-ir-version` as a constant, and that
`machine-tag` is unforgeable (`ir.sls:41-43`).

**The second premise is false, and the first does not imply the conclusion.**
Measured before Slice ①b's task 3 ran: IR descriptors are bare R6RS vectors with
no opacity, so `(vector-ref good 0)` copies the tag using an `(rnrs)` primitive
and no private import, and the forged object satisfies `machine?`. A test can
therefore build a machine at an unsupported version and reach the new arm. That
the stamp is a constant makes the version un-*varyable through the constructor*;
it does not make the arm unreachable, which is a different claim.

**So Slice ①b declares no `EXPECT_SURVIVES` for this check.** It ships two
ordinary pins instead, one per direction — permissive (accept any version),
caught by the forged-machine case; restrictive (mutate the supported constant so
every machine becomes unsupported), caught by every verify lane. Both measured.

The forged-machine device is test-only and labelled as one at its site, and its
**premise is asserted alongside** — that the tag was copied and the version is
not the supported one — so that if the representation ever gains real opacity the
case fails loudly instead of passing vacuously on some other `invalid-shape`.

**The design's parallel instruction is amended too**, at `milestone-4-design.md`
§6 task 3 and its Amendments block: the trap that item prescribes an
`EXPECT_SURVIVES` for does not exist. The rest of item 6 stands — the check is
still the sole rejection site for §16.2:884, and it still closes a
listed-and-unimplemented gap rather than re-closing one.

*AGENTS.md reserves `EXPECT_SURVIVES` for the genuinely unwitnessable with a
written reason, and "this cannot be tested" is a claim to demonstrate rather than
assume. Here the demonstration went the other way, which is the only reason this
note exists.*
