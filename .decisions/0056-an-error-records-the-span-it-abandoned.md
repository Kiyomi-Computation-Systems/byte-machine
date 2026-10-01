# 0056: An error records the span it abandoned

Date: 2026-10-01
Status: accepted; unreleased
Milestone: none. From [issue #145](https://github.com/Kiyomi-Computation-Systems/byte-machine/issues/145), filed from chez-http-server's cut-off-span PR record, after 0.6.1
Builds on: [0028](0028-callback-slots-and-visible-state.md) (`parser-active-span`, a plain accessor added rather than an existing one widened to a compound), [0022](0022-structured-parser-error-record.md) (the parser-error family, and the five-argument constructor generated code calls), [0042](0042-empty-span-delivers-one-fragment-on-the-feed-side.md) (the span-end and flush delivery steps)
Amends: [0022](0022-structured-parser-error-record.md) (item 1's member count, item 8's projection width)

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
   is empty whenever the span took nothing since its last fragment: at every
   finish error (item 3), when a data callback fails (item 4), and when a byte
   is refused before the span takes any in the failing feed (the new lane's
   `A!` case: `tok 1` at offset 1).

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
   also recorded where no byte was refused, and the range can then be empty. A
   span data callback that fails records it, and was handed its bytes: the new
   lane asserts `close 3 boundary tok 3` for a failure at the span end.
   Subtracting one there gives a range that runs backwards. What the record
   states is what the parser took. When the error
   node was entered over an `advance` edge, the last withheld byte is the one
   whose transition led to the error. Whether that byte belongs to the token is
   the grammar's call.

6. **An unbound data callback changes nothing above.** A span whose optional
   data callback is not bound hands its fragments to nobody. The offset still
   marks where the withheld fragment begins. An embedder counting a span's
   bytes binds its data callback.

## What it costs

Every error record is two slots larger, eleven where it was nine, whether or
not a span was open. `abandon-span!` runs once per `parser-feed!` and
`parser-finish!` call, error or not: a call, two slot reads and a test, plus
two slot writes when it fills a record. A delivery costs one more slot write
per fragment. None of it is per byte, except where the caller feeds one byte
at a time, which makes the per-call and per-fragment costs per byte. The
allocation lane's two error witnesses (an error costs the same however many
bytes precede it) pass unchanged, and their two record-growth mutations were
re-anchored onto the eleven-slot constructors. This is reasoned, not
benchmarked. The cell that would show either cost is
`byte-at-a-time-fragmentation`, which feeds one byte per call.

`compile.sls`'s `reserved-member-2` mirrors the runtime's exports, so it gains
the two names. An output binding spelled `parser-error-span` or
`parser-error-span-offset` is now refused at compile time. It would have
collided with the runtime import of every generated library.

## What this does not do

- **It does not flush on error.** `§14:839` stands: the bytes are reported, not
  delivered.
- **It does not record a carried span's own start.** For a span carried into
  the failing feed, the offset is never earlier than that feed's start (and
  later when a data callback failed). The earlier bytes went out at feed
  boundaries, and the embedder already counted them. Recording the start too
  would need a parser slot per span start. Nothing here needs it.
- **A pause reason carries no span.** The parser is live after a pause, and
  `parser-active-span` answers.

## Witnesses

- `byte-machine.differential.abandoned-span` (source and AOT), a new lane. Its
  token machine refuses a byte from inside the span by reexecute and by
  advance. Each path has an expected-value case:
  - no span open, in a first feed and in a later one;
  - a machine error in the failing feed, including one before the span takes a
    byte;
  - a span carried across a feed, and a span opened inside a sub-slice;
  - a data callback failing at the span end, at a flush, and at a later flush;
  - a completion callback failing after the span closed, in a first feed and
    in a later one;
  - truncation at finish;
  - the stored error on both sticky rows, reset, and a pause.

  Its last group is the property itself, over three machines: the token
  machine, a keyword table inside a span (the prefix it parks across feeds), and
  a counted body inside a span. Every way to feed one input in up to three
  slices is run, each slice copied behind its own padding so that no slice index
  is a stream offset. That is 174 schedules per lane across eight inputs. In
  both lanes, the delivered fragments followed by `[span-offset, error-offset)`
  are the span's bytes up to the error. Each row's schedule count is checked
  against a number written into the row, and the number of rows against eight.
- The cross-lane error projection (`error-projection.sls`) carries both members,
  six to eight. Every differential program that compares errors through it
  compares them across executors, and so does the property differential. That
  is 12 of the 17 differential programs (`rg -l error-projection
  test/common/differential-*.sps`). The counted-span, keyword-span,
  keyword-table, keyword-header and settable differentials do not use it. The
  new lane's keyword-table and counted rows cover the two span shapes among
  them.
- `byte-machine.unit.runtime`: both constructors build the two members as `#f`.
- Mutation Pass 78 has twenty mutations, nineteen pinned and one declared
  survivor:
  - the guard's two conjuncts;
  - each seam's call and cursor, and the fill's order against the flush;
  - two operands of the offset arithmetic;
  - each slot written and each slot read;
  - the span recorded and the mark advance;
  - each constructor's two defaults.

  Each pin sits on one record measured by staging the mutant. A 19 × 20 sweep
  finds every pin once in its own mutant's output, in no sibling's, and not in
  the baseline's. One conjunct, `e`, is caught by a raise: a `need-input` or
  `paused` result has no record to write into.

  The survivor narrows the advance to failing deliveries. A mark advanced on a
  successful delivery is overwritten before anything reads it, so no lane can
  tell the two apart (measured across the eleven lanes that drive a span). It
  is declared because the boundary flush's absent `paused` arm is inert only
  while every delivery advances.
- Eight shipped pins moved, and none was retired:
  - five pins that spelled the error projection, re-pinned;
  - Pass 54's re-anchor pin, re-pinned (item 4 describes it);
  - Pass 77's two record-growth pins, re-anchored onto the eleven-slot
    constructors.

  The suite goes from 77 passes / 660 mutations to 78 / 680.
