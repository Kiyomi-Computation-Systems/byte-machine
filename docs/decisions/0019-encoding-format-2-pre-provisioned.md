# 0019: Normalized encoding format 2, with three slots reserved empty

Date: 2026-08-31
Status: accepted
Milestone: 4, Gate 0 (milestone-4-design.md §4.2)

## Context

Measured against the shipped tree at commit `a942327`, the commit Milestone 3
closed at. Seven commits sit between `a942327` and this record and none
touches `src/`. One of them, `1dcb804`, edits
`docs/plans/byte-machine-implementation-plan.md` — the file this record cites
by line throughout — but only as a single line substituted for another, at
§9.5:442 (`git show 1dcb804 --stat` shows `2 +-`, one insertion for one
deletion); no downstream line moves, verified by re-checking the cited
§10.1:480, §16.2:884 and §20:1043 lines against the current tree below. The
same commit also appends dated amendment notes to decisions 0010 and 0012,
and the other six add `docs/plans/milestone-4-design.md`, the Gate 0
implementation plan and decision 0018 — none of which this record cites by
line — so every `src/` line cited below is still the line Slice ①a will
open.

**What `encode-normal` encodes, and what it cannot see.** It takes two
parameters — `(define (encode-normal entry states)`, normal-ir.sls:251 — and has
exactly one caller, `(fnv1a-64 (encode-normal entry states))` at
normal-ir.sls:286. It never receives the machine. That is a *structural* claim,
not a policy one: field declarations, field initial values and the machine name
are invisible to the IR fingerprint by construction, not by omission.
milestone-3-design.md:1008-1009 relied on the same fact for the debug map. What
it does write is a version byte of 1 (:254), the entry id, the state count, and
then one tagged record per state — dispatch 0 (:262), stop 1 (:275), error 2
(:276), finish 3 (:277), pause 4 (:279).

**The error declaration's `reason` is discarded at normalization.** The helper
that resolves an error reference is `errcode` (normal-ir.sls:144-147); it walks
`machine-errors` for a matching `error-declaration-name` and returns
`error-declaration-code` and nothing else. Both encode arms that emit an error
therefore emit a code symbol only: the error arm at :276 and the dispatch
default-eof arm at :274. The accessor `error-declaration-reason` exists
(ir.sls:288), is not among `graph.sls`'s exports (graph.sls:12-25), and `rg`
finds no reader for it anywhere in `src/` or `test/`. §10.5:527 makes a "static
printable-ASCII reason" part of every error declaration, and §10.1:480 fixes its
repertoire. Today the value is validated at construction, stored, and dropped.

**The fingerprint is computed over the encoding, not over the emitted text.**
This is the distinction the whole record turns on. `normalize-machine` hashes
`(encode-normal entry states)` and stores the result in slot 3 of the
normal-machine vector (normal-ir.sls:286; accessor at :32). The emitter *reads*
that number — `(fp (normal-machine-fingerprint normal))`, compile.sls:149 — and
splices it into the rendered constructor call at compile.sls:164. Emitted text
is strictly downstream of the fingerprint and never upstream of it. So the two
changes have different blast radii: **an `encode-normal` change moves the
fingerprints and, through :164, the goldens; an emitted-template change moves
the goldens only.** Goldens are compared as raw bytes
(determinism-one-byte-tests.sps:41-42 and its two siblings), and
compile-tests.sps:165 additionally pins the whole constructor call as a
substring.

**The `exec` measurement.** The emitted signature is fixed at six parameters in
one template string — `"  (define (exec state offset bv start end finish?)\n"`,
compile.sls:156 — and a generated `exec` is called with six arguments at exactly
two sites, `runtime.sls:218` (feed, `#f`) and `runtime.sls:262` (finish, `#t`).
Those are the only two: `runtime.sls:207` is the `/v1` five-argument `feed`
call, inside the different closure defined at `:205`. All three committed
goldens carry that six-parameter line verbatim at line 4. A field-store
parameter added in Slice ② would therefore change the emitted text of *every*
machine, including the zero-field ones, and all three goldens would move in ②
— falsifying the milestone's own oracle that ①b, ② and ③ move no existing
golden (milestone-4-design.md:2272) one to two slices after this record is
made.

