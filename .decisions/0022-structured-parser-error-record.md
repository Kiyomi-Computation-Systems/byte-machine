# 0022: The structured parser-error record — one shape in both lanes, position kind from the arriving transition

Date: 2026-08-31
Status: accepted
Milestone: 4, Gate 0 (milestone-4-design.md §4.5)

> **Amendments** — later notes at the foot of this file reach back into the text
> above them. Nothing above a note is rewritten.
>
> - **2026-09-02 (Milestone 4, before Slice ①b)** — **amends item 7**: the table
>   is one entry per error declaration the graph **reaches**, not per declaration
>   declared. Raised as an open question by Slice ①a's whole-branch review and
>   resolved before ①b, because 0019 point 5 makes the golden it moves a STOP
>   condition for every later slice.
> - **2026-09-06 (Milestone 7 Gate 0)** — **annotates the "It deliberately touches
>   nothing else" bullet**: "that is Milestone 7 (§25:1616)" is
>   [decision 0032](./0032-diagnostic-record-seven-fields-and-path-policy.md),
>   implemented by Milestone 7's Slice ①; `§16.4:945`'s comparison rule, which the
>   bullet invokes, is unchanged. Nothing above became false; this bullet is the
>   whole note.
> - **2026-09-11 (Milestone 7 Slice ②)** — **annotates item 7's amendment**:
>   records where the reached-but-unencoded declaration shape it names is now
>   produced (the Slice ② generator's `orphan-prob`/`dangling-prob` draws) and
>   consumed (Slice ④). Nothing above became false.

## Context

Decided against the shipped tree at `a942327`, the commit Milestone 3 closed at.
Nineteen commits sit between `a942327` and this record and none touches `src/`
(`git diff a942327..HEAD -- src/` is empty). One of them, `1dcb804`, edits
`.plans/byte-machine-implementation-plan.md` — the file this record cites by
line more than any other — but only as a single line substituted for another, at
§9.5:442; no downstream line moves.

**Today the error slot is a bare code symbol.** `parser-result-error` is
`(vector-ref r 5)` of the parser-result vector (runtime.sls:88-95), and every
producer puts a symbol there. The interpreter's `error-value` returns
`(error-declaration-code (lookup-error errors …))` (interpret.sls:105-107), and
`default-eof-value` the same (interpret.sls:108-109). The emitter renders that
symbol as a literal in the error arm (compile.sls:113-115) and in the
default-eof arm (`render-eof-branch`, compile.sls:95-99); the committed golden
shows the result as `(byte-machine-make-feed-outcome/v1 (quote error) pos (quote
unexpected-byte) 3 off)` (test/fixtures/generated-http-version.golden.sls:18).
Tests read it as a symbol — `(check-equal "error value" (parser-result-error r)
'unexpected-byte)` (runtime-tests.sps:51). Of §9.3:397-405's nine public names,
**none** exists: `rg 'parser-error'` over `src/` returns nothing. A machine
error therefore reports one of the eight members §12.7:753-760 requires it to
record.

**The family has been deferred twice, both times to "M4/M5".** Milestone 2 put
it out of scope in its own §7 — "**The full structured `parser-error-*` accessor
family** (§9.3), including `position-kind`" — with the note that "the
categorical `position-kind` marker and richer error structure arrives with the
milestones that produce richer errors (M4+)"
([milestone-2-design.md](../.plans/milestone-2-design.md):461-464). Milestone 3
deferred it again in its §8:992-997, on the same authority. The rule both
deferrals rest on is milestone-2-design.md:343-344, which rejected shipping
`position-kind` alone in M2 because that "removes an inconsistent carve-out
(populating one field of an otherwise-deferred accessor family)". That rule is
the reason the family cannot land a member at a time, and it is what makes this
record's scope the whole of §9.3:397-405 rather than the two members M4's own
error paths would otherwise force.

**A third deferral is not available.** §22.4:1271 makes the
interpreter≡generated differential compare "error domain, code, public
source-node name, absolute position, and position kind", and Milestone 4's exit
criterion §25:1570 is discharged through that list — so deferring again would
make M4's own exit criterion unassertable in the terms §22.4 states it.

**The debug map was deferred on exactly this dependency, and its inverse is
already built.** Milestone 3's §8 struck §17:963's map with a reason that names
this record: "**The state-ID-to-source-name debug map** (§17:963) — its only
consumers are the unshipped parser-error accessors, and no v0.1 error is raised
*inside* a lowered prefix state"
([milestone-3-design.md](../.plans/milestone-3-design.md):1004-1006). The forward
direction exists: `lower-machine` builds `name->id` by walking `machine-nodes`
with an index (private/normal-ir.sls:140-142). It is local — `lower-machine`
returns only `(values entry states)` (:248) and `make-normal-machine` is a
four-slot vector (:28) — so the inverse is a threaded return value, not an
analysis. Internal prefix states are the one part `name->id` does not cover:
they are numbered by `allocate-prefix-ids` (private/normal-ir.sls:128-135) from
the declared count onward and must take their entries from the prefix-block walk
instead of from inverting the alist.

**Position kind is a property of the transition that arrived, not of the error
state.** §12.7:766-773's table is the authority, and two of its rows prove the
point on their own:

| Error source | Stored position |
| --- | --- |
| Reexecute mismatch / rejected digit | `byte` at the current stream offset |
| Error edge after an advance | `boundary` after the committed byte |

One error node reached by a reexecute edge reports `byte`; the *same* node
reached by an advance edge reports `boundary`. The emitted arm for a normalized
error state is keyed on the state id alone (`render-state-arm`,
compile.sls:113-115) and cannot see which edge jumped to it, so position kind
cannot be a per-site literal in either executor. The remaining rows are :770
("Zero-width machine action or callback failure" → `boundary` at the current
stream offset) and :771 ("Truncated input during `finish!`" → `eof` at the final
stream offset).

**All three kinds are already producible, which is why the family is
front-loadable.** `byte` comes from a reexecute fallback, `boundary` from an
advance-mode edge, and `eof` from a `finish!` over exhausted input — byte
dispatch and error nodes, both shipped in Milestone 1 (§25:1457-1461); Milestone
2 adds no node kind here, only `finish!`/EOF execution (§25:1503), without which
the `eof` kind has no producer. The whole family can therefore be proved in a
slice that adds no node kind; Slice ② adds :770's row and Slice ③ :773's
overflow rider to a table that already works.

## Decision

1. **The record is one tagged vector with eight members and nine public names,
   and the member order is §9.3:398-405's.** `domain`, `code`, `reason`,
   `detail`, `node-name`, `state-id`, `offset`, `position-kind`, plus
   `parser-error?` (§9.3:397). It lives beside the parser-result tag
   (runtime.sls:86-95) and is opaque per §9.3:425. Generated code constructs it
   through one reserved binding, `byte-machine-make-parser-error/v1`; all ten
   names are mirrored into `reserved-member-2` (compile.sls:44-52, twenty
   symbols at `a942327`) in the same commit that exports them, per decision 0012
   item 4, so the `reserved-drift-tests.sps` guard stays load-bearing.

   **The reserved constructor takes five arguments per call site, not eight.**
   `(byte-machine-make-parser-error/v1 (vector-ref errs N) (quote name) id off
   pk)` — the `errs`-table entry (packing `code` and `reason`), the public
   source-node name, the state id, the absolute offset, and the position kind.
   `domain` and `detail` are not call-site arguments at all: the constructor
   fixes them internally to decision 2's values, `machine` and `#f`, so no
   generated site ever writes them.
2. **Every accessor ships at once, and `domain`/`detail` ship at their
   *specified* machine-domain values.** `domain` is `machine` and `detail` is
   `#f` at every Milestone 4 construction site. `#f` is not a placeholder:
   §9.3:401 annotates `detail` "`#f` for machine errors". This is what
   milestone-2-design.md:343-344 requires — a whole family, not one populated
   field of a deferred one.
3. **Both lanes construct the same record, with the same members, from the same
   inputs.** The interpreter's two error producers (interpret.sls:105-107 and
   :108-109) and the emitter's two error-producing arms (compile.sls:113-115 and
   :95-99) stop yielding `error-declaration-code` and yield a `parser-error`
   instead. They land in one commit: the lanes are compared by value, so a split
   leaves the differential red between commits. §12.7:777 makes source-node
   name, domain, code, offset and position kind "semantic and must match between
   interpreted and generated execution", and this is the construction that makes
   that assertable.
