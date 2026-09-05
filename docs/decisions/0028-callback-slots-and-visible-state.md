# 0028: Read accessors answer during `busy`; the active span gets the sixth one

Date: 2026-09-04
Status: accepted
Milestone: 5, Gate 0 (milestone-5-design.md §4.6, §4.9, §4.10)

> **Amendments** — later notes at the foot of this file reach back into the text
> above them. Nothing above a note is rewritten.
>
> - **2026-09-04 (Milestone 5, Slice ①b)** — **amends the Consequences bullet on
>   Slice ①b's accessors**: `parser-state-name` was deferred whole to Slice ② by
>   the owner, so ①b ships five of the six, not all six.
> - **2026-09-05 (Milestone 5, Slice ②)** — **annotates the 2026-09-04 note and
>   item 3**: the deferral it recorded is discharged — `parser-state-name`
>   shipped, by the route that note predicted — item 1's `busy` rule is witnessed
>   from inside a callback for all six accessors, and item 3's short circuit is
>   implemented as written, so the constraint it placed on §18:981's trace holds.
>   Nothing above became false.

## Context

Decided 2026-09-04, after Milestone 5 Slices ⓪ and ⓪b closed, against the shipped
tree. Three questions the parent plan leaves under-specified, all on the surface a
callback sees. Two are externally observable through the public API, so a slice
that picks one by accident pins the wrong answer in a golden. The third is
observable through nothing at all, which is the reason it needs a record rather
than a test: both lanes must make the same choice and no oracle would notice if
they did not.

**1. `§13:821` says "lifecycle is `busy`, so parser operations are rejected" and
nothing says which operations those are.** `§12.2`'s operation matrix
(`:689`–`:699`) has exactly four operation columns — `feed!`, `finish!`,
`resume!`, `reset!` — and no accessor column, so its `busy` row (`:699`) settles
nothing about the five read accessors. `§12.1:679` defines the state only as
"`busy` is an internal guard while feed, finish, or a callback is executing."

Measured 2026-09-04:
`rg -c "accessor" docs/plans/byte-machine-implementation-plan.md` returns
**nineteen** lines — twelve before this Gate appended its own disposition, seven
inside it — and not one of the twelve makes an accessor's availability
conditional on a lifecycle state. Two of them associate accessors with a callback
(`§13:818`, `§25:1564`) and both do so permissively. The nearest thing to a
restriction is `§9.4:438`, which lists "lifecycle violation, reentrancy, poisoned parser,
callback binding error, generated-runtime ABI mismatch, and accessor misuse" as
*distinct* codes; `§9.3:425` grounds the last of them in meaning, not in timing —
"Accessors enforce where fields such as `next` are meaningful." The shipped
implementation reads it the same way: `parser-field-ref`'s only `accessor-misuse`
raise (`src/byte-machine/runtime.sls:526`) fires on an undeclared field name, and
its comment says so — "reaching an accessor with something the machine never
declared."

**2. `§13:820` requires state that `§9.3` has no accessor for.** It commits the
runtime to reporting, for an automatic feed-boundary fragment, "the current source
input node together with the active span name". `§9.3:407-411` is exactly five
parser accessors — `parser-lifecycle`, `parser-state-name`,
`parser-stream-offset`, `parser-field-ref`, `parser-user-context` — and none of
them names a span. `parser-field-ref` cannot be stretched to answer, because
`§10.2:495` puts span markers on the other side of the field boundary: "Parser
bookkeeping such as current state, lifecycle, callback vector, user context,
cursor, stream offset, and span markers is not exposed as machine fields."

**3. `§9.3:419` fixes what an unbound optional callback *returns* and not what
occupies its indexed slot.** It requires that `make-parser` "installs
no-op/default behavior only where declared", and that "An optional decision
callback must declare `default-branch`; other optional callbacks default to
`continue`" — a rule about outcomes, silent about representation.

