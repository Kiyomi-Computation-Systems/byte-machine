# 0056: An error records the span it abandoned

Date: 2026-10-01
Status: accepted; unreleased
Milestone: none. From [issue #145](https://github.com/Kiyomi-Computation-Systems/byte-machine/issues/145), filed from chez-http-server's cut-off-span PR record, after 0.6.1
Builds on: [0028](0028-callback-slots-and-visible-state.md) (`parser-active-span`, a plain accessor added rather than an existing one widened to a compound), [0022](0022-structured-parser-error-record.md) (the parser-error family, and the five-argument constructor generated code calls), [0042](0042-empty-span-delivers-one-fragment-on-the-feed-side.md) (the span-end and flush delivery steps)

## Context

When a parse error stops the parser with a span open, the span is abandoned:
the runtime flushes no final fragment and synthesizes no completion
(`§14:839`). Fragments that went out at earlier feed boundaries stay
observable. The bytes the span took in the feed that failed are never handed
to the application.

chez-http-server holds a request target and a field name to size limits. It
counts their bytes as the parser hands them over, so a request whose limit-
crossing byte and malformed byte arrive in one feed is answered 400, and the
same request split between them is answered 414 or 431. The issue measured it
through chez-httparse v0.4.4: of 40,000 random malformed requests each fed at
every delivery size, 980 got different answers at different sizes, and for
326 the status itself differed. Those numbers are the issue's, measured there,
not re-taken here.

`parser-active-span` still names the span after an error, since an error
leaves span state alone. What the embedder cannot get is where that span's
undelivered bytes begin. The runtime holds it, as the span's mark, and no
accessor reads the mark.

## Decision

1. **Two accessors on the parser-error record**, each `#f` when no span was
   open at the error, and each non-`#f` otherwise:

   ```scheme
   (parser-error-span error)          ; the span the error abandoned, or #f
   (parser-error-span-offset error)   ; where its withheld bytes begin, or #f
   ```

   Two plain values, not one `(span . offset)` compound. The record's other
   eight members are each read through their own accessor, and 0028 added
   `parser-active-span` as a plain accessor rather than widen
   `parser-state-name` to a compound. 0028's own reason does not transfer, and
   is not claimed: it rejected a compound that appears in cases a caller cannot
   predict, and `#f`-or-a-pair would be predictable here. What decides it is the
   family's shape, and that the two are read apart: the server in the issue
   picks 414 or 431 from the name alone, and needs the offset only to count.

2. **What the offset means.** `[span-offset, parser-error-offset)` is exactly
   what `§14:839` withholds: bytes the parser took for the span and neither
   flushed nor delivered. Every byte the span took before `span-offset` went out
   in an earlier fragment. So for a machine error mid-feed the offset is the
   span's own start when it opened in the failing feed, and the failing feed's
   start when the span was carried into it — the issue's two cases. The range
   can be empty, on two paths the issue did not list (item 4).

3. **It is filled where both executors hand the error back**, not by either
   executor: in `parser-feed!` after the boundary flush, and in
   `parser-finish!` after the finish path. `abandon-span!` reads the parser's
   span name and mark there and writes the two members into the record the
   executor built. Both constructors build them as `#f`. So the
   generated-runtime ABI stays 9, no emitted text changes, and no golden moves.

   The record is written **in place**, not copied. It has not left the runtime
   yet: one constructor call per error builds it, and nothing has returned it.
   Both finish paths **store** their error before the seam sees it, so the
   record they stored and the one the call returns are the same object, and
   they gain the span together. A copy was built first and measured. It needed
   the finish seam to store the copy again, which made every finish path's own
   store redundant, and the full mutation run reported three shipped pins
   UNCAUGHT: "the default-eof arm does not store its value", "a finish reaching
   a named error node does not store its value" and "a /v2 finish error does
   not store its value". An uncaught pin had found a property enforced in two
   places, so the copy went, not the pins.

   The mark is a slice offset, and the record wants a stream offset. A feed
   result names one point twice: `next` in the slice and `stream-offset` in the
   stream. The mark therefore lies `next - mark` bytes before the result's
   stream offset. A finish runs over the empty slice `[0, 0)` and re-anchors an
   open span's mark to 0, so its cursor is 0 and its withheld range is always
   empty: the last feed's boundary flush handed over every byte the span took.
   A finish result's `next` repeats the stream offset, so the cursor is passed
   in rather than read from it.

   Only an `error` result is filled. A `need-input` or `paused` result can leave
   a span open, and has no record to fill: a pause abandons nothing, and
   `parser-result-pause`'s reason answers `#f` for both members.

4. **A delivery advances the mark to the fragment's end**, before the callback
   runs. This is what `§13:822` specifies ("with the delivered mark already
   advanced to the fragment end"). The code had dropped it because nothing could
   observe it (`.reference/callback-span-lifetime.md` §3 recorded the
   divergence). Now something can. A data callback that **fails** leaves the
   span open, at the span end (the completion substep that closes it never
   runs) and at a feed-boundary flush (the feed ends in error, so no next feed
   re-anchors the mark). Without the advance, the error would report as
   withheld the bytes that callback had just been handed, and an embedder
   counting them would count them twice.

   The issue says "at an error, the mark is exactly where the undelivered bytes
   begin". That holds for every machine error and is false on those two paths.
   It was checked against the code rather than adopted, per
   [AGENTS.md](../AGENTS.md)'s rule for outside proposals, and is recorded here
   because the issue's proposal rests on it.

   Restoring the advance moved one shipped mutant's output. "An open span's mark
   is not re-anchored at the next feed" used to mis-slice the next feed by one
   byte. Its stale mark is now the previous slice's end, past the next span
   end's cursor, so that end delivers nothing. It is still caught, by the same
   check, with a different got. It was re-pinned on the measured output, with a
   dated note on the paragraph that described the old one.

5. **The record does not say which withheld byte was refused.** The issue
   suggests the embedder take `[span-offset, error-offset)`, "less one at
   `boundary`, where the parser took the refused byte before refusing it". That
   is a fact about the issue's grammar, not about position kinds. `boundary` is
   also what a callback failure records, and there the withheld range is empty
   (measured in both the new lane and `position-kind-tests.sps`'s span-data
   row, `cl 2 boundary body 2`), so subtracting one would give a range that runs
   backwards. What the record states is what the parser took. When the error
   node was entered over an `advance` edge, the last withheld byte is the one
   whose transition led to the error. Whether that byte belongs to the token is
   the grammar's call.

6. **An unbound data callback changes nothing above.** A span whose optional
   data callback is not bound hands its fragments to nobody. The offset still
   marks where the withheld fragment begins. An embedder counting a span's
   bytes binds its data callback.

## What it costs

Every error record is two slots larger, eleven where it was nine, whether or
not a span was open. Filling the two costs two slot writes, on the error path
only. A delivery costs one more slot write per fragment, not per byte. Nothing
changes on the per-byte path. The allocation lane's two error witnesses (an
error costs the same however many bytes precede it) pass unchanged, and their
two record-growth mutations were re-anchored onto the eleven-slot constructors.
This is reasoned, not benchmarked. The cell that would show a per-delivery cost
is `byte-at-a-time-fragmentation`, the one benchmark that delivers a fragment
for every byte.

`compile.sls`'s `reserved-member-2` mirrors the runtime's exports, so it gains
the two names. An output binding spelled `parser-error-span` or
`parser-error-span-offset` is now refused at compile time. It would have
collided with the runtime import of every generated library.

## What this does not do

- **It does not flush on error.** `§14:839` stands: the bytes are reported, not
  delivered.
- **It does not record a carried span's own start.** For a span carried into
  the failing feed, the offset is that feed's start. The earlier bytes went out
  at feed boundaries, and the embedder already counted them. Recording the
  start too would need a parser slot per span start. Nothing here needs it.
- **A pause reason carries no span.** The parser is live after a pause, and
  `parser-active-span` answers.

## Witnesses

- `byte-machine.differential.abandoned-span` (source and AOT), a new lane over
  a token machine that refuses a byte from inside the span by reexecute and by
  advance. It has one group per path: no span open, a machine error in the
  failing feed, a span carried across a feed, a span opened inside a sub-slice,
  a data callback failing at the span end and at a flush, a completion callback
  failing after the span closed, truncation at finish, the stored error on
  both sticky rows, reset, and a pause. Its last group is the property itself.
  Under every schedule of up to three slices of one input (113 schedules per
  lane across four inputs), the delivered fragments followed by
  `[span-offset, error-offset)` are the span's bytes up to the error, in both
  lanes.
- The cross-lane error projection (`error-projection.sls`) carries both members,
  six to eight, so every differential lane and the property differential compare
  them across executors.
- `byte-machine.unit.runtime`: both constructors build the two members as `#f`.
- Mutation Pass 78 has thirteen mutations. They cover the guard's two
  conjuncts, each seam's call, two operands of the offset arithmetic, each
  seam's cursor, the mark advance, the two slot writes, an accessor's slot and
  each constructor's default. Each is pinned on one record measured by staging
  the mutant, and a 13 × 13 sweep finds every pin once in its own mutant's
  output and in no sibling's. One conjunct, `e`, is caught by a raise: a
  `need-input` or `paused` result has no record to write into. Eight shipped
  pins were re-pinned and none retired. Two record-growth pins in Pass 77
  follow the eleven-slot constructors. Five pins spelled the error projection
  that grew. Pass 54's re-anchor pin is the one item 4 describes. The suite
  goes from 77 passes / 660 mutations to 78 / 673.