4. **`feed-outcome` does not grow.** It keeps its five slots and its `/v1`
   constructor (runtime.sls:78-84); its existing `error` slot merely carries a
   richer value. Decision 0012 item 3 is the precedent — "`paused` and
   `finished` are new status *symbols*, not a new record" — and the only
   reserved `feed-outcome` `/v2` is decision 0010's Consequences / Slice-B
   amendment, an optimization "gated on benchmark evidence" (§23) that cannot
   exist yet: `bench/` holds two `.gitkeep` files. Consequently the sticky-error
   rows (runtime.sls:150-151 and :245-246), the four `parser-set-stored-error!`
   call sites that store a produced error (:161, :268, :301, :309) — a fifth,
   `parser-reset!`'s clear to `#f` at :334, is unrelated — and the slot's setter
   (:135) take no edit: they store and return whatever the executor produced.
   That is the amendment working rather than an omission.
5. **Position kind is carried as one more loop variable in each executor,
   set from a literal at each jump.** `advance` → `boundary`; `reexecute` →
   `byte`; the EOF-chain jump → `eof`; and — the case Milestone 4's seam slice
   cannot itself produce, fixed here so Slices ② and ③ inherit a rule instead
   of each choosing one — a **zero-width jump → `boundary` at the current
   stream offset**, per §12.7:770. **The loop-entry initialization is
   `boundary`, unconditionally, in both lanes, with no `finish?` key.** Nothing
   has been consumed since either kind of call began, so an error state reached
   with no jump taken reports a boundary at the current stream offset
   regardless of whether a feed or a `finish!` call is the one observing it —
   the parked-continuation case discussed below shows both lanes agreeing at
   exactly that value, which is the same value a feed resuming onto the
   identical state already reports below. §12.7:771's truncated-`finish!` row
   does not license a different initialization here: nothing is truncated by a
   call that merely observes an error state reached earlier. In the generated
   lane the initial value is one literal at the loop header — the `(let loop
   ((pos start) (st state) (off offset)))` header at compile.sls:157 gains a
   fourth argument, `(quote boundary)`, unconditionally — and both `loop-tail`
   forms (compile.sls:75-78) carry it forward on every advance/reexecute jump
   they render; it joins `reserved-member-3` (compile.sls:53) in the commit
   that emits it. The interpreter keeps this same split across two functions
   rather than one flag: `parser-feed-op!` gains a second loop variable,
   initialized to `boundary` (runtime.sls:171-201, whose dispatch arm already
   has the mode in hand at :196), and `parser-finish-op!` gains one too,
   threaded through its own `loop` (runtime.sls:283-311): initialized to
   `boundary` and set to `eof` on the eof-target hop out of its `(dispatch)`
   arm — the `(loop t)` at runtime.sls:306 — then read, not hardcoded, by its
   error arm (runtime.sls:297-302), in place of the bare code symbol it
   returns today. `eof` is reserved for where truncation actually occurs or is
   inherited along the EOF-target chain: the loop variable itself, set to
   `eof` at the chain hop — `render-eof-branch`'s node case in the generated
   lane, and `parser-finish-op!`'s `(loop t)` above in the interpreter — and
   its terminal counterpart, reached by no jump at all once the chain is
   exhausted: `render-eof-branch`'s default-EOF arm, which takes its own
   per-site `(quote eof)` literal (compile.sls:95-99), and
   `parser-finish-op!`'s `(dispatch)` arm's `default-eof-value` message, the
   interpreter's matching path (runtime.sls:303-310).

   **This closes a gap the old initialization left open.** A pause's
   continuation is reachable as an error node directly — for a byte-reachable
   pause the verifier rejects only a `finish` continuation and
   `eof-reachable-stop`/`cycle` (verify.sls:438-457), while `eof-terminal`
   classifies an error continuation as `'error` (verify.sls:364) — and
   `parser-feed-op!` parks `current` on that continuation (runtime.sls:186). A
   pause's continuation is itself a zero-width edge (verify.sls:270-271,
   :333-336), so a feed resumed directly onto an error state has consumed
   nothing in this call: the same "nothing consumed" condition the rule above
   assigns `boundary` for, not `byte`. Reporting `byte` there would name an
   offending byte at an offset the parser has never read.

   **Two sites sit outside every jump rule above.** Unlike a normalized error
   state — reached by one of the four jumps this record classifies, whose
   emitted arm (`render-state-arm`, compile.sls:113-115) is keyed on state id
   alone and genuinely cannot see which edge arrived, which is why position
   kind is *not* a per-site literal there — both sites below are terminal
   constructions a jump does not lead into. **The first is the generated lane's
   default-EOF arm, which takes a per-site literal `eof` instead of the loop
   variable.** The default-EOF arm (`render-eof-branch`, compile.sls:95-99) is
   a terminal construction: on the EOF-target chain's first dispatch it is
   reached by no jump at all, because `parser-finish-v2!` (runtime.sls:260-262)
   calls `exec` over an empty slice, so `pos >= end` immediately. This arm
   fires with the loop variable still at its initialization only when the
   EOF-target chain has no hop before it; when `render-eof-branch`'s own node
   case (compile.sls:96-97) has jumped a prior hop there first, the variable
   already reads `eof` — "still at its initialization" is not true of every
   site, only of those reached with no prior hop. §12.7:771 fixes `eof`
   regardless of which, so this arm takes the same shape with a literal `(quote
   eof)`, matching the interpreter's own constant `eof` in `parser-finish-op!`
   above. The differential will catch a generated lane that instead inherits
   the loop variable here — but the tempting green-restoring repair is making
   the *interpreter* agree at `byte` instead, which is consistently wrong: both
   lanes reach this arm by exhausted dispatch, whether or not a prior hop ran,
   and §12.7:771 admits only `eof` either way.

   **The second is the parked error state a `finish!` call inherits from a
   pause, and both lanes agree at `boundary` for it.** `parser-finish-v2!`
   (runtime.sls:260-262) passes `(parser-current parser)` into `exec`
   unconditionally, including when a prior pause parked `current` directly on a
   normalized **error** state — the case the paragraph above establishes as
   verifier-legal, reachable as feed → pause → `parser-resume!` → lifecycle
   `ready` → `parser-finish!` (runtime.sls:249 admits `ready | finish-ready`).
   `exec`'s `case st` then reaches `render-state-arm`'s error arm
   (compile.sls:113-115) on its first dispatch, no jump taken, with the loop
   variable at its initialization — the same site shape as the first, reached
   through `parser-finish-v2!` rather than the exhausted-dispatch default.
   Because the loop-entry initialization is `boundary` unconditionally, as
   fixed above, the generated lane reports `boundary` here. The interpreter
   reaches the same parked node through `parser-finish-op!`'s `((error) …)` arm
   (runtime.sls:297-302), reading the same loop variable fixed above — at its
   initialization value here too, since this arrival takes no jump — not `eof`,
   because nothing is truncated by a `finish!` call that merely observes an
   error node a prior feed already reached. Both lanes therefore agree: the
   parked continuation is the same zero-width edge whichever API call arrives
   on it, so it reports the same `boundary` a feed resuming onto it already
   reports (the paragraph above) — position kind is a property of the
   transition that arrived, not of which call observes it, exactly as the
   Context above states it.