**And the slot does not exist yet.** Measured against `src/byte-machine/runtime.sls`
on 2026-09-04: `make-parser` (`:212`) binds `callback-bindings` and never reads it
— `rg -c "callback-bindings" src/byte-machine/runtime.sls` returns **1**, the
parameter list itself — and the parser vector it builds (`:223`, `:229`) carries
no callback member. `user-context` measures identically: one occurrence, the same
parameter list. Of `§9.3`'s five read accessors the runtime exports **two**,
`parser-lifecycle` (`:17`) and `parser-field-ref` (`:24`); `parser-state-name`,
`parser-stream-offset` and `parser-user-context` appear nowhere in `src/` or
`test/`. This record therefore writes a rule for five accessors of which two ship
and a slot that has no bytes — which is the point of settling it at Gate 0 rather
than inside the slice that builds them.

## Decision

**1. "Parser operations are rejected" (`§13:821`) scopes to the four mutating
operations. Every read accessor answers normally while lifecycle is `busy`.**

The scope is read off `§12.2:699`, the only place in the plan that says *which*
operations the `busy` rejection covers: one `busy` row, four cells, "Raise
reentrancy condition" in each. There is no fifth column to extend the rule to.
`§12.6:747` carries the same unscoped word — "Prohibited lifecycle operations and
reentrant parser operations raise API-contract conditions before further
mutation" — and is settled the same way: it names no operation of its own, and
its "before further mutation" clause has nothing to say about a call that mutates
nothing.

The direction is forced, bullet by bullet, by the committed-state list `§13:816`
addresses *to a callback*. Each bullet commits the runtime to exposing something
at callback entry, and callback entry is the one moment lifecycle is `busy`, so an
accessor that raised there would make its bullet unsatisfiable rather than merely
inconvenient:

- `§13:818` — "fields include every operation completed before the callback and
  are read-only through public accessors" — names its accessor outright, and
  `parser-field-ref` is the only one there is.
- `§13:819` commits stream offset and cursor; `parser-stream-offset` is the
  public form of the first, and the cursor has none — `§9.3:407-411` lists no
  cursor accessor, and `§10.2:495` keeps the cursor in parser bookkeeping — so
  the bullet is satisfiable at all only if `parser-stream-offset` answers.
  `§13:820` commits the public parser state name; `parser-state-name` is its
  public form.
- `§13:821` is the self-referential case: `parser-lifecycle` refusing to answer
  during `busy` would make the sentence being interpreted unobservable from the
  only situation in which it is true.
- `§25:1580` lists "busy/reentrancy guards and callback-visible committed state"
  as one Milestone 5 scope bullet, not two independent ones — the guard and the
  visibility are the same piece of work, and only one reading satisfies both.

`parser-user-context` is the honest exception and is stated as one: `§13:816-826`
does not name it. It is included for uniformity, on a weaker ground — all three
callback signatures (`§13:784`, `:790`, `:796`) hand `user-context` to the
callback as its second argument, so an accessor that refused during `busy` would
be denying a value the callback is already holding. A carve-out with no reason is
what a later slice re-derives wrongly.

**2. A sixth parser accessor, `parser-active-span`**, returning the active span's
name, or `#f` when no span is active.

Two alternatives were rejected, each for a reason that survives a check:

- **Widening `parser-state-name` to a compound value in the feed-boundary case.**
  `§13:820` calls the fragment **automatic** — the split is chosen by the runtime,
  not declared by the machine — so no caller can *predict* which calls return the
  compound. (It stays detectable after the fact by a type test; predictability is
  what is lost.) Every existing caller's contract would become conditional on a
  case it cannot anticipate, to serve a case none of them asked about.