**The version byte has never distinguished anything.** It has read 1 through
every encoding change so far: Milestone 2 appended eof routing to the dispatch
record and added the `finish` and `pause` tags — decision 0011's Consequences,
which re-baselined the fingerprints without touching the byte — and Milestone 3
deliberately did not change the encoding at all (decision 0014's Consequences:
"every machine expressible before Milestone 3 encodes identically after it";
decision 0015 point 1: "the encoding-format version byte is unchanged", restated
in the code at compile.sls:104). One value has named at least three encodings.
Note also that no record owns that byte: normal-ir.sls:250 credits the layout to
"decision 0009 layout", but decision 0009 contains no occurrence of "layout",
"format", "version" or "encoding".

## Decision

1. **The canonical encoding's format version byte goes 1 → 2 in Slice ①a**, at
   `normal-ir.sls:254`, and this record is its owner from that commit forward.
   The bump is not what forces the re-baseline — encoding the `reason` does that
   — which is exactly why it is taken here: the byte write itself is nearly
   free in ①a and free in no other slice; slot (c) below is not (Consequences).
   From ①a the byte names one encoding rather than three.

2. **The same bump introduces the error declaration's static `reason` into the
   encoding**, appended after the code at both sites that emit one: the error
   arm (`normal-ir.sls:276`) and the dispatch default-eof arm (`:274`). It must
   enter the *encoding*, not merely be read from the source machine. Decision
   0009 point 2 computes the IR fingerprint over the canonical normalized IR and
   §20:1043 makes it "embedded deterministic non-cryptographic IR fingerprint
   … of canonical normalized IR and emission options" — the object the
   determinism checks compare. Two machines differing only in a reason must
   therefore differ in fingerprint, or the fingerprint stops identifying what
   was emitted.

3. **The same bump reserves three slots, each written with an empty value and
   read by nothing.**
   (a) *The encoding's field table* — a `u16be` count of zero with no per-field
   records, in `encode-normal`. Filled in ①b.
   (b) *The ABI payload's field-initials member* — member 0 of the single quoted
   metadata vector the unversioned constructor takes (§4.1), rendering as
   `(quote #())`. Filled in ①b.
   (c) *Emitted `exec`'s seventh parameter* — the template at `compile.sls:156`
   goes from six parameters to seven, both call sites (`runtime.sls:218`,
   `:262`) pass an empty vector, and the new parameter's name joins
   `reserved-member-3` (`compile.sls:53`, today twelve symbols carrying the
   other six) in the same commit. Filled in ②.
   Slot (c) is the one a reader will miss, because it is not in the encoding at
   all; it is reserved here for the same reason and by the same argument. Its
   own two-site breakage is Consequences' second bullet, not this inventory.

4. **This is a format decision, not a transformation, so §17:966 does not reach
   it.** That line reads: "Normalization must not perform speculative
   performance transformations in v0.1. It should produce the simplest correct
   execution graph." A count of zero changes no lowering, allocates no state and
   yields no different execution graph; it is a byte in the serialization of a
   graph that is unchanged. The §17 responsibility the reservation serves is
   :962, "assign field, callback, and span slots" — this holds the slot's place
   one slice before the assignment exists.

5. **A later slice that finds an existing golden or an existing fingerprint
   moving has broken this reservation and must STOP, not re-baseline.** From
   ①a's merge, the three committed goldens under `test/fixtures/` are
   byte-identical for the rest of Milestone 4, and the four IR fingerprint
   values ①a measures are the values ①b, ② and ③ ship. A movement is evidence
   that a slot was added late, not evidence that a number needs updating; the
   repair is the slot, not the baseline. Re-baselining instead silently converts
   this record's guarantee into a second unbudgeted re-measurement, which is the
   outcome the whole ①a/①b split exists to avoid.

## Consequences

- **The re-baseline this concentrates in ①a, measured.** Four distinct IR
  fingerprint values are pinned at **nineteen sites across six files**, and none
  in `src/`: `4236938459847922092` (9 sites), `15725897457025557005` (5),
  `9098559711816935340` (3), `12299125921751534854` (2). By file — one per
  golden (`generated-one-byte.golden.sls:20`, `generated-pause.golden.sls:33`,
  `generated-http-version.golden.sls:85`), two in `compile-tests.sps` (`:165`,
  `:212`), three in `normal-ir-tests.sps` (`:73`, `:122`, `:147`), and eleven in
  `test/support/cmake/SchemeMutationSuite.cmake`. **Seven of those eleven are
  mutation pins carrying a measured `got` digest** — `:4773`, `:4780`, `:4787`,
  `:4889`, `:4907`, `:4958`, `:4980` — and `SchemeMutationSuite.cmake:843-852`
  states why they are different in kind: "an expected golden is RECOMPUTED by
  re-running the lane, but a 'got' digest can only be RE-MEASURED, by applying
  that one mutation to a staged copy and reading what it printed." Each must be
  re-measured by staging the mutation, never recomputed. The remaining four
  cmake sites are narrative (`:4942`, `:4943`, `:4951`, `:6548`), and Pass 49's
  narrative additionally records the mutant library's own byte count (`:6544`,
  `:6580`) alongside its digest — both measurements of a golden this slice
  moves. That doctrine block is itself pre-Milestone-3 and says "five" and
  "~15"; the measured counts today are seven and nineteen, so it is re-measured
  in the same slice rather than cited as current.