6. **The absolute offset needs no new arithmetic.** `off` is already bumped on
   advance and not on reexecute — in the interpreter at runtime.sls:196-200 and
   in the emitted tails at compile.sls:75-78 — so `(off, position-kind)` *is*
   §12.7's stored position in both executors. That the two lanes reach it by the
   same rule from independent code is the strongest available evidence the
   lowering is 1:1.
7. **The static payload lives in one immutable per-library table keyed by error
   *declaration*, not per site.** *(**Amended 2026-09-02** — the table holds one
   entry per **reached** declaration. See the note at the foot.)* Generated code defines `(define errs (quote
   #(#(<code> <reason>) …)))`, one entry per error declaration — §19.1:996's
   "immutable field/callback/debug metadata" literally — and each site builds
   its record from a table index plus its own two literals (public source-node
   name, state id) and the loop's two variables. The reason is measured, not
   aesthetic: `generated-http-version.golden.sls` carries **nine** error sites
   over **two** declarations, eight of them the default-eof arm (:10, :22, :31,
   :40, :49, :58, :67, :76) because `render-eof-branch` renders at every
   dispatch state. Per-site literals would repeat each reason string once per
   site. `errs` joins `reserved-member-3` with the loop variable.

   **The table's entries are ordered exactly as `machine-errors` declares them,
   and a site's table index is that declaration's position in that list.** The
   worked example — `(vector-ref errs 1)` at a `reject` error node — is the
   second of `http-version-machine.sls`'s two declarations, `(list eof-decl
   rej-decl)` (:55-57); `errcode` already walks `machine-errors` in this same
   order today to resolve a declaration name to its code
   (normal-ir.sls:144-147).
8. **`parser-error-state-id` is the single accessor excluded from cross-lane
   differential comparison, on §12.7:777's authority** — generated IDs "are
   deterministic for a given normalized graph, but an independently interpreted
   machine need not report the same ID. Differential tests do not compare that
   accessor across executor kinds." Both lanes must still *report* one; only the
   comparison omits it. The interpreter reports the node's declaration index —
   its position in `machine-nodes` (`ir.sls:374`) — the same mapping
   `lower-machine` builds as `name->id` (`private/normal-ir.sls:140-142`);
   §12.7:777 licenses the two lanes to differ here, so this is the
   interpreter's own deterministic choice, not a requirement that it match the
   generated lane's id. The exclusion is expressed once, in one shared
   projection over the §22.4:1271 five, and asserted **positively** — a check
   that fails if the exclusion is ever widened to drop a comparable member —
   because the differential's obvious repair for the red this record causes is
   to narrow the comparison back to the code symbol it compared before the
   family existed.
9. **The §17:963 debug map is normalizer output, total over internal prefix
   states, and cannot perturb the IR fingerprint.** It is what makes
   `parser-error-node-name` answerable in the generated lane, where the emitter
   needs the public name of each state as an emission-time literal. It is added
   as a member of the normal-machine vector (private/normal-ir.sls:28) and
   threaded out of `lower-machine` (:248) rather than reconstructed;
   milestone-3-design.md:1008-1009 already established the fingerprint argument
   — "`encode-normal` is called as `(encode-normal entry states)` and never sees
   names" — and that call is unchanged at private/normal-ir.sls:286.

   **A default-EOF error has no error node, so its `node-name` is the *dispatch*
   node's — the one whose EOF-target chain was exhausted, which is where
   truncation was detected.** The design fixes this: the default-EOF arm "takes
   the same shape with a literal `(quote eof)` and the *dispatch* node's name,
   which is where truncation was detected." §12.7:777 makes source-node name
   semantic and required to match between lanes, so this is not a debug nicety.
   The generated lane already has that node's public name in hand at emission
   time, the same way it has the node's other per-site literals. The interpreter
   does not: `default-eof-value` (interpret.sls:108-109) takes no argument and
   has no node in hand, so it must gain one — the enclosing `(dispatch)` arm in
   `parser-finish-op!` (runtime.sls:303-310) already holds the exhausted
   dispatch node as `node` and can thread it through the `default-eof-value`
   message.

   **What `node` holds there is not always the public name itself.** For a
   lowered sequence prefix state, `node` is the compound pair `(node-name .
   consumed-bytes)` built at `interpret.sls:79`, not a bare symbol — the same
   representation `eof-target-of` already unwraps as `(if (pair? cur) (car cur)
   cur)` (interpret.sls:112-113). This is the common case, not the exception:
   states 4-10 of `generated-http-version.golden.sls` are internal prefix
   states, so seven of the eight default-EOF sites Decision item 7 already
   counts (:10, :22, :31, :40, :49, :58, :67, :76) sit on them.
   `default-eof-value` must unwrap `node` the same way before it becomes
   `parser-error-node-name`'s value — `(if (pair? node) (car node) node)` — so
   both lanes report the enclosing declared node's public name, never the raw
   pair.

## Consequences

- **Milestone 4 can assert §22.4:1271 in the terms §22.4 states it.** Error
  domain, code, public source-node name, absolute position and position kind
  become five comparable values across interpreter and generated execution where
  there was one symbol, so exit criterion §25:1570's error clause is discharged
  against node kinds already shipped, before Milestone 4's first field exists.
  Slices ② and ③ inherit decision 5's zero-width rule and add one populated row
  each rather than re-deriving a convention.
- **Two enumerated values ship with no producer until Milestone 5, and that is
  not a half-populated family.** `domain` = `callback` and a non-`#f` `detail`
  have exactly one producer in the plan — §13:808's "explicit callback failure
  containing an application code and optional detail", with §13:824 fixing that
  "no error is installed until a callback returns failure" — and callbacks are
  Milestone 5 (§25:1572). What milestone-2-design.md:343-344 forbids is
  populating one *field* of a deferred *family*; every one of §9.3:397-405's
  accessors ships here, and an enumerated field whose second value has no
  producer yet is the ordinary condition of a closed enumeration mid-plan.
