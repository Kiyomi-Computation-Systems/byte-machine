# 0025: The Milestone 5 seam, paid once — trailing slot tables, ABI 4, and `exec`'s two new parameters

Date: 2026-09-04
Status: accepted
Milestone: 5, Gate 0 (milestone-5-design.md §4.3, §4.8)

> **Amendments** — later notes at the foot of this file reach back into the text
> above them. Nothing above a note is rewritten.
>
> - **2026-09-04 (Milestone 5, Slice ①a planning)** — **amends point 4**: its
>   handoff says the position-axis drift row derives `position-table`'s names
>   "from the IR". Measured while writing the Slice ①a plan: there is nothing in
>   `ir.sls` to derive them from.
> - **2026-09-04 (Milestone 5, Slice ①a execution)** — **amends point 4**: its
>   allocation of point 1's encoding shape to Slice ①a. There is no artifact move
>   to pay, so the seam argument does not reach it; ①b lands the section with the
>   data. Point 1's shape is unchanged and is recorded in `normal-ir.sls`.

## Context

Measured against the branch head `cc66302` — Milestone 4 closed, plus Milestone
5's two hardening slices ⓪ and ⓪b. Every `src/` and `test/` line cited below was
read on 2026-09-04 and is the line Slice ①a will open; Gate 0 itself changes no
`.sls`, no `.sps`, no CMake and no test.

**The gap this closes.** `§17:962` — "assign field, callback, and span slots" —
puts callback and span slot *assignment* in normalization. No sentence anywhere
says which normalization outputs the canonical *encoding* must cover. `§20:1043`
names the fingerprint's input as "canonical normalized IR and emission options"
and `§20:1046` computes it "over the canonical encoding"; neither fixes a layout,
a member list or a version. The field table's presence in the encoding was fixed
by [decision 0019](./0019-encoding-format-2-pre-provisioned.md), not by the plan
— so Milestone 5 arrives at the same question with no sentence to answer it.

**The header, measured** (`src/byte-machine/private/normal-ir.sls:465-467`):

```
;;   [version u8][entry u32be][state-count u32be][field-count u16be]
;;   [field records...][state records...]
```

**Decision 0019's three reserved slots are all spent, and Milestone 4 spent
them.** Measured against both the code and the in-tree comment that names each
slot's filler:

- (a) *the encoding's field table* — `encode-normal` now takes a `fields`
  parameter (`normal-ir.sls:462`), and `:474` records "①a wrote this count as a
  literal zero with no records, and Slice ①b fills it";
- (b) *the ABI payload's field-initials member* — `compile.sls:504` reads
  "Decision 0019 item 3(b)'s member 0, filled by Slice ①b", and
  `test/fixtures/generated-accumulate.golden.sls:36` renders
  `(quote #(#((value . 0))))`;
- (c) *emitted `exec`'s seventh parameter* — `compile.sls:63-64` reads "`fieldv`
  is emitted `exec`'s seventh parameter, reserved empty here and filled in Slice
  ② (decision 0019 item 3(c))", and the template at `compile.sls:532` is
  `(define (exec state offset bv start end finish? fieldv)`.

**Only (a) was ever in the header**, and this is worth stating because item 3
reads as one inventory of three like things. (a) is the `u16be` field count in
the layout above. (b) is a member of the ABI payload the emitter renders and (c)
is a parameter of the emitted `exec`; **neither is in the encoding at all**, so
neither is fingerprint-visible.

So **Milestone 5 draws on no reserve.** It reserves again, on 0019's precedent,
and pays its own bill. A reader who arrives at 0019 item 3 expecting an unspent
slot for callbacks will not find one; 0019 is annotated at item 3 for that
reason (Consequences).

**What already exists, and what is only missing.** `make-machine` has taken
`callbacks` and `spans` arguments since the IR was written
(`private/ir.sls:543`), stores them (`:561`), and exports accessors for both
(`:11`, defined at `:572` and `:573`) — and **nothing reads either accessor
anywhere in `src/` or `test/`** (measured two ways, `rg` and `grep -rn`, on
2026-09-04). No shipped fixture under `test/fixtures/` mentions a span or a
callback at all. So the declaration lists exist and the *encoding* of them is
what is absent — the same shape 0019's Consequences records for `machine-fields`,
exported since M1 with no reader until ①b filled it.