- **Treating `§13:820` as a debug-only surface with no public witness.** With
  `parser-field-ref` already ruled out by `§10.2:495`, that leaves `§13:822` ("a
  span-data callback sees its named span active with the delivered mark already
  advanced to the fragment end") and `§13:823` ("a span-complete callback sees
  that span inactive") with no observable form at all. `§22.4:1267` compares
  "final state and fields" across lanes — exactly the two surfaces the span would
  then sit outside. The oracle would not go wholly blind: `:1269` still compares
  "exact span fragment ranges/content" and `:1268` the callback order, so every
  fragment "one active named span" (`§25:1581`) emits is checked either way. What
  nothing in `:1264`-`:1272` compares is whether the span is *active* — which is
  the whole of what `§13:822` and `§13:823` fix, and the half where the two lanes
  can diverge in silence.

`§9.3` is a **normative list**, so this is a plan change and not a silent
addition. It landed 2026-09-04 as an appended disposition in
`docs/plans/byte-machine-implementation-plan.md`'s `## Dated dispositions`,
which adds the entry without moving a line of `§9.3` or renumbering any
`§section:line` citation.

**3. An unbound optional callback's slot holds a sentinel, short-circuited at the
invocation site.** The alternative — installing a closure that returns the
declared default — is uniform, but allocates one closure per unbound optional
callback at construction.

**The honest ground: no application-visible witness distinguishes the two.** An
unbound optional callback is, by construction, one the application supplied no
procedure for, so under either shape the set of application procedures a harness
can wrap is identical and the `§22.4:1268` "callback order and results" sequence
is the same. The choice is taken on **cost, not on observability**, and this
record says so rather than manufacturing a reason.

One surface could in principle tell them apart, and it is named here so that it is
decided rather than discovered: `§18:981`'s trace entry, "callback invocation and
result". It is not a differential witness — `§18` is the reference interpreter,
its hook is "an optional trace hook for tests" (`§18:974`) and "is not invoked
unless explicitly enabled" (`§18:985`), and the generated lane has no counterpart
to compare against. Slice ② must not trace a short-circuited slot as an
invocation; if it does, this item's "not observable" stops being true in the one
place it can.

The decision still binds **both lanes**. That is the reason to write it down, not
the reason to prefer it: a divergence here would be invisible to the differential.

## Consequences

- **Slice ①b implements `parser-active-span`** and takes it from this record and
  the appended disposition, not from `§9.3`'s body, which is unchanged. The same
  slice owns the three accessors measured absent above — `parser-state-name`,
  `parser-stream-offset`, `parser-user-context` — and `parser-active-span`
  besides, so item 1's rule is written for five accessors of which two ship,
  item 2 makes it six, and all six become testable in one slice rather than in
  three.

  > **Amended 2026-09-04 (Milestone 5, Slice ①b)** — `parser-state-name` is
  > Slice ②'s, so five of the six ship here. See the note at the foot.
- **Slice ①b owes the slot resolution `§9.3:419` describes and `make-parser` does
  not perform.** `milestone-5-design.md`:715 (the `make-parser` bullet) puts "`make-parser`'s `§9.3:419`
  binding resolution" in that slice and drives each of its rejections from a
  positive test, and
  [decision 0025](./0025-milestone-5-seam-encoding-abi-exec.md) calls the same
  work "①b's callback-slot and accessor work" — so the sentinel that occupies an
  unbound optional slot is installed there. **Slice ② owes the other half**: the
  short-circuit that reads it, which cannot be written before the
  callback-invocation node exists, and the `busy` guard on exactly the four
  mutating operations and no more. The callback error channel those slots report
  through is [decision 0024](./0024-callback-error-vocabulary.md); the reserved
  slot vector the emitted `exec` receives is decision 0025's item 3.
- **Item 1 is testable before spans exist.** Any read accessor called from inside
  an event or decision callback witnesses it, in both lanes, with no span
  machinery — so it is not blocked behind
  [decision 0029](./0029-span-state-is-a-lattice.md)'s pass or
  [decision 0027](./0027-reachable-path-for-callbacks-and-spans.md)'s reachability
  relation.
- **Item 3 is the one decision here with no oracle**, by its own argument. It is
  held by review, by both lanes reading this record, and by the constraint on
  `§18:981` above — not by a test. A slice that "verifies" it has misunderstood
  it.
- **What `parser-active-span` returns inside a span-complete callback is not this
  record's to decide.** `§13:823` already answers it — the span is inactive, so
  `#f` — and that is `§13`'s sentence, cited rather than restated.
- The `busy` rule fixes the shape of the reentrancy guard: it goes on the four
  operations, so a guard placed on a shared internal entry point that every
  accessor also passes through would be wrong even though every mutating test
  still passed.

## 2026-09-04 (Milestone 5, Slice ①b) — one of the six accessors moved to Slice ②

The Consequences bullet above says Slice ①b "owns the three accessors measured
absent above — `parser-state-name`, `parser-stream-offset`, `parser-user-context`
— and `parser-active-span` besides", and concludes that "all six become testable
in one slice rather than in three."

**Five became testable in ①b. `parser-state-name` did not, and the owner deferred
it whole to Slice ② on 2026-09-04.**

**Measured while planning ①b:** `§13:820` requires it to name "the source
callback/span node, not a generated internal continuation". The `'v2` parser holds
`current` as an integer state id, and `normal-machine-debug-map` — the id→name map
— is read at exactly one site, at *emission* time, where it bakes names into
emitted error constructors as literals. It never crosses into the emitted library.
The interpreted lane can answer today; the generated lane cannot answer at all
without a table that does not exist.

The plan first proposed shipping it answering in the interpreted lane only. The
owner took the stronger reading, and the reason is recorded because it generalises:
**a public accessor that answers in one lane and not the other is worse than one
that does not exist yet.** It would ship a `§9.3` name whose contract holds only
where a caller happens to be, and the differential would compare an answer against
a hole rather than failing.

Slice ② is where it belongs: the first slice that invokes a callback, and so the
first with a caller that can witness the value, and the first that must carry an
id→name table into the generated lane regardless.

**Nothing else in this record changes.** Item 1's `busy` rule is written for five
accessors and still is; item 2's `parser-active-span` shipped in ①b as stated.


## 2026-09-05 (Milestone 5, Slice ②) — the deferral closes, and item 3 reports

**`parser-state-name` shipped**, as the foot note above said it would, and by the
route that note predicted: Slice ② had to carry an id→name table into the
generated lane regardless, and it is ABI payload member 2 — §17:963's state-id to
source-name vector, total over internal prefix states. §9.5:444 made that a
version bump, 4 → 5. The alternative the note called "a separate emitted
definition" is not a third transport: the emitted library exports one name and
the compiled-machine constructor's five arguments are the only channel, so a
top-level `define` would still have to be passed in.

**Item 1 is witnessed, and needed a fix to be true.** All six read accessors are
called from inside a callback in both lanes and all six answer. The generated
lane did not satisfy §13:819-820 as shipped: emitted `exec` owns its own
`pos`/`off`/`st` locals and writes the parser's slots only on RETURN, so a
callback would have seen the offset the feed began at and the state it began in.
The shared invocation commits both before invoking; on the interpreted side those
writes are no-ops.

**Item 3 reports, as this record asked it to.** The sentinel is short-circuited at
the invocation site and **the closure is never called** — the short circuit is
literally `(if (unbound-callback? f) (list 'goto default) …)`, and `f` is only
applied in the other arm. So the constraint this record placed on §18:981's trace
holds: nothing can trace a short-circuited slot as an invocation, because nothing
invokes it. The declared default is resolved to a TARGET at lowering time, in two
independent walks (the normalizer's and the interpreter's, decision 0015 point 3),
so the invocation site carries no rule of its own.

**Nothing else in this record changes.** Item 2's `parser-active-span` shipped in
①b and is unchanged; item 1's scoping to §12.2's four mutating operations is what
Slice ②'s reentrancy row implements.
