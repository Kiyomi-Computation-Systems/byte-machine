# Milestone 13 Design — A parser can start in a mode

**Status: Milestone 13 OPEN 2026-09-15 — design and Gate 0.** To be delivered as
this design plus Gate 0 = decision
[0047](../.decisions/0047-a-parser-can-start-in-a-mode.md) (the M8–M12 pattern:
the gate is folded into one decision, no separate gate-0 plan) plus two slices —
Slice ① (the mechanism end to end) and Slice ② (the v0.5.0 release and close).
The brief's acceptance is dispositioned in the Close section at close.

Written against **`18fcc8b`** (`main`; v0.4.0 released as `18fcc8b`, tag
`v0.4.0` — Milestone 12 Slice ② was the release commit). Every anchor below was
measured against that commit, in this checkout, on `tarm64osx` / Chez Scheme
10.4.1 — the one Tier 1 cell that exists locally (the release-ledger reality M9
recorded). Measurements are cited by construct and `file:line` at `18fcc8b`; a
slice that edits a file re-resolves its own citations as its last step before
commit (AGENTS.md, "A `file:line` into a document your own commit also edits
must be re-measured").

Authority, in order: the upstream brief
(`~/github/chez-httparse/.plans/2026-09-15-upstream-parser-mode-brief.md`, the
consumer's ask, recorded under its decision 0006 item 4) and the parent
[implementation plan](./byte-machine-implementation-plan.md) — `§9` (the public
API surface, `parser-field-ref` at `§9.3:410`), `§10` (the source IR — field
declarations), `§12` (lifecycle and `parser-reset!`), `§16.2` (the verifier's
rules), `§29:1767` (the admission
bar for new semantic behaviour) — then decision 0047, then `AGENTS.md`.

This is the **fourth** milestone opened from a consumer brief rather than the
parent plan (M10 empty-span was the first, M11 keyword-table the second, M12 the
pause reason the third). It is neither a `§25` milestone (M9 was the final
planned one, `§25:1651`) nor a `§29` deferred extension, so it is admitted under
`§29:1767`'s bar — interpreter semantics, verification rules, generated parity,
documentation, and tests before admission — as a minor release.

---

## 1. Summary

A field's initial value belongs to the **machine**, not to the parser.
`make-parser` fills every field from the declarations the compiled machine
carries (`runtime.sls:394`, `:402`, through `initial-values`, `:806`), and
`(byte-machine runtime)` exports `parser-field-ref` (`:1463`) with **no**
mutating sibling. So two parsers built from one machine cannot start in two
different states, and a grammar whose behaviour depends on a mode the EMBEDDER
chooses — request vs response, a lenient-flags bitset, a strict/lenient dialect —
has no way to be told the mode. The consumer works around this with nodes at the
machine's entry that WRITE the mode on the first feed: `chez-httparse` spends
**one required callback + three nodes** for the request/response `type` and
**eleven optional callbacks + twenty-two nodes** for the eleven-bit
`lenient_flags`, to encode two integers the embedder already knows (its decision
0017).

This milestone gives a parser a way to start somewhere other than the declared
initials — **without** a general field writer (which would let a caller corrupt
`content-length` mid-parse, brief §3) and **without** silently invalidating the
verifier's reasoning about a field's value at the entry state (brief §3, the
part this design found in the code). The mechanism is:

- a uint field may be declared **settable** — an optional `settable?` flag on
  `make-uint-field`, via `case-lambda`, so no existing machine changes;
- `make-parser` gains an optional **initial-values** argument: an alist
  `((field-name . value) …)` overriding the declared initials of settable fields
  only, range-checked to the field's declared width, refused for any unknown or
  non-settable name — it is a CONSTRUCTION argument, so it cannot apply mid-parse;
- `parser-reset!` restores the **embedder-given** initials, not the declared
  ones, so the chosen mode survives a reset by construction (brief §2);
- the verifier gains a rule closing the one entry-value soundness hole a settable
  initial opens (§3.2), with a new diagnostic;
- and the settable marking + the width the generated lane needs to range-check an
  override cross the ABI seam under a presence guard, so a machine with no
  settable field is byte-identical except the ABI literal. The generated ABI
  moves **7 → 8**.

Two slices:

- **Slice ① — the mechanism.** The `settable?` flag on `make-uint-field` and its
  accessor; the `make-parser` initial-values argument, its validation, and the
  reset-survival slot; the settable table across the normalizer, the fingerprint,
  the emitted payload, and both lanes; the ABI 7→8 bump; the verifier rule and its
  diagnostic; the differential / determinism / interpret lanes including a
  mode-started parser proved to agree across executors and to survive reset; the
  property driver; the re-authored and new mutations; the before/after node-count
  and size measurement. One atomic commit — the ABI bump, the payload growth, and
  the emitted decode cannot be split without a red intermediate (AGENTS.md, "A
  plan that schedules a red intermediate commit is the thing that is wrong").
- **Slice ② — the release and the close.** The version surface to `0.5.0`, the
  `CHANGELOG.md` section, the release ledger's version surface + hardcoded
  assertions, the annotated tag, and the five milestone-status surfaces.

## 2. Why this shape

Three brief traps (§3) force the shape:

1. **A general `parser-field-set!` is not a mode; it is corruption.** The
   runtime's own comment says the read-only-ness of `parser-field-ref` is a
   design decision, not an oversight (`runtime.sls:1489-1490`, "the declarations
   belong to the compiled machine and outlive every reset"). A general writer
   would let a caller change `content-length` between feeds mid-parse — which is
   not a mode (brief §3). So the embedder-chosen initial is supplied at
   CONSTRUCTION (an argument to `make-parser`), where it cannot apply mid-parse,
   and only to fields the machine has DECLARED settable.

2. **A reset that forgets the mode is the same bug as a wrong default, arriving
   later.** `parser-reset!` restores the DECLARED initials today
   (`runtime.sls:1510`, `(initial-values (parser-field-decls parser))`), so a
   naive initial-values argument would have the mode silently vanish on the first
   reset (brief §2). The consumer already engineered around exactly this: it
   keeps `lenient-flags` separate from its framing `flags` field precisely so the
   mode survives its inter-message restart (`grammar.sls:321-324`). So this design
   decides it deliberately: reset returns the parser to its JUST-CONSTRUCTED
   state, and a just-constructed parser holds the embedder's initials — the parser
   stores the merged initials and `parser-reset!` restores from THOSE (§3.4). The
   callback-chain workaround got reset-survival for free by re-asking; the
   replacement must be at least as hard to get wrong (brief §2), and storing the
   effective initials makes forgetting the mode impossible.

3. **A field with an embedder-chosen initial no longer has its declared initial
   bounding its value at entry, and a pass that reasons about that must know**
   (brief §3, last paragraph). This is not hypothetical: `verify.sls`'s
   `parked-eof-start` reasons that a counted-consume node reachable at the ENTRY
   state holds "the field's initial and may be zero, so it starts at itself"
   (`:1111-1113`), branching on the declared initial. If the embedder could set
   that counter positive, the static reasoning would be quietly wrong. So a
   settable field is MARKED (not any field silently overridable), the verifier is
   told which fields carry an embedder-chosen initial, and it refuses the one
   shape that would make its entry reasoning unsound (§3.2). A settable field is a
   mode/bitset selector — the consumer's `type` and `lenient-flags` are never
   consume counters — so the rule costs a real grammar nothing.

The mechanism a decision-callback branch key CANNOT provide, and this one can, is
an ARBITRARY integer: llhttp's `lenient_flags` is a 16-bit field an embedder sets
to any of 2048 subsets of eleven bits (brief §2). A branch key carries one of a
declared set; a subset needs the integer itself, which the initial-values
argument passes directly. This is decision 0017's priced-but-declined alternative
2 ("ask byte-machine for a field writer"), now general enough to admit.

## 3. What the tree already settles

Read-only survey against `18fcc8b`.

### 3.1 The field mechanism today, and where the initial rides

A uint field is `#(tag name width initial source-label)` (`make-uint-field`,
`private/ir.sls:928`): `width ∈ {8,16,32,64}` and `initial ∈ [0, 2^width − 1]`,
both checked at construction (`:930-938`). The compiled machine carries the
fields as a `(name . initial)` table both lanes reach by their own route — the
interpreter is asked (`interpret.sls:501-504`, the `'field-initials` message,
which has the full uint-fields via `machine-fields`), the generated lane reads
ABI payload member 0 (`compile.sls:734-740`, `"(" name " . " initial ")"` per
field — **name and initial only; the width is NOT in the payload**, it is
resolved at emit time by `field-slot-width`, `:182`).

`make-parser` (`runtime.sls:382`) builds the mutable field-values vector once,
`(initial-values decls)` (`:806`, copying `(cdr decl)` per field), in both the
`'op` arm (`:394`) and the `'v2` arm (`:402`). `parser-field-ref` (`:1463`) reads
a field by name→slot; there is no writer. `parser-reset!` (`:1492`) restores the
field-values from the DECLARED initials (`:1510`). The parser vector is 17 slots
(indices 0–16; the field-values are slot 8, the immutable decls slot 9).

So the brief's diagnosis is exact: the initial is machine-owned, one copy per
declaration, restored-to on reset, and there is no seam by which one parser can
start where another does not.

### 3.2 The verifier's one entry-value assumption — the soundness core

Most verifier passes reason about the field GRAPH (a field name resolves to a
declaration; an operand is in range for its width; a field-branch has both arms),
none of which a settable initial touches. **One** pass reasons about a field's
VALUE at the entry state. `parked-eof-start` (`verify.sls:1101-1116`) classifies
where the EOF walk starts for a parser parked on a node: a NON-entry
counted-consume node holds a positive count (the only returns that leave `current`
on it leave the field positive), so it takes its EOF route; but the ENTRY
counted-consume "falls through: a fresh parser is parked there without having
executed it, **its count is the field's initial and may be zero**, so it starts
at itself and takes `classify`'s join" (`:1111-1113`). That "may be zero" is a
claim about the DECLARED initial. If the embedder set that counter positive
through an initial-values argument, a fresh parser parked at the entry
counted-consume would take its EOF route, not the join — and the walk would start
in the wrong place, silently.

The rule (decision 0047 item 4): **a settable field may not be the counter of a
counted-consume node** — a new verifier diagnostic (`settable-consume-counter`,
or a clearer spelling the prototype settles), keyed on the field name, mirroring
the `pass-names` resolution arm's shape (`verify.sls:351-354`). This is broader
than "at entry" and deliberately so: a counter's whole meaning is a count that
starts at a known value and decreases, and an embedder-chosen start makes the
count analysis unsound wherever it is used, not only at entry. A settable field
is a mode/bitset selector, never a consume counter, so the rule refuses only
nonsense. Slice ① audits `verify.sls` for any other pass that branches on a
field's declared initial (this survey found only this one) and states the audit's
result at the pass.

### 3.3 The ABI seam — settable + width cross it, under a presence guard

The generated lane's `make-parser` must reject an override of a non-settable or
unknown field, and range-check a settable override to the field's width, EXACTLY
as the interpreter does — the two lanes must not diverge (the differential lanes
exist to prove they never do). The interpreter has the full uint-fields; the
generated lane has only `(name . initial)` (no width, no settable mark). So the
settable marking and the width the check needs must cross the ABI seam.

The seam moves under a **presence guard**, the decision-0019 / M11 / M12
discipline ("bytes only when the feature is present"):

- **Emitted payload.** The v8 metadata is the current three members
  `#(#(fields) #(cbs) #(snames))` when NO field is settable — byte-identical to v7
  except the ABI literal — and a four-member `#(#(fields) #(cbs) #(snames)
  #(settable-table))` when at least one field is settable, where the settable
  table carries `(slot width)` per settable field, everything the generated
  `make-parser` needs to validate and apply an override. The runtime's
  compiled-machine decoder length-guards the fourth member (absent ⇒ no field is
  settable ⇒ every override is refused). This mirrors decision 0046's refusal of a
  sixth feed-outcome slot: reuse/append rather than move every site.
- **Fingerprint.** `encode-normal` already encodes each field as
  `[name-length u16be][name UTF-8][width u8][initial u64be]`
  (`private/normal-ir.sls:732-735`, `:753-758`) — field names and initials are in
  the fingerprint on purpose ("a field name is observable to a generated parser
  through `parser-field-ref`, so two machines differing only in one must differ",
  `:83-85`; "integers ride 64 bits for the same reason field initials do",
  `:229`). The settable marking is a NEW datum the ABI carries, so it must enter
  the encoding too, else two machines differing only in one field's settability
  share a fingerprint but emit different bytes (the invariant
  `normal-ir-tests.sps` guards for field data). It rides as a trailing section
  encoded only when non-empty — the same "appended, present-guarded" pattern the
  fields, callbacks, and spans sections already use (`normal-ir.sls:100-105`) — so
  a machine with no settable field's fingerprint does not move.
- **ABI 7 → 8.** `current-abi-version` (`runtime.sls:96`) and the emitted literal
  (`compile.sls:800`, `(byte-machine-make-compiled-machine 7 …)`) move 7 → 8; the
  ABI lane reads it out of the emitted text (`compile-tests.sps`, the
  M12-established site). The bump is honest: the emitted payload CONTRACT gains a
  member, so a consumer decoding a v8 generated parser must know a settable field
  carries a table — exactly what the ABI number tracks (decision 0042's principle,
  M12's precedent). All seven determinism goldens re-baseline the ABI literal; a
  golden whose machine marks no field settable moves ONLY that literal, and the
  present-guarded sections mean even the field-bearing goldens
  (`generated-accumulate`, `generated-counted`) do not grow their field records —
  the exact set is confirmed at regeneration in Slice ①.

`parser-result` is not touched (this milestone adds no result slot); the
generated `exec` body is not touched (a settable initial changes make-parser, not
the per-byte loop). The emitted-text delta is the payload member alone.

### 3.4 Reset survival — the merged initials in a new parser slot

`make-parser` merges the initial-values argument over `(initial-values decls)`
once, at construction, into the mutable field-values (slot 8) AND stores the same
merged vector in a **new immutable parser slot 17** (the vector is 0–16 today,
§3.1). `parser-reset!` restores field-values from slot 17 rather than
recomputing `(initial-values decls)` (`:1510`), so a reset returns the parser to
its just-constructed state INCLUDING the embedder's mode (brief §2). With no
initial-values argument, slot 17 equals the declared initials and reset is
unchanged — the current behaviour is the no-override case, so every existing
reset lane holds. Appending slot 17 strands the pre-existing mutation pin whose
FIND is a make-parser vector-literal arm (the M10 lesson,
[[status-surfaces-drift-independently]] / the slot-16 append), re-anchored in
lockstep in Slice ①.

### 3.5 The consumer's before/after (brief §4)

Measured in `~/github/chez-httparse/src/httparse/grammar.sls` at the consumer's
current pin:

| mode surface | today (workaround) | with the primitive |
|---|---|---|
| `type` (u8, initial 0) | 1 **required** `on-message-type` decision callback + **3 nodes** (`switch-type`, `type-store-request`, `type-store-response`, `:1080-1087`) | `make-uint-field 'type 8 0 #t` |
| `lenient-flags` (u16 bitset, initial 0) | **11 optional** `on-lenient-*` decision callbacks + **22 entry nodes** (`lenient-ask-*` / `lenient-set-*`, `:365-400`) | `make-uint-field 'lenient-flags 16 0 #t` |
| embedder supplies | 12 callback bindings | one `make-parser` initial-values arg: `((type . 1) (lenient-flags . <bitset>))` |

**12 callback declarations + 25 entry nodes → 2 settable markers + 1
construction argument.** The bitset in one integer is the value a decision-callback
branch key provably cannot carry (2048 subsets). The ~216 strict fixtures keep
working untouched: the argument is optional, absent ⇒ declared initials ⇒ strict
(`grammar.sls:397` records the 216). Slice ① records the exact before/after node
count MEASURED, with the reproduce command, never a prototype number (AGENTS.md,
[[scratch-fixture-measurements]]).

### 3.6 The demonstration, the lanes, and the mutation surface

An in-repo demonstration machine with a settable field whose value forks
behaviour (a two-mode machine: a settable `mode` field, a field-branch that reads
it, two terminals) driven in BOTH lanes, proving (a) two parsers from one machine
started with different initials diverge as their mode dictates, interpreter ≡
generated; (b) a reset restores the embedder's initial, not the declared one
(feed → mode observed → reset → the mode still set → second feed forks the same
way — the brief §2 sequence turned into a lane); (c) an override of an unknown or
non-settable field, or an out-of-range value, is refused identically in both
lanes. This is the M11 `differential.keyword-header` demonstration pattern (a
lane that is the consumer's shape reduced to the primitive).

Mutations live in `SchemeMutationSuite.cmake`. New pins, each witnessed in its
own SPEC lane's program: the settable-flag read (a mutant treating every field as
settable, or none, must redden the refusal lane); the range check (a mutant
dropping the width bound); the reset-survival slot (a mutant restoring the
declared initials must redden the reset lane); the verifier's settable-counter
rule (both directions); and the payload settable-table encode/decode. The
ABI-literal pin moves 7→8. `EXPECTED_MUTATIONS`/`EXPECTED_PASSES` are recounted
from the manifest, never predicted (currently 72 passes / 628 mutations).

## 4. Gate 0 — the design calls this milestone resolves

Folded into decision
[0047](../.decisions/0047-a-parser-can-start-in-a-mode.md). Its numbered
decisions are: the optional `settable?` on `make-uint-field`; the `make-parser`
initial-values argument restricted to settable fields, range-checked, refused for
unknown/non-settable; reset restoring the embedder-given initials via a stored
merged vector; the verifier's settable-consume-counter refusal; the settable
table crossing the ABI seam under a presence guard with the honest 7→8 bump; and
the v0.5.0 framing. Two calls the owner resolved at kickoff and the slice
validates with a prototype:

- **Version framing → v0.5.0 minor.** Adds new optional public API
  (`make-uint-field` settable flag + `uint-field-settable?`, the `make-parser`
  initial-values argument) with no break — a semver minor, as M10 (v0.2.0), M11
  (v0.3.0), and M12 (v0.4.0) were.
- **ABI → bump 7→8.** Justified by a genuine emitted-payload-contract move (the
  settable table, §3.3), not a runtime-only behaviour change (which decision 0042
  item 3 rightly declined for M10, its emitted text byte-identical). The consumer
  re-measures and bumps its pin against ABI 8 (brief §1), as it did for ABI 6 and
  7. Confirmed at kickoff: a runtime-only no-bump design (the generated lane not
  range-checking overrides) was rejected — it lets a generated parser accept an
  override the interpreter refuses, the lane divergence this project never admits.

### 4.1 What Slice ① validates with a prototype before committing to fixtures

Per brief §3 ("the slice that does the work owns the design") and the M10–M12
precedent (prototype the load-bearing shape first): a scratch prototype in an
isolated worktree confirms, in BOTH lanes, that (a) two parsers built from one
machine with different settable initials fork behaviour as their mode dictates and
agree interpreter ≡ generated; (b) a `parser-reset!` after a mode-setting feed
restores the EMBEDDER's initial, not the declared one (brief §2); (c) an override
of a non-settable field, an unknown field, or an out-of-range value is refused in
both lanes with the same contract violation; (d) the verifier refuses a settable
field used as a counted-consume counter and accepts one used as a field-branch
selector; and (e) a generated machine with a settable field **emits and runs
end-to-end** — not merely grepping the ABI literal — so the settable-table encode
(fingerprint), the payload member, and the generated decode are all exercised, and
the ABI literal reads 8, while a machine with no settable field emits
byte-identical bytes except that literal. Only then are the fixtures written.

## 5. Slice ① — The mechanism

One atomic commit. TDD, tests first.

- **IR (`private/ir.sls`).** `make-uint-field` gains an optional trailing
  `settable?` (a boolean) via `case-lambda`, inserted before `source-label`
  exactly as M12 inserted the pause reason (`:363-372`): the 4-arg arity defaults
  it `#f` and keeps today's vector, the 5-arg arity checks a boolean and stores
  it. Add `uint-field-settable?` (new slot 4; `uint-field-source-label` moves to
  slot 5). The constructor checks local shape only.
- **Public surface (`graph.sls`).** Export and re-export `uint-field-settable?`
  beside the existing field accessors (`:109-110`, `:137-138`). The
  `.reference/source-ir-and-builder.md` constructor signature for
  `make-uint-field` gains the optional flag (the `§27:1692` "documents every
  constructor" artifact) — mechanism doc here; version/status docs are Slice ②.
- **Verifier (`verify.sls`).** Add the settable-consume-counter refusal: a
  counted-consume node whose field is settable raises the new diagnostic,
  mirroring the `pass-names` arm's shape (`:351-354`). State at
  `parked-eof-start` (`:1111-1113`) that the "may be zero" entry reasoning now
  rests on the settable field being refused as a counter (the audit result, §3.2).
  Confirm the settable flag adds no node target.
- **Normalizer + fingerprint (`private/normal-ir.sls`).** `field-table`
  (`:969-978`) carries the settable flag alongside `(name width initial slot)`.
  `encode-normal` (`:728`) encodes the settable fields as a trailing section
  present only when non-empty (§3.3), so a machine with no settable field's
  fingerprint does not move. `normal-ir-tests.sps` gains the mirror cases: two
  machines differing only in a field's settability differ in fingerprint; a
  machine with no settable field encodes byte-identically.
- **Compiler (`compile.sls`).** Emit the settable table as a fourth metadata
  member when any field is settable, else keep the three members (§3.3). Bump the
  emitted ABI literal 7→8 (`:800`). The `exec` body and the per-field `(name .
  initial)` member are unchanged.
- **Runtime (`runtime.sls`).** `make-parser` gains the optional initial-values
  argument via `case-lambda` (the 3-arg arity keeps today's behaviour): validate
  each pair against the settable table / source machine — unknown or non-settable
  name, or out-of-range value for the field's width, is a
  `byte-machine-contract-violation` (the existing make-parser violation family,
  `:342`, `:350-353`); merge the overrides over `(initial-values decls)` into
  slot 8 and store the merged vector in the new slot 17. `parser-reset!` restores
  from slot 17 (`:1510`). Both the `'op` and `'v2` arms build the 18-slot vector
  (`:393-396`, `:401-406`). Bump `current-abi-version` 7→8 (`:96`). The
  interpreter answers the settable table from the source machine
  (`interpret.sls:501-504`, extended or a sibling message); the generated lane
  reads the payload's fourth member.
- **Census & drift surfaces (loud ratchets — they fail the build, so name them).**
  Diagnostic census (`diagnostic-census-tests.sps`): the new verifier arm adds a
  `make-diagnostic` site — re-pin the per-code count, the site total, the layer-3
  fixture, and the derived catalog check against
  `.reference/verifier-diagnostic-catalog.md` for the new code. The ABI 7→8 bump
  moves, beyond `compile-tests.sps`, the direct `(byte-machine-make-compiled-machine
  7 …)` constructions in `runtime-tests.sps` and the ABI-literal mutation pin in
  `SchemeMutationSuite.cmake`. A `verify-tests.sps` case parallels the new rule.
- **Round-trip printer (`test/support/harness/.../machine-print.sls`).**
  `print`-field renders the settable flag, or a settable-field machine loses it
  on print↔reparse (and `machine-corrupt.sls`, which edits the printed datum,
  needs it before any settable-targeting corruption).
- **Reference docs (mechanism-describing).** `.reference/source-ir-and-builder.md`
  (the `make-uint-field` flag and `uint-field-settable?`);
  `.reference/generated-code-integration-chez.md` (the `make-parser`
  initial-values argument, and its "ABI version (currently `7`)" at `:127` → 8);
  `.reference/field-and-overflow.md` (settable fields and the mode
  pattern); `.reference/transition-and-cursor-semantics.md` (reset restores the
  embedder-given initials); and the parent plan's `§10` field disposition and
  `§9` `make-parser` accessor list gain a settable/initial-values disposition,
  appended not inlined.
- **Tests.** The demonstration machine and its differential lane (§3.6) — the
  mode fork, the reset-survival sequence, the refusal cases, both executors. The
  before/after node count and the settable-field size measurement (§3.5, §3.6),
  MEASURED through the emitter with the reproduce command. Regenerate **all seven**
  determinism goldens (every one embeds the ABI literal verbatim and is
  byte-compared, so all move to 8), asserting each fingerprint is unmoved (no
  golden marks a field settable) — the present guard is proved by the goldens not
  moving beyond their ABI literal.
- **Property driver + mutations.** Extend the property draw table so a generated
  machine may mark a field settable and a generated parser may start with an
  override (at a probability that keeps the strict-default path dominant); the
  Layer-1/2/3 comparators already cover field values across lanes. Re-author the
  field/make-parser mutation FINDs the shape change breaks and add the new pins
  (§3.6); recount the totals from the manifest; run the whole scheme mutation lane
  and confirm each new/changed pin is caught for the reason it names (the wrong
  signature and the exit status, never the "suite complete" line — AGENTS.md).

Exit: two parsers from one machine start in two modes and agree across executors;
a reset preserves the embedder's mode; an illegal override is refused identically
in both lanes; the verifier refuses a settable consume counter; `make test` green
in both Chez modes; the scheme mutation lane green with recounted totals; the ABI
reads 8; the before/after node count and size measurement recorded.

## 6. Slice ② — The release and the close

Written against its own re-taken base after Slice ① merges (one plan at a time).
Version surface → `0.5.0`; `CHANGELOG.md` `[Unreleased]` → dated `[0.5.0]` under
`### Added`/`### Changed`; release-ledger `release-version` (`release-ledger.sls`)
and the hardcoded assertions in `release-ledger-tests.sps` updated in lockstep
(including a new `[0.5.0]` changelog witness beside the kept `[0.1.0]`–`[0.4.0]`);
`README.org` status; the parent plan's top status line, its `§29` admission
disposition, and its Milestone 13 close disposition (appended at the foot, never
inlined); annotated tag `v0.5.0`; this design's status header → CLOSED with a
Close section. The `§26`/`§27` release census is unchanged — those are the v0.1
release criteria the ledger checks, and a settable field adds no criterion row
(the append rule freezes them). Exit: `(byte-machine test release-ledger)` green
against `0.5.0`; the tag exists; the five surfaces agree.

## Exit (full Milestone 13)

The brief's ask is met: a parser can be started in a mode other than the declared
initials, through a settable field and a `make-parser` initial-values argument,
without a general writer and without a reset that forgets the mode or a verifier
that mis-reasons about an embedder-chosen entry value. v0.5.0 is tagged. The
consumer can bump its gitlink pin off `v0.4.0` against generated ABI 8, declare
its `type` and `lenient-flags` fields settable, delete the `switch-type` + two
store nodes and the eleven-callback / twenty-two-node lenient chain, and set both
modes through one `make-parser` argument (its decision 0017's two-line seam
change). Decision 0047 records the mechanism.

## Explicitly out of Milestone 13

- **A general `parser-field-set!`** (§2 trap 1) — a mid-parse writer is corruption,
  not a mode; deferred with its rationale.
- **A settable non-uint field.** The only field kind is the uint field; there is
  nothing else to make settable.
- **An initial-values argument that restores the DECLARED initials on reset.**
  Reset restores the embedder-given initials by construction (§3.4); the other
  choice is the brief §2 bug and is not offered.
- **Making a field settable change the generated `exec`.** A settable initial is a
  construction concern; the per-byte loop does not move.

## Handed to writing-plans

- **Slice ①** — this design §5 and decision 0047's Slice ① consequences, after the
  §4.1 prototype confirms the shape. Base `18fcc8b` (or current `main`).
- **Slice ②** — this design §6 and decision 0047's Slice ② consequences. Written
  against its own base after Slice ① merges.

## References

- Upstream brief: `~/github/chez-httparse/.plans/2026-09-15-upstream-parser-mode-brief.md`
- Consumer decision 0017 (the message kind is a decision callback, not a field the
  embedder writes): `~/github/chez-httparse/.plans/decisions/0017-the-message-kind-is-a-decision-callback-not-a-field-the-embedder-writes.md`
- Decision [0047](../.decisions/0047-a-parser-can-start-in-a-mode.md)
- Decision [0042](../.decisions/0042-empty-span-delivers-one-fragment-on-the-feed-side.md)
  — the ABI-tracks-shape principle this milestone's honest bump respects.
- Decision [0019](../.decisions/0019-encoding-format-2-pre-provisioned.md)
  — "a datum the ABI carries must be in the encoding", the fingerprint rule the
  settable section obeys.
- Parent plan `§9`, `§10`, `§12`, `§16.2`, `§29:1767`.