- **The encoding is obliged to carry the error declaration's `reason`, and that
  obligation is decision 0019's, not re-decided here.** Normalization discards
  it today: the `errcode` helper resolves a declaration name to
  `error-declaration-code` and nothing else (private/normal-ir.sls:144-147),
  even though `error-declaration-reason` has existed since Milestone 1
  (private/ir.sls:288). Because the record now reports the reason, two machines
  differing only in a reason are observably different machines, and decision
  0009 point 2 makes the IR fingerprint the object §20:1043 embeds and the
  determinism checks compare — so a reason outside the canonical encoding would
  leave the fingerprint no longer identifying what was emitted.
- **This record is what makes §16.2:886's unchecked `reason` clause live.**
  Carrying the reason into the record means an author-supplied string is written
  into generated Scheme source for the first time; `pass-names-valid` checks
  machine, node, error-declaration names and codes and no reason at all
  (verify.sls:461-477), and §10.1:480 restricts embedded reasons to printable
  ASCII plus LF. The gap was inert only because the emitter had never written a
  user-controlled string. Closing it, and the matching writer-side escaping
  §20:1039 requires, is an obligation of the slice that lands this record, not
  of a later one.
- **It deliberately touches nothing else.** `parser-result` keeps its five slots
  and its accessors (runtime.sls:88-95) — the error member's *type* changes, not
  the result's shape. `graph.sls` takes no edit: §9.3 is a runtime surface, and
  §9.1 fixes the construction surface. The §16.4 diagnostic record is not
  widened; that is Milestone 7 (§25:1616), and §16.4:945 keeps diagnostics
  compared by structure and code rather than rendered text either way.
  `parser-field-ref` and the callback-visible half of §25:1564 are untouched:
  they are Milestone 4's later slices and Milestone 5's caller. And nothing here
  upgrades §9.4:438's ABI-mismatch condition, which decision 0010 item 5 still
  leaves as an `assertion-violation`.