**The ABI, measured.** `current-abi-version` is 3 (`runtime.sls:61`). The
constructor's first guard is `(= abi-version current-abi-version)`
(`runtime.sls:79`) — strict equality. Five lines below it,
`(>= (vector-length metadata) 1)` (`runtime.sls:84`) is a *minimum length* check
on the metadata vector. The constructor's own comment states the coupling
(`runtime.sls:63-71`): the payload is one quoted vector rather than a rest-arg
precisely so that "the vector keeps growth and the check coupled."

**`exec`, measured.** Seven parameters in one template string
(`compile.sls:532`): no parser handle and no callback table. It is the generated
lane's only entry point — the runtime calls it at exactly two sites,
`runtime.sls:381` (feed, `#f`) and `runtime.sls:428` (finish, `#t`).

**The artifacts a seam change moves, measured.** Four committed goldens under
`test/fixtures/`. Each carries the `exec` signature at `:5` and the constructor
call as its **last** line — `generated-one-byte.golden.sls:21`,
`generated-pause.golden.sls:34`, `generated-accumulate.golden.sls:36`,
`generated-http-version.golden.sls:86` — and each of those last lines carries a
literal ABI `3` *and* that machine's IR fingerprint. The four fingerprint values
are pinned at **21 sites across seven files, all in `test/` and none in `src/`**:
the four goldens (one each), `test/common/normal-ir-tests.sps` (4),
`test/common/compile-tests.sps` (2), and
`test/support/cmake/SchemeMutationSuite.cmake` (11).

## Decision

1. **The callback and span slot tables encode as an optional trailing section,
   present only when nonempty. The header does not grow.** It stays
   `[version u8][entry u32be][state-count u32be][field-count u16be]`. A machine
   that declares neither a callback nor a span therefore **encodes
   byte-identically to today**, and its IR fingerprint does not move. Growing the
   header instead would move **every** fingerprint — the four header writes at
   `normal-ir.sls:482-485` are unguarded, so every machine gets them — and with
   it all four goldens and the literal pinned at
   `test/common/normal-ir-tests.sps:96-99`, a re-baseline paid by machines the
   feature does not touch. Decision 0019 struck exactly that bargain once, for
   the field table: its item 3(a) reserved the count, and its item 5 turned the
   resulting byte-identity into a STOP condition for every later slice —
   `test/common/normal-ir-tests.sps:223-226` is the test that holds it, "filling
   the reservation does not move a zero-field fingerprint", checking
   `(normalize (one-byte/fields '()))` against `14095574568398596535`; the
   comment at `:206-207` in the same block names what it is for, "Decision 0019
   item 5, asserted rather than assumed: ①a reserved the count slot so that a
   zero-field machine encodes IDENTICALLY once ①b fills it." Restating that
   bargain for the slot tables is consistent, not novel.

2. **`current-abi-version` goes 3→4 in Slice ①a, and the ABI payload gains a
   second member, empty.** `§9.5:444` is what forces the bump: "It may change
   before `1.0.0` only with a generated-ABI version bump, deterministic
   regeneration, and a changelog entry." The strict equality at `runtime.sls:79`
   is what enforces it.

   **The `>= 1` at `runtime.sls:84` is the metadata *length* check and enforces
   nothing about the version.** It is a minimum, so a two-member payload
   satisfies it unchanged — that is the freedom the quoted vector was chosen for,
   not a hole. This is stated here because a claim made during the design's own
   research — that "`runtime.sls:84-88`'s `>= 1` check will not enforce the bump,
   so the slice owes a test that it did" — conflated the two guards, and a record
   that repeats the conflation re-creates the false work order it would have
   produced. Slice ①a still owes coverage that a version-3 generated file is
   refused by a version-4 runtime; it owes it as **coverage of a working guard**,
   not as the closing of a hole.

