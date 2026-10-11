# 0058: The allocation audit is a census of arm kinds too

Date: 2026-10-11
Status: accepted; released in 0.8.0 (2026-10-11)
Milestone: none. Settles [0057](0057-a-digit-compares-against-its-bound.md)'s "What this does not fix", first bullet, after 0.7.0
Builds on: [0040](0040-allocation-audit-is-a-slope-with-a-control.md) (the slope and its live control), [0055](0055-the-allocation-audit-is-a-census-of-runtime-ops.md) (the counting twin and the op census), [0057](0057-a-digit-compares-against-its-bound.md) (the digit witness, and the fixnum limit on "allocates nothing")
Amends: [0057](0057-a-digit-compares-against-its-bound.md) ("What this does not fix", first bullet)

## Context

0055 bounded the allocation audit's scope by a census of the runtime ops
emitted code can call. 0057 found the hole in that bound: an arm whose cost is
inline code calls no op, so the census cannot say whether any audited input
runs it. The integer-accumulate arm allocated on every digit into a u64 field
for that reason, in the audit's own HTTP fixture, while the lane was green.
0057 named the closure: count, on the counting twin, which state arms each
audited input enters, and fail for any arm kind the HTTP and keyword machines
render that no witness enters.

Measured first. The twin was given a counter at the head of every state
procedure (item 1), and the rows of items 2 and 3 were run against the lane as
0057 left it, before any witness below was added. Through the source launcher
(`ctest --test-dir build/dev -R allocation-audit.chez.source -V`, which prints
the `arm census` lines and the rows' failures):

- The HTTP machine renders 217 states; the audited inputs entered 49.
- Arm kinds rendered and never entered, as `(machine . kind)`:
  `(httpcensus . accumulate)`, `(httpcensus . counted-consume)`, and the
  overflow `error` arm of each of 0057's two digit machines.
- Kinds `render-state-arm` renders that no audited machine renders: `pause`.
- Field operations and predicates the emitter renders and no input entered:
  12 of 14. The HTTP machine renders three (`store`, `clear`, `nonzero`), and
  its only stores, the two framing flags, were on the body path, so only
  `clear` and `nonzero` had run.

The two unentered HTTP kinds are the body path: every audited message had no
body. A scratch probe listing the HTTP machine's field, count and accumulate
states one by one found 13 of its 19 never entered: both accumulate arms (the
Content-Length digits and the chunk size), both counted-consume arms, the
branch on the Content-Length value, the four framing branches after a
Content-Length or Transfer-Encoding line, both flag stores, and the chunk-size
branch and its reset.

## Decision

1. **The twin counts the states it enters.** Each state of a rendered machine
   is one procedure `%s<id>` inside `exec`. The lane reads the twin's library
   as a datum and puts `(census-enter! 'machine id)` at the head of each one,
   so an input's reach is the set of states it entered. Kinds come from the
   normalized IR, read by importing `(byte-machine private normal-ir)`: a
   rendered library names its states but not their kinds, and no public
   library exports them. The lane re-normalizes the verified machine and
   refuses to load a pair whose IR fingerprint differs from the one the
   rendered library passes its constructor. A check asserts that the counted
   ids of every twin are exactly `0..N-1`.
2. **The totality row is per machine, and per arm.** Every arm an audited
   machine renders must be entered, in that machine, by a witness, an arm
   being the state's kind, with its selector where it has one: a field arm's
   operation or predicate, an accumulate arm's base. Each selector renders
   different inline code. Per machine is 0057's reading ("the HTTP and keyword
   machines render"); across machines, once 0057's digit machines were
   witnessed `accumulate` was entered somewhere while the HTTP machine's two
   accumulate arms still never ran. Per kind is not enough either, measured:
   with the fixed-body witnesses' registrations deleted, a per-kind row stayed
   green, since the chunk size's base-16 arm stood in for the Content-Length
   digits' base-10 one, which is the arm 0057 fixed; the per-arm row names
   `(httpcensus accumulate . 10)`.
3. **It is total over the emitter, not only over the fixtures.** The kinds
   `render-state-arm` renders are derived from compile.sls as the labels of its
   `case` on `(normal-state-kind s)`, the way 0055 derives ops from string
   literals. Every derived kind must be rendered by some audited machine, so a
   new kind fails the lane until a witness machine has it. One level down, the
   same holds for field arms: the labels of `render-operation`'s `case` on `op`
   and `render-predicate`'s on `pred` must each be entered by a witness.
   Each derivation has a control in the other direction (every kind rendered,
   every field arm entered, is a derived label), so a dispatch rewritten in a
   form the recogniser cannot read fails by naming everything, rather than
   deriving an empty set that every row then accepts.
4. **Witnesses, each with its answers read back before its allocation:**
   - *A fixed body.* Bodies of 10044 and 50044 bytes allocate the same, with
     callbacks disabled and bound. The two lengths have the same number of
     digits, so the Content-Length digits cannot enter the slope; with 44 and
     40044 they did, and 0057's mutant of the digit bound reddened this case.
   - *A chunked body.* 201 chunks allocate what 1 does, disabled and bound.
   - *Counts above the fixnum range.* A Content-Length and a chunk size of
     2^64 − 1, the feed ending inside the body: 44 and 40044 bytes consumed
     allocate the same. Counted consume stores its remainder once per feed, so
     a bignum count costs per feed, never per byte; recorded as 82 B per
     message more than a fixnum count, the Content-Length digits included.
   - *The digit machines' overflow.* 2^64, refused at its last digit, costs the
     same after 10 numbers as after 1010.
   - *A pause.* A machine with both renderings of the arm, with and without a
     reason: a pause after 40044 bytes allocates what one after 44 does.
   - *Every field operation and predicate on a u64 field.* One machine, a
     settable field per row, and bignum constants where a row's values can
     still be fixnums: `clear-mask`'s mask, `range`'s upper bound, and the
     masks of `mask-any` and `mask-none`. Each row runs from an initial value below
     `(greatest-fixnum)`, where 1000 more executions must allocate nothing, and
     from one above it, recorded. The live control is `increment` above the
     range, which must allocate.
5. **The claim, and its limit, are 0057's, for every arm.** An arm allocates
   nothing while every value it computes is a fixnum. Above the range,
   measured per execution: 16 B for an arm whose result is a bignum
   (`increment`, `decrement`, `add`, `set-mask`, `clear-mask`) and for a mask
   test whose masked value is one (`mask-any`, `mask-none` here); 0 B for
   `store`, `clear`, `mask-all` with a fixnum mask, and every comparison
   (`equal`, `zero`, `nonzero`, `range`; `range` against a bignum bound).
   No library code changes: the measurement found no arm allocating below the
   range. The documentation's caveat already states the limit.

## What it costs

The lane ran in about 1.4 s and now runs in about 1.5 s (source). The
mutation lane gains thirteen mutations.

## What this does not cover

- **Branches inside an arm.** The census unit is a state, so entering an arm is
  not running each of its branches: a fallible operation's failure edge, the
  counted-consume and keyword arms' end-of-input branches under finish, the
  keyword arm's need-input branch. Nor is every state entered: of the HTTP
  machine's 217, 136 are. The other 81 are 25 error states, 44 dispatch states
  and 12 span states (counted by a scratch copy of the lane), and no row asks
  for them, because their kinds are entered elsewhere in the machine.
- **Variants below the arm.** A span completion with and without its
  callback, a pause or callback with and without a reason: each is witnessed
  where this lane already runs it (both pause renderings here), but no row
  requires it.
- **The emitter-wide field rows are across machines.** Every operation and
  predicate the emitter renders must be entered in some machine (in practice
  the field machine), not in each; the per-machine row is what asks for the
  ones an audited machine renders, in that machine.
- **What the compiler folds.** `clear-mask` renders `(bitwise-and v
  (bitwise-not K))`, and allocates nothing below the range only because Chez
  folds `(bitwise-not K)` at compile time; for a 64-bit mask K is a bignum.
  The emitter could write the complement at emit time, as 0057 did for the
  digit bound, and would move every golden with a `clear-mask` in it. Not done
  here: the field row is what would notice if the folding stopped.
- **A kind rendered outside `render-state-arm`'s case.** The emitter-side row
  derives from that one `case`. A kind rendered some other way would be
  invisible to it, though the per-machine row would still fail for it as soon
  as an audited machine rendered one.

## Witnesses

- `byte-machine.unit.allocation-audit` gains a body group (four cases), a pause
  group, a field-arm group, an overflow block in each digit case, and an
  arm census group of six rows: the instrumenter's completeness, the kind
  recogniser's control, the emitter's kinds rendered, the per-machine arm
  totality, the field-arm recogniser's control, and the field arms entered.
- The mutation lane gains thirteen mutations, all in Pass 77: from 79 passes /
  698 mutations on `main` when this merged it (`9932801`) to 79 / 711. Two shipped mutations moved: "an arm no audited input reaches calls
  a runtime op" and its split-name twin were anchored in the counted-consume
  arm, which a witness now enters, so the first went uncaught (measured: exit
  0). Both now sit in `%dispatch`'s fallback clause of a callback answer, the
  one clause no construction reaches. Thirteen are new. Two turn an HTTP
  fixture error node that no input reaches into an arm no witness enters
  there: a stop, a kind the machine has nowhere else, and a `set-mask` field
  action, a kind its witnesses enter with an operation they never run there,
  which only the per-arm reading catches (the per-machine row). A case label
  no IR state carries, for kinds and for operations (the emitter rows). Each
  dispatch rewritten so its recogniser reads nothing (the controls). The stop
  arm defined as `(define %sN (lambda ...))` (the instrumenter's check). And
  six allocations in the arms the new witnesses enter: counted consume
  (pinned on the fixed body), an infallible and a fallible field action and a
  field branch (the field group), a pause, and an accumulate overflow. The
  chunked body and the two above-range cases carry no pin of their own; they
  redden under the counted-consume, digit-bound, infallible field-action and
  field-branch mutants. Every pin was measured against a staged copy: each
  resolves exactly once in its own mutant's output and in none of the other
  24 mutants' outputs in the pass, whose baseline exits 0.
