# 0024: The callback error vocabulary — one `callback` domain, two codes, one fixed reason

Date: 2026-09-04
Status: accepted
Milestone: 5, Gate 0 (milestone-5-design.md §4.1, §4.2)

> **Amendments** — later notes at the foot of this file reach back into the text
> above them. Nothing above a note is rewritten.
>
> - **2026-09-05 (Milestone 5, Slice ②)** — **annotates the Consequences bullet
>   "What this hands to Slice ②"**: the code half is implemented, and the
>   Consequences' warning that a domain-only cross-lane check "passes vacuously
>   by construction" is what shaped the fixtures. Nothing above became false.
> - **2026-09-05 (Milestone 5, Slice ④)** — **annotates the Consequences bullet
>   "What this hands to Slice ④"** (its `milestone-5-design.md`:876-881 citation
>   is wrong; §9's exemption boundary is at :980-985): the discharge, and the
>   citation's correction. The obligation itself was read correctly and is met.

## Context

Decided 2026-09-04, against the tree this gate was dispatched at (`cc66302`).
Every plan sentence and source line cited below was read from the working tree
that day. Gate 0 writes no code: this record hands obligations to Slice ② and
Slice ④ and performs none of them.

**The plan names this error three ways and defines it once.** Measured today,
`rg -ni "callback application|callback-contract"` over
`docs/plans/byte-machine-implementation-plan.md` returns exactly three lines:

| citation | text |
| --- | --- |
| `§10.5:530` | "Callback application failures occupy a separate runtime error domain and do not need source-IR declarations." |
| `§10.6:586` | "Unknown results are runtime callback-contract errors." |
| `§12.3:719` | "The machine entered a declared machine error or callback application error." |

`rg -n "callback-contract"` alone returns **one** line, `§10.6:586`, and that
sentence is the whole of the plan's treatment of a callback returning a value
outside its declared outcomes. It assigns no domain, no code and no reason.
Whether the three phrases above name one thing or three is itself unsettled, and
a slice cannot implement a vocabulary that has not been fixed. **This record
binds all three phrases to one domain.**

**The accessors that must answer already shipped, with their callback half
empty.** `§9.3:398` fixes the domain's two values — `(parser-error-domain error)
; machine | callback` — and `§9.3:401` annotates the detail "`#f` for machine
errors". [Decision 0022](./0022-structured-parser-error-record.md) shipped the
whole eight-member record in Milestone 4 (item 1) and fixed both callback-side
values at their machine-domain constants **inside the constructor** (items 1
and 2): `byte-machine-make-parser-error/v1` writes `'machine` and `#f`
positionally and no call site passes either
(`src/byte-machine/runtime.sls:161-163`). 0022's
Consequences named `§13:808`'s explicit callback failure as what Milestone 5
would bring to populate them. This record is the vocabulary half of that
deferral's other end; Slice ② is its code half.

**The condition channel is populated, and it is where a wrong guess lands.**
Measured today over `src/`: `byte-machine-contract-violation` has **55 call
sites** carrying **six** distinct codes — `invalid-argument` (42), `internal`
(7), `lifecycle-violation` (3), and one each of `unverified-machine`,
`invalid-slice` and `accessor-misuse`. None of the six concerns a value a
callback returned. Nothing in the tree forces the choice below; the plan does,
and only if the right sentences are read.

## Decision

1. **A callback-contract error is a stored parser error in the `callback`
   domain, delivered through the ordinary error-result path, and sticky.**
   Under the Context's binding, `§12.3:719` puts this family on that channel by
   name — "a declared machine error **or callback application error**" is what
   the `error` feed status means, and "The status is sticky until reset.
   Repeated feed attempts return the same error without consuming input."
   `§12.1:671` gives `error` as a feed outcome and `§12.2:696` gives the sticky
   row's behaviour. `§13:824` supplies the verb: "no error is installed until a
   callback returns failure" — *installed*, which is what a stored error is. The
   record it is stored in is 0022's; this record adds no member and changes no
   shape.

2. **It does not poison.** `§12.6:749` is the only sentence in the plan that says
   what poisons a parser. Measured today, `rg -n "poison"` over the parent plan
   returns **eight** lines. Two of them are section headings and state nothing —
   `§12.6:745` ("### 12.6 Misuse and poisoning") and `§25:1572` ("### Milestone
   5: Callbacks, poisoning, and spans"). The five that remain beside `§12.6:749`
   are downstream of the state, not triggers for it: `§9.4:438` (the `poisoned
   parser` condition code), `§12.2:698` (the `poisoned` lifecycle row),
   `§12.5:739` (reset "clears … poison state"), `§19.3:1025` ("poison cleanup")
   and `§25:1579`, whose Milestone 5 scope bullet reads "unexpected escape
   poisoning" and names nothing wider.

   `§12.6:749` reads: "If a callback raises an unexpected condition or performs a
   nonlocal escape, the condition/escape propagates and `dynamic-wind` marks the
   parser poisoned." A wrong return value matches neither disjunct of the
   antecedent — and, decisively, **the consequent is not expressible for it**:
   there is no condition and no escape to propagate when a callback returns.
   Extending poisoning here would widen, by inference, an enumeration the plan
   states in exactly one sentence.

   `§12.6:749`'s own first sentence routes the other half of callback
   misbehaviour before the poisoning sentence begins — "Expected callback
   failures must use callback result values" — so the two mechanisms are stated
   in one place and this error belongs to the first.

3. **It is not an API-contract condition.** `§9.4:429` scopes that channel:
   "Portable API-contract conditions are tagged byte-machine values raised
   non-continuably with Scheme `raise`", and `§12.7:775` keeps "API-contract
   conditions and unexpected callback conditions … distinct from parser data
   errors". A callback returning an undeclared value is neither the caller
   misusing the API surface nor a condition the callback raised.

   The nearest-looking entry in `§9.4:438`'s code list, **"callback binding
   error", is construction-time**: `§9.3:419` makes parser construction resolve
   `callback-bindings` and "rejects duplicates and unknown names, rejects missing
   required callbacks". That is the caller handing `make-parser` bad arguments, a
   different moment from a bound callback returning badly.

   **The absence of a callback-contract entry from `§9.4:438` is corroboration,
   not proof, and this record declines to lean on it.** That sentence opens
   "Codes include", so the list is not closed and nothing can be ruled out by
   absence from it alone. What settles the channel is `§12.3:719` in item 1,
   positively — but positively *given the Context's binding*: on the plan's text
   alone `§12.3:719` names a callback *application* error, and it reaches this
   error because this record binds that phrase to `§10.6:586`'s
   callback-contract error.

4. **The explicit `make-callback-failure` outcome and an out-of-contract return
   share the domain and are distinguished by code.** They are not the same event
   and `parser-error-code` is where the difference has to live.

   - The explicit failure's code is the **application's**. `§13:808` describes
     the outcome as "an explicit callback failure containing an application code
     and optional detail" and `§9.3:423` requires `make-callback-failure` to take
     "a symbolic code satisfying the same portable ASCII name grammar. Its detail
     is opaque application data." `parser-error-code` (`§9.3:399`) is the only
     code member the record has, so discarding the constructor's `code` argument
     would make a required parameter unobservable. It passes through, and the
     optional detail passes through to `parser-error-detail`.
   - The out-of-contract return has no application code, so the runtime **mints**
     one, fixed and identical in both lanes, and its detail is **`#f`**: there is
     no `make-callback-failure` call on this path and therefore no
     application-supplied detail. `§12.7:757` calls the member "optional
     callback-provided detail"; nothing was provided. Nor does the runtime put
     the offending returned object there — `§9.3:423` defines the detail as
     application data, and storing an arbitrary returned object would widen the
     retention surface Slice ④ has to reason about for no stated benefit.

   **The limit, stated rather than assumed:** nothing in `§9.3:423`'s grammar
   reserves the minted symbol, so an application that deliberately returns
   `make-callback-failure` with that same code produces an error no accessor can
   tell from the runtime-detected one. That is the application's own doing and no
   check in this project can see it. The record claims the two paths are
   distinguishable in the ordinary case, and claims no more.

5. **The `reason` is one fixed printable-ASCII constant, identical in both
   lanes.** `§12.7:753-757` makes reason a member of every sticky runtime error,
   with no domain split — "static reason and optional callback-provided detail" —
   while `§10.5:530` says callback application failures "do not need source-IR
   declarations", so there is no `errs`-table entry to draw a declared reason
   from the way a machine error does (`§10.5:527`, "static printable-ASCII
   reason").

   - **`#f` is ruled out.** `§12.7:757` calls it *static*, and the plan annotates
     the accessors that may answer `#f` where they are declared — `§9.3:395`
     ("`#f` unless error") and `§9.3:401` ("`#f` for machine errors").
     `parser-error-reason` at `§9.3:400` carries no such annotation.
   - **Rendering the code's printed form is ruled out.** By item 4 the code is
     application-supplied on one of the two paths, so a reason derived from it
     varies with an application's chosen symbol — which is no longer static in
     `§12.7:757`'s sense — and it would put a symbol's external representation
     into a behavioural contract.
   - Printable ASCII is the shape `§10.1:480` already fixes for reasons that
     reach generated output ("restricted to printable ASCII plus LF"), and
     keeping the callback-domain constant inside that shape keeps
     `parser-error-reason` answering one kind of value in both domains.

## Consequences

- **Both codes are differential fixtures, not unit tests.** `§12.7:777` and
  `§22.4:1271` make source-node name, domain, code, absolute position and
  position kind the values the interpreted and generated lanes must agree on, so
  each of item 4's two paths has to be exercised in both lanes rather than in one.

- **One of those five cannot diverge, and the fixtures should not be written as
  though it can.** This record prescribes 0022 item 1's construction
  (`src/byte-machine/runtime.sls:161-163`): `domain` is fixed inside the one
  shared constructor both lanes call rather than passed from a call site, so no
  emitted site and no interpreter site can write it differently — exactly as
  `machine` and `#f` are fixed there today. Item 5's `reason` is fixed by the
  same construction, but it is not one of the five: neither `§12.7:777` nor
  `§22.4:1271` compares reason across lanes, so no differential check is lost by
  fixing it. The differential's teeth for these errors are on **code,
  source-node name, offset and position kind**; a check that only compares
  domain across lanes passes vacuously by construction.

- **The position members need no new decision.** `§12.7:770` already assigns
  "Zero-width machine action or callback failure" a `boundary` at the current
  stream offset, which is the rule 0022 item 5 shipped as the zero-width jump's
  position kind. Slice ② populates a row in a table that already works; it does
  not choose a convention.

- **The out-of-contract-return fixture belongs to `§22`, not to `§21`.** The HTTP
  reference fixture's callbacks are restricted by `§21.5:1183-1187` to recording
  events, inspecting read-only fields, and injecting "`continue`, `pause`, or
  explicit callback failure outcomes". A callback that returns an undeclared
  value is outside that "may only" list, so the machine that produces the minted
  code is a test machine under §22's differential, and `§21.5` is not to be read
  as forbidding the case.

- **What this hands to Slice ④.** Item 4 gives the explicit-failure path a
  populated `parser-error-detail`, and `§13:799` names that slot among the
  application-owned carriers explicitly outside the no-retention guarantee:
  "Application-owned opaque values—including callback closures, user context, and
  callback error detail—may retain data by their own policy and are outside that
  guarantee." The parser's stored error therefore transitively holds application
  data that `§13:799` **permits** to retain the fed bytevector, and neither
  `§12.7:777` nor `§22.4:1271` compares detail across lanes. **Slice ④'s
  retention oracle must exclude the error-detail slot alongside user context**;
  an oracle that excludes only user context reports a false violation the first
  time a fixture callback fails with a detail holding its own slice.
  (`milestone-5-design.md`:876-881 (the retention oracle's third layer, "The exemption boundary") states the same boundary as the oracle's third
  layer. This bullet is the deferral's second end.)

- **What this hands to Slice ②.** The `callback` domain, item 4's two codes, item
  5's constant, and the obligation that both are produced by both lanes from the
  same construction. The seam those lanes cross — emitted `exec`'s parameters and
  the generated ABI — is
  [decision 0025](./0025-milestone-5-seam-encoding-abi-exec.md)'s, paid in Slice
  ①a before any of this runs. What a callback can see while the error is being
  produced — lifecycle `busy`, and which accessors answer — is
  [decision 0028](./0028-callback-slots-and-visible-state.md)'s, not this
  record's.

- **It changes nothing already decided.** [Decision 0013](./0013-runtime-coded-conditions.md)'s
  coded-condition family is untouched: item 3 adds no code to it, and the six
  codes measured in the Context stand. 0022's record shape, member order and
  constructor are untouched: this record populates two enumerated values 0022
  shipped with no producer, and adds no ninth member. For `domain` = `callback`
  this record names **two** producers, item 4's pair; for a non-`#f` `detail` it
  names the one 0022 named, `§13:808`'s explicit failure.


## 2026-09-05 (Milestone 5, Slice ②) — the code half lands

**What this record handed to Slice ②** — "the `callback` domain, item 4's two
codes, item 5's constant, and the obligation that both are produced by both lanes
from the same construction" — is implemented.

`byte-machine-make-callback-error/v1` fixes `domain` to `callback` and `reason` to
one printable-ASCII constant inside the constructor, exactly as 0022 item 1 fixes
`machine` and `#f`, so no emitted site and no interpreter site writes either. The
application's code and detail pass through on §13:808's path; the out-of-contract
path mints `callback-contract-violation` and its detail is `#f`.

**The Consequences' warning held.** "A check that only compares domain across
lanes passes vacuously by construction" — so the differential asserts the whole
projected record BY VALUE for both paths, not only that the two lanes agree, and
two of that lane's mutations edit code both lanes share (the outcome classifier
and this constructor) precisely because the cross-lane comparison cannot see them.

**One thing this record did not have to decide, and did not.** §13:812's two
sentences — event and span callbacks accept only continue/pause/failure, decision
callbacks may additionally return their declared branch keys — turn out to be ONE
test at the invocation site: an event node declares no branch targets and a
decision node declares exactly the keys §16.2:901's node half admits, so "does the
returned symbol name a declared branch of THIS node" answers both, out of data
both lanes already carry. No callback KIND crosses the seam.

---

**2026-09-05 (Milestone 5, Slice ④) — the "What this hands to Slice ④" bullet is
discharged, and its own citation had gone stale.**

*Discharged.* Slice ④'s retention oracle excludes neither carrier by enumeration:
it is reachability-based, and it ships an explicit arm for the case this record
warned about — a fixture callback failing with a detail holding its own slice,
asserted as RETAINED and permitted, in both lanes
(`test/common/retention-tests.sps`, "callback error detail may retain it too").
A second arm holds the same failing path with `detail` `#f` and asserts the
bytevector is gone, so the first arm is about `§13:799`'s third carrier rather
than about the error record. The retaining arm is mutation-pinned; the `#f`
discriminator is not, and is not claimed to be — no mutant's recorded failure
signature is that case's, and its control is the pair, not a pin.

*The wrong citation, and the first diagnosis of it was also wrong.* The bullet
points at `milestone-5-design.md`:876-881 for "the retention oracle's third
layer". Today that lands in §8's work list; the exemption boundary is at
**:980-985**. The first version of this note said Slice ③'s Appendix rewrites had
moved it — **measured, that is impossible**: the Appendix heading has always sat
BELOW §9 (960 at Gate 0, 1009 after Slice ②, 1042 after Slice ③), and an edit
below a section cannot renumber it. The citation was **wrong when it was
written**: at `79c18c7`, the commit that introduced it, "The exemption boundary"
was at :898 and :876-881 already held §9's "Scope, as an allocation" paragraph —
off by twenty-two lines on arrival. It reached :980 through growth in §§6-8.

That distinction is the whole value of the correction. A citation that DRIFTED is
an argument for re-measuring citations when the target changes; a citation that
was **never right** is an argument for resolving one when you write it, which is
a different discipline and the one that would have caught this. Nothing above
this note is rewritten.

The bullet called itself "the deferral's second end", which is why it mattered:
the second end never pointed at the first.