---

## 2026-09-02 (Milestone 4) — item 7 amended: the table is per *reached* declaration

Raised by Slice ①a's whole-branch review as an open question, and **resolved
before Slice ①b** — deliberately, on timing: the fix moves a committed golden,
and from Slice ①a's merge [0019](./0019-encoding-format-2-pre-provisioned.md)
point 5 tells a later slice to treat a moving golden as a STOP condition. Cheap
now, expensive after ①b.

**Item 7 is amended to read: one entry per error declaration the graph
REACHES.** Everything else in item 7 stands — the table is still per
declaration rather than per site, still ordered as `machine-errors` declares
them, and a site's index is still that declaration's position in the *emitted*
table.

### What was measured

`encode-normal` writes a declaration's static reason at exactly two sites — an
error state's, and a dispatch state's `(default . code)` eof routing — so a
declaration that no error node names and that is not the machine's default-eof
error never reaches the encoding, and therefore never reaches the IR
fingerprint. The emitted `errs` table, built per item 7 from
`machine-errors` in full, carries it anyway.

Two machines differing only in such a declaration's reason therefore hash the
same and emit different bytes:

```
(same-fingerprint    #t)
(same-emitted-bytes  #f)
```

### Why it matters

It contradicts [decision 0019](./0019-encoding-format-2-pre-provisioned.md)
item 2's own argument, in that record's words: "two machines differing only in a
reason must differ in fingerprint, or the fingerprint stops identifying what was
emitted." §20:1043 makes the fingerprint the object the determinism checks
compare, so a fingerprint that does not distinguish two different emitted
libraries is weaker than both records assume.

