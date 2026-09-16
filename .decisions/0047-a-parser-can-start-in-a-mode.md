# 0047: A parser can start in a mode, through settable field initials

Date: 2026-09-15
Status: accepted
Milestone: 13, Gate 0 (milestone-13-design.md §4)

> **Amendments**
> - 2026-09-15 (Slice ①) amends item 5: the emitted settable table is keyed by
>   `(name width)`, not `(slot width)` as written below. `make-parser` resolves an
>   override by field NAME, and payload member 0 already fixes name→slot, so the
>   table carries the name. Only the fingerprint's tag-10 section uses the slot.

## Context

Decided against `main` at `18fcc8b` (v0.4.0 released, tag `v0.4.0`). This is the
fourth milestone opened from a `chez-httparse` consumer brief rather than the
parent plan (M10 empty-span, M11 keyword-table, M12 the pause reason were the
first three). It is neither a `§25` milestone (M9 was the final one, `§25:1651`)
nor a `§29` deferred extension, so it is admitted under `§29:1767`'s bar as a
minor release.

**What the runtime does today.** A field's initial value belongs to the
MACHINE. `make-parser` fills every field from the declarations the compiled
machine carries (`runtime.sls:394`, `:402`, through `initial-values`, `:806`,
which copies each `(name . initial)`), and `(byte-machine runtime)` exports
`parser-field-ref` (`:1463`) with NO mutating sibling — the read-only-ness is a
stated design decision, not an oversight (`:1489-1490`, "the declarations belong
to the compiled machine and outlive every reset"). `parser-reset!` restores the
field-values from the DECLARED initials (`:1510`). So two parsers built from one
machine cannot start in two different states.

**Why it is wrong.** A grammar whose behaviour depends on a mode the EMBEDDER
chooses — request vs response, a strict/lenient dialect, a version-selected
variant — has no way to be told the mode. `chez-httparse` reproduces llhttp
bit-exactly; llhttp parses requests and responses with one machine and one entry
state, choosing which start line by a `type` field the embedder writes before the
first byte, and turns on any subset of eleven `lenient_flags` bits the same way.
With no field writer, the consumer works around it with nodes at the machine's
ENTRY that WRITE the mode on the first feed: **one required decision callback +
three nodes** for `type` (`grammar.sls:1080-1087`) and **eleven optional decision
callbacks + twenty-two nodes** for `lenient-flags` (`:365-400`), to encode two
integers the embedder already knows (the consumer's decision 0017). A branch key
cannot carry a subset — `lenient_flags` has 2048 of them — so the callback
workaround does not generalise to a set; it multiplies.

**What the tree already settles** (measured at `18fcc8b`; full survey in
milestone-13-design.md §3):

- **The field is a `#(tag name width initial source-label)` record**
  (`private/ir.sls:928`), `width ∈ {8,16,32,64}`, `initial ∈ [0, 2^width − 1]`
  checked at construction (`:936`). The compiled machine carries `(name .
  initial)` per field — name and initial, NOT width (`compile.sls:734-740`); the
  width is resolved at emit time (`field-slot-width`, `:182`).
- **One verifier pass reasons about a field's VALUE at entry.** `parked-eof-start`
  (`verify.sls:1101-1116`) says a counted-consume node reachable at the ENTRY
  state holds "the field's initial and may be zero, so it starts at itself"
  (`:1111-1113`) — a claim about the DECLARED initial. Every other pass reasons
  about the field GRAPH (resolution, width range, branch arms), which an
  embedder-chosen initial does not touch.
- **The fingerprint already encodes field names and initials on purpose.**
  `encode-normal` writes each field as `[name-length u16be][name][width u8]
  [initial u64be]` (`private/normal-ir.sls:732-735`), because a field name and
  initial are observable to a generated parser through `parser-field-ref` and two
  machines differing in one must differ in fingerprint (`:83-85`, `:229`).
- **The parser vector is 17 slots** (0–16; field-values slot 8, immutable decls
  slot 9). `parser-result` is not on the generated↔runtime ABI; the generated
  `exec` body does not read a field's initial.

## Decision

**1. A uint field may be declared settable.** `make-uint-field`
(`private/ir.sls:928`) gains an OPTIONAL trailing `settable?` boolean via
`case-lambda`, inserted before `source-label` exactly as M12 inserted the pause
reason (`:363-372`), so the existing 4-arg arity is unchanged and no existing
machine changes. A `uint-field-settable?` accessor is added (new slot 4;
`source-label` moves to slot 5). The constructor checks local shape only (a
boolean); whether a settable field is used legally is the verifier's (item 4).
*Rejected*: every field implicitly settable — it would make item 4's soundness
question apply to fields no embedder ever overrides, and silently widen what a
`make-parser` argument may reach; opt-in keeps the settable set exactly the
grammar author's mode fields.

**2. `make-parser` gains an optional initial-values argument, restricted to
settable fields, range-checked, applied only at construction.** A fourth
argument (`case-lambda`, so the 3-arg arity is unchanged) is an alist
`((field-name . value) …)`. Each pair is validated: an unknown name, a
non-settable field, or a value outside the field's declared width `[0, 2^width −
1]` is a `byte-machine-contract-violation` (the existing make-parser violation
family, `runtime.sls:342`, `:350-353`). The overrides are merged over
`(initial-values decls)` into the field-values. Because it is a CONSTRUCTION
argument, it cannot apply mid-parse. *Rejected, with the failure it would cause*:
a general `parser-field-set!` exported beside `parser-field-ref` — a general
writer would let a caller change `content-length` between feeds mid-parse, which
is not a mode, it is corruption (brief §3); the read-only-ness is a stated design
decision (`:1489-1490`). If a writer were ever wanted it would have to be
restricted to a parser that has not consumed a byte, or to settable fields — which
is what a construction argument to settable fields already is, without the
mid-parse surface.

**3. `parser-reset!` restores the EMBEDDER-GIVEN initials, not the declared
ones.** `make-parser` stores the merged initials in a new immutable parser slot
17, and `parser-reset!` restores the field-values from slot 17 rather than
recomputing `(initial-values decls)` (`:1510`). A reset returns the parser to its
JUST-CONSTRUCTED state, and a just-constructed parser holds the embedder's mode,
so the mode survives a reset by construction. With no initial-values argument slot
17 equals the declared initials and reset is unchanged. *Rejected, with the
failure it would cause*: restoring the DECLARED initials on reset — the mode would
silently vanish on the first reset, the same bug as a wrong default arriving
later (brief §2). The consumer already engineered around exactly this, keeping
`lenient-flags` separate from its framing `flags` so the mode survives its
inter-message restart (`grammar.sls:321-324`); the callback-chain workaround got
reset-survival for free by re-asking, and a replacement must be at least as hard
to get wrong.

**4. The verifier refuses a settable field used as a counted-consume counter.** A
counted-consume node whose consumed field is settable raises a new diagnostic
(`settable-consume-counter`, or a clearer spelling the item-7 prototype settles),
keyed on the field name, mirroring the `pass-names` resolution arm
(`verify.sls:351-354`). This closes the one entry-value soundness hole a settable
initial opens: `parked-eof-start`'s "may be zero" reasoning (`:1111-1113`) rests
on the entry counted-consume counter holding its declared initial, which an
embedder override would falsify. The rule is broader than "at entry" and
deliberately so — a counter's meaning is a count that starts at a known value, and
an embedder-chosen start makes the count analysis unsound wherever used. A
settable field is a mode/bitset selector, never a consume counter (the consumer's
`type`/`lenient-flags` are field-branch selectors), so the rule refuses only
nonsense. *Rejected*: relaxing the entry reasoning to treat every entry
counted-consume counter as possibly-positive — it would change the analysis for
existing machines that rely on the declared-zero case, rejecting or re-routing
legal grammars; refusing the (nonsensical) settable counter leaves the reasoning
exactly as-is for every real machine.

**5. The settable marking and the width the generated lane needs cross the ABI
seam under a presence guard; the generated ABI bumps 7 → 8.** The generated
lane's `make-parser` must reject an override of a non-settable or unknown field
and range-check a settable one to its width, IDENTICALLY to the interpreter, or
the two lanes diverge — which the differential lanes exist to forbid. The
interpreter has the full uint-fields; the generated lane has only `(name .
initial)`. So the settable table (`(slot width)` per settable field — **amended
2026-09-15 (Slice ①): shipped keyed by `(name width)`, see the header**) rides as a
FOURTH emitted-metadata member, present only when at least one field is settable
— a machine with none emits the current three members, byte-identical except the
ABI literal — and the runtime's decoder length-guards it (absent ⇒ no settable
field ⇒ every override refused). It enters the fingerprint as a trailing section
encoded only when non-empty (the decision-0019 rule "a datum the ABI carries must
be in the encoding, not merely read from the source" — else two machines
differing only in a field's settability share a fingerprint but emit different
bytes), the same appended, present-guarded pattern the fields/callbacks/spans
sections already use (`normal-ir.sls:100-105`). `current-abi-version`
(`runtime.sls:96`) and the emitted literal (`compile.sls:800`) move 7 → 8; the
ABI lane reads 8 out of the emitted text, as each prior bump did. *Rejected, with
the failure it would cause*: a runtime-only design carrying nothing across the
seam (no ABI bump) — the generated lane could not range-check or reject an
override, so a generated parser would accept an override the interpreter refuses,
the lane divergence this project never admits. *Rejected*: growing every field's
`(name . initial)` member and fingerprint record to carry width+settable
uniformly — it would move every field-bearing golden's field bytes for a marking
almost every field does not carry; the present-guarded trailing table moves only a
machine that actually marks a field settable.

**6. Ships as v0.5.0 (minor).** Adds new optional public API (`make-uint-field`'s
settable flag, `uint-field-settable?`, the `make-parser` initial-values argument)
with no break — a semver minor, as M10 (v0.2.0), M11 (v0.3.0), and M12 (v0.4.0).
The release is Milestone 13 Slice ②.

**7. Slice ① prototypes the load-bearing shape first.** Per brief §3 (the slice
that does the work owns the design) and the M10–M12 precedent, a scratch
prototype in an isolated worktree confirms in BOTH lanes: two parsers from one
machine with different settable initials fork behaviour and agree interpreter ≡
generated; a `parser-reset!` after a mode-setting feed restores the embedder's
initial, not the declared one (brief §2); an override of a non-settable, unknown,
or out-of-range field is refused identically; the verifier refuses a settable
consume counter and accepts a settable branch selector; and a generated
settable-field machine emits AND runs end-to-end with the ABI reading 8, while a
machine with no settable field emits byte-identical bytes except the ABI literal.
Only then are the fixtures written.

## Consequences

- **Handed to Slice ① (the mechanism, one atomic commit).** After the item-7
  prototype: the `settable?` flag on `make-uint-field` and `uint-field-settable?`
  (`private/ir.sls`), exported through `graph.sls`; the `make-parser`
  initial-values argument, its validation, and the merge into field-values + the
  new slot 17; `parser-reset!` restoring from slot 17; `current-abi-version` 7→8.
  The settable table across `field-table` and the guarded `encode-normal` trailing
  section (`private/normal-ir.sls`), the fourth emitted-metadata member and the
  ABI literal (`compile.sls:800`), and the generated-lane decode; the interpreter
  answering the settable table from the source machine (`interpret.sls:501-504`).
  The verifier's settable-consume-counter refusal (`verify.sls`) and its
  `verify-tests.sps` case. TDD in a new differential/determinism/interpret
  demonstration: two parsers from one machine started in two modes agreeing across
  executors, the reset-survival sequence, and the three refusal cases; the
  before/after node count and the settable-field size measurement MEASURED through
  the emitter with the reproduce command. Regenerate **all seven** determinism
  goldens (each embeds the ABI literal verbatim and is byte-compared, so all move
  to 8), asserting each fingerprint is unmoved (no golden marks a field settable —
  the present guard proved by the goldens not moving beyond the ABI literal).

  The drift surfaces Slice ① owes: the diagnostic census
  (`diagnostic-census-tests.sps` counts + site total + layer-3 fixture + the
  derived catalog check against `.reference/verifier-diagnostic-catalog.md` for
  the new code); the direct ABI-7 constructions in `runtime-tests.sps` and the
  ABI-literal mutation pin (`SchemeMutationSuite.cmake`) → 8; the settable field on
  `machine-print.sls` (before any `machine-corrupt.sls` settable corruption); the
  `property-driver.sls` draw table extended to mark fields settable and start
  parsers with overrides at a probability that keeps the strict-default path
  dominant; and the mechanism-describing reference docs
  (`.reference/source-ir-and-builder.md`, `field-and-overflow.md`,
  `generated-code-integration-chez.md` incl. its "ABI version (currently `7`)"
  (`:127`) → 8, `transition-and-cursor-semantics.md`) with a `§9`/`§10`
  disposition for the
  settable flag and the initial-values argument.

- **Handed to Slice ② (the release and the close).** The version surface moves to
  `0.5.0` across the five surfaces the release ledger names; `CHANGELOG.md`'s
  `[Unreleased]` becomes a dated `[0.5.0]` section; the release ledger's
  `release-version` and its hardcoded version assertions (`release-ledger-tests.sps`)
  move in lockstep (a new `[0.5.0]` changelog witness beside `[0.1.0]`–`[0.4.0]`);
  the tag; the parent plan's top status line, its `§29` admission disposition, and
  its Milestone 13 close disposition (appended at the foot, never inlined); and
  the five milestone-status surfaces (AGENTS.md) all say M13 closed. The
  `§26`/`§27` criteria are the v0.1 criteria the ledger checks and gain no row.

- **A mutation pin per new decision**, witnessed in the new demonstration lane's
  program: the settable-flag read (every-field-settable and no-field-settable
  mutants both redden the refusal lane); the range check; the reset-survival slot
  (a mutant restoring the declared initials reddens the reset lane); the verifier's
  settable-counter rule (both directions); and the payload settable-table
  encode/decode.

- **The consumer picks it up** by bumping its gitlink pin off `v0.4.0` against
  generated ABI 8, declaring its `type` (u8) and `lenient-flags` (u16) fields
  settable, deleting the `switch-type` + two store nodes and the eleven-callback /
  twenty-two-node lenient chain, and setting both modes through one `make-parser`
  initial-values argument — its decision 0017's "two-line change at the seam, and
  the grammar does not move".