3. **Emitted `exec` gains the parser handle and the callback slot vector,
   reserved and unused, in the same slice.** `§13:784` is the callback signature
   — `(callback parser user-context)` — so a callback invoked from generated
   execution needs a parser to receive, and generated execution happens inside
   `exec` (`runtime.sls:381` and `:428` are its only callers). Today it receives
   none. Both new identifiers join `reserved-member-3` (`compile.sls:68-70`) in
   the same commit, exactly as `fieldv` did.

   **This is 0019 item 3(c)'s *precedent*, not 0019 item 3(c)'s *slot*** — that
   slot is spent (Context). What transfers is the shape of the bargain: a
   parameter added *later* changes the emitted text of every machine, including
   the ones the feature does not touch, so the widening is paid once, before any
   callback arm exists to need it.

4. **All of this lands in Slice ①a, before any semantics.** ①a makes points 1-3
   real and adds no semantics. It carries one further task this record does not
   settle: the position-axis drift row of milestone-5-design.md §5:641-646 (the "Add a position-axis drift row" bullet), which
   derives `position-table`'s names from the IR rather than hand-writing them.
   Every later Milestone 5 slice then gets "no fingerprint moved" as a **gate**
   rather than a hope, and a golden that moves in a later slice is evidence that a
   slot was added late — decision 0019 item 5's discipline, restated for this
   milestone. (0019 item 5's own guarantee was scoped "for the rest of Milestone
   4" and is spent with that milestone; this point is the Milestone 5 instance of
   the same discipline, not an extension of 0019's.)

## Consequences

**The oracle is two-sided, and the two sides fail for different reasons.**

*Forward — the four goldens **do** move.* They are emitted **text**, and point
1's "encodes byte-identically" is a claim about the *encoding*, not about the
rendered library, so it does not spare them. An earlier draft of the design
asserted that an empty `git diff -- test/fixtures/` was the assertion, and that
was wrong on exactly this point; the correction is carried here so a slice does
not re-derive the wrong oracle. Measured, the move is **two lines per file, four
files, and nothing else**: the `exec` signature at `:5` widens, and the last line
changes twice over — the literal `3` becomes `4`, and the metadata vector gains
its second member.

*Backward — every fingerprint is unchanged*, and this is the sharper half. Note
what that means at the site: the goldens' last line carries the fingerprint too,
so that line changes for two reasons and must **not** change for a third. The
forward assertion is satisfiable by re-baselining, which is precisely what a
wrong encoding change would do to it. The backward one is not: it is a positive
claim about four values pinned at 21 sites across seven files (Context), and
`test/common/normal-ir-tests.sps:96-99` pins one of them as a bare literal on a
line this slice must not touch at all. **A fingerprint that moves in ①a means the
encoding changed when point 1 said it would not.** That is an assertion that can
actually fail.

**Point 1's rejected alternative — not encoding the tables at all — is refused on
precedent, and the precedent is narrower than it first looks.**
`test/common/normal-ir-tests.sps:173` is the case "two machines differing only in
a field NAME differ in fingerprint". It is about a *field*, not about a
declaration table and not about callbacks, so **it does not by itself forbid**
leaving callback slots out of the encoding. What it establishes is that in this
system **declaration identity is fingerprint-visible** — and a design in which
two machines differing only in their callback bindings share a fingerprint would
break that consistency for the one declaration family whose identity reaches
*outside* the machine. **That is an argument from precedent, not a proof, and it
is recorded as one.**

**What this hands the slices, and what it removes from them.**

- **Slice ①a** gets its *seam* work list from points 1-3 and the two-sided oracle
  above; milestone-5-design.md §5:641-646 (the "Add a position-axis drift row" bullet)'s position-axis drift row is the
  slice's one other task and is outside this record. It re-baselines the goldens
  exactly once, before any behaviour exists to argue about, and it owns no
  semantics: the slot tables it encodes are empty in every shipped fixture, the
  ABI member is empty, and both new `exec` parameters are unused.
- **Slice ①b lands on ABI 4 rather than bumping it again.** Point 2 pays the
  version bump once, in ①a, so ①b's callback-slot and accessor work —
  [decision 0028](./0028-callback-slots-and-visible-state.md) — arrives *after*
  the seam rather than alongside it. What this record guarantees ①b is narrow and
  checkable: the payload's second member and the version that admits it are
  already there. Whether ①b needs that member for anything is ①b's question, not
  this record's.
- **[Decision 0026](./0026-internal-state-id-order.md) is the other
  fingerprint-visible half of Milestone 5** and is deliberately not settled here:
  this record fixes *what the encoding covers*, 0026 fixes *the order the state
  records are written in*. Both are observable through the same number, so a
  slice that changes either without the other's licence trips the same gate.

**Decision 0019 is annotated, not amended, and the annotation is at item 3.**
Nothing 0019 says becomes false — its item 3 named where each of its three slots
would be filled and all three were filled as named. What a reader arriving at
item 3 by citation cannot see is that the reserve is now empty, which is the one
fact this record needs from it. That is an **annotates**, and it carries a site
marker at item 3 as well as a dated note at the foot of that file.

## 2026-09-04 (Milestone 5, Slice ①a planning) — point 4's handoff names a derivation that does not exist

Point 4 hands Slice ①a "the position-axis drift row of milestone-5-design.md
§5", which at the time instructed an implementer to "derive the position names
from the IR the way `kind-predicates-in-source` derives the kinds".

**Measured at `79c18c7`, while writing the Slice ①a plan:**
`rg -n 'position' src/byte-machine/private/ir.sls` returns two comment lines about
the field schema. `ir.sls` carries no position vocabulary of any kind. The only
enumeration with the right cardinality lives in `verify.sls` — **the file the
census exists to test.**

That asymmetry is exactly what makes the *kind* row strong and it does not
transfer. The kind row derives its set from `ir.sls` and tests `verify.sls`: two
independent files, so a mutation to one is caught by the other. A position row
can only derive from `verify.sls` and therefore tests that file against itself.
And because the census reads the **staged** tree
(`SchemeMutationSuite.cmake:1150`, `set(ENV{BYTE_MACHINE_SOURCE_ROOT}
"${STAGE_DIR}/src")`), a mutation that removes a position removes it from both
the code and the derived set: the mutant is self-consistent and the row stays
green.

**Nothing above this note is rewritten, and point 4's allocation stands** — the
row is still Slice ①a's. What changes is what the row can be. The Slice ①a plan's
Task 5 resolves it: derive from `verify.sls`, and require the row's own comment to
state that it is structurally weaker than the kind row and why. It still catches
what nothing catches today — a hand-edit adding a position to the verifier without
adding a matrix cell, `position-table` (`kind-position-census-tests.sps:93`) being
hand-written data that no assertion reads.

The design's `§5` bullet, being an **instruction** rather than a record, was
corrected in place on the same date.

## 2026-09-04 (Milestone 5, Slice ①a execution) — point 1's shape is right; point 4 allocated it to the wrong slice

Point 4 says "①a makes points 1-3 real". Points 2 and 3 it did. **Point 1 it did
not, and should not have.**

**The seam argument is that a change moving a committed artifact is paid once,
before any semantics, so every later slice can assert "no golden moved" as a
gate. Measured while executing ①a: the trailing slot-table section moves no
artifact, ever.** A section that writes zero bytes for a machine declaring
neither a callback nor a span leaves the byte stream identical, and `fnv1a-64`
folds over exactly those bytes — so the fingerprint is the same whether the
section-writing code exists or not. Adding it in ①b costs precisely what adding
it in ①a costs: nothing.

**That is the whole difference between a trailing section and a header slot, and
it is why decision 0019 had to reserve and this one does not.** 0019 item 3(a)'s
field count sits *inside* the header, which every machine writes unconditionally,
so its position had to be claimed a slice ahead or every fingerprint would move
twice. Point 1 chose a trailing section precisely to avoid that, and then point 4
scheduled it as though it had not.

Landing it in ①a would have meant a guard over two always-empty lists — live code
no input can reach, in the milestone that opened with two hardening slices about
exactly that, and in the file `encode-normal` lives in.

**Nothing in point 1 changes.** The shape it fixes — an optional trailing
section, present only when nonempty, header unchanged, the count *inside* the
guard because an unconditional count is two bytes on every machine — is recorded
at the head of `encode-normal` (`src/byte-machine/private/normal-ir.sls`) so that
①b implements a written-down shape rather than re-deriving one. What moves is the
slice that owns the code.