**Bounded, and not urgent.** The determinism property §20:1031 actually states —
same verified machine, options, binding and generator version produce
byte-identical source — is unaffected; two machines differing in a declaration
are different machines. Nothing in the tree can reach it: every fixture uses
declarations that are all reached, and `machine-gen.sls` fixes two declarations
with distinct codes, so the property lane cannot generate one either. What is
lost is the stronger claim both records lean on — that the fingerprint
identifies the emitted output.

### What was taken, and what was not

**Taken: narrow the table to reached declarations.** Emitter-only. `errs` is
built from the declarations the normalized states actually resolve, in
declaration order. Measured: `same-fingerprint` and `same-emitted-bytes` now
agree, and **no IR fingerprint moves**, because the encoding is untouched. One
golden moves — `test/fixtures/generated-pause.golden.sls` loses a row, its
`default-eof` declaration being genuinely unreached, since every dispatch state
there routes EOF to a node.

**Rejected: widen the encoding to every declaration.** It keeps item 7's
original wording and makes the fingerprint cover the whole table, but it
re-baselines all four IR fingerprints and all three goldens a *second* time —
the double payment the ①a/①b split exists to avoid — and after ①a's merge it
collides with 0019 point 5 outright.

**Rejected: narrow the claims instead and ship no code.** Available, and the
cheapest by a wide margin, but the claim it would narrow is load-bearing for
§20:1043: the fingerprint is what the determinism checks compare, and a
fingerprint that does not distinguish two different emitted libraries is worth
less than both records assume. Declining to fix a real inconsistency because
nothing currently reaches it is how a guard that does not guard ships.