- **Slot (c) also breaks two sites outside that fingerprint inventory, because
  they match text and arity, not a value.** Widening `runtime.sls:218` and
  `:262` to seven arguments leaves
  `test/support/cmake/SchemeMutationSuite.cmake:2714`'s `FIND` — verbatim
  `runtime.sls:262`'s six-argument line — unmatchable, and `SITES` is asserted
  exactly (`MutationRunner.cmake:59`), so this fails the mutation's own
  declaration rather than being silently skipped; the repair is to re-anchor
  that `FIND` on the new seven-argument text, not to delete the pin
  (`MutationRunner.cmake:344-346`). It also leaves
  `test/common/runtime-tests.sps:276`'s
  `(define (stub-exec state offset bv start end finish?)` — a hand-written
  six-parameter exec driven through both widened call sites, the feed at `:296`
  and the finish at `:300`, via `v2-machine` at `:289` — one parameter short, so
  the runtime unit lane dies on arity unless it gains the seventh in the same
  commit.

- **What it removes from ①b, ② and ③.** ①b fills a count that is already zero
  and a payload member that is already `(quote #())`, so a machine declaring no
  fields encodes *and renders* byte-identically. ② adds its field store to a
  parameter that already exists in the emitted text. ③ adds a node kind, which
  moves nothing existing because no shipped fixture uses one. Each of the three
  therefore gets "no existing golden and no existing fingerprint moved" as a
  gate assertable by `git diff` against ①a's merge — a falsifiable oracle they
  would otherwise not have, and the only thing that pays back ①a's bill.

- **Decision 0009 is extended by the field table, not falsified, and takes no
  dated amendment.** 0009 fixes the IR fingerprint's *input* ("computed over the
  canonical normalized IR"), its *embedding*, and its *role* in the D6
  determinism checks. It fixes no layout, no member list and no version — the
  words "layout", "format", "version" and "encoding" do not occur in its text.
  Adding a field table and a reason changes what the canonical normalized IR
  *contains*, which is precisely the freedom 0009 left open, so no sentence of
  it becomes false and it gets no amendment note; the tree it was decided
  against remains its evidence. The question arises only because
  `normal-ir.sls:250` credits the byte layout to "decision 0009 layout", an
  attribution 0009 does not support — that comment is corrected in ①a to point
  here. Contrast decision 0012 item 1, which names the `/vN` binding in its own
  decision text and therefore *does* take a dated amendment under §4.1: a record
  needs amending when its own words go false, not when a later record builds on
  it.

- **The format version byte acquires its first mutation pin here, and the naive
  anchor will fail.** `rg` finds no pin on `normal-ir.sls:254`; the only
  `put-u8 p 1` FIND in the suite is the default-eof arm's longer literal at
  `:4887`. The literal `(put-u8 p 1)` occurs three times in `encode-normal`
  (`:254`, `:274`, `:275`), and after the bump `(put-u8 p 2)` occurs **twice**
  (`:254` and the error arm at `:276`) — so the collision moves rather than
  disappears, and `SITES` is asserted exactly (`MutationRunner.cmake:59`). Any
  pin on the new byte must anchor on surrounding text.

- **What this deliberately does not touch.** No verifier pass: the encoding
  format version is *not* §16.2:884's "unsupported IR versions", which is
  `machine-ir-version` (ir.sls:351, stamped with no accessor) against a
  `pass-schema` that is still a bare `machine?` tag test (verify.sls:107-108);
  closing that is Slice ①b's. No `graph.sls` or `ir.sls` change: `make-machine`
  has taken a `fields` argument (ir.sls:352) and `machine-fields` has been
  exported (ir.sls:10; defined at :370) since M1 with no reader anywhere in
  `src/` or `test/`, and this reservation mirrors that shipped precedent one
  layer down. And this
  record settles only that the `reason` is *encoded* — its portability check in
  `pass-names-valid` and the writer's escaping of `"`, `\` and LF are Slice ①a's
  own tasks under §10.1:480 and §20:1039, not consequences of the format.