### What now holds, and what witnesses it

`determinism-one-byte-tests.sps` asserts the converse property directly — two
machines whose fingerprints agree emit identical bytes — with the *premise*
asserted alongside it, so the implication cannot pass vacuously if the
fingerprints ever stop agreeing. A mutation restoring the unfiltered table is
caught by that case.

One consequence for a later slice: **the duplicate-code fixture must have BOTH
same-code declarations reached.** Naming only one lets this filter drop the
other, leaving the lookup a single candidate — at which point resolving by code
and resolving by (code, reason) agree and the duplicate-code mutation goes
UNCAUGHT. Measured while landing this change.

### Where the evidence is

Slice ①a's plan
([milestone-4-slice-1a-implementation-plan.md](../.plans/milestone-4-slice-1a-implementation-plan.md)),
under the whole-branch review section, carries the original reproduction.

## 2026-09-11 (Milestone 7 Slice ②) — item 7's open shape is now drawn on purpose

Item 7's amendment notes that an error declaration present in the source `errs`
table but **absent from the encoding's reached-declaration table** is a shape the
tree carried but no fixture exercised. Milestone 7 Slice ②'s generator can draw it
on purpose: its free/structural draw supplies orphan and dangling error
declarations (`unreferenced-error-declaration` and the dangling-target codes) as
rejection material, under the generator's `orphan-prob` / `dangling-prob` steering.
The property lane of Slice ② does **not** exercise this: it runs `property-steering`,
whose `orphan-prob` and `dangling-prob` are **0**, and it counts rejections as a
bare total, not by code — the by-code rejection ledger (`make-rejection*`,
`rejection-codes`) is exported from the driver but **not called in this slice**.
Both are turned on by **Slice ④**, whose corruption catalogue and independent
oracle drive `free-steering` (`§4.6`) and consume the ledger. Recorded here so the
next reader of 0022 finds where the shape is produced and where it is consumed,
rather than re-deriving the shipped generator's avoidance of it.
