# Transition and cursor semantics

How a byte moves the parser, what the cursor and the absolute stream offset
mean, what each parser status tells a caller, and how `parser-feed!` and
`parser-finish!` differ at the end of the input.

This is `§27:1693` of
[the implementation plan](../.plans/byte-machine-implementation-plan.md). Everything
below was checked against the code — `(byte-machine runtime)`,
`(byte-machine interpret)`, and `(byte-machine private ir)` — not against the
plan; where the two would differ, the code is described and the difference named.
Applies to byte-machine at Milestone 8. Both executors — the reference
interpreter and a generated parser — behave identically here except where a
difference is called out.

---

## 1. The two edge modes

A byte-reading transition is an **edge** (`make-edge` in
`(byte-machine private ir)`), and every edge declares one of exactly two modes,
`advance` or `reexecute` (`§11.2`, `§11.3`). The mode decides what happens to the
current byte after the edge's target is chosen.

- **`advance`** commits the examined byte: it enters the target, moves the cursor
  forward by one, and increments the absolute stream offset by one (`§11.2`). The
  byte is consumed; the parser will not see it again.
- **`reexecute`** enters the target *without* moving the cursor or the stream
  offset (`§11.3`). The target observes the same current byte. This is how
  delimiter handling and span exclusion work without any pushback — there is no
  general rewind or backtracking. Peeking at a delimiter is expressed as a
  one-byte dispatch with a `reexecute` edge.

Edges with a mode occur on the byte-reading kinds only: a byte-dispatch node's
cases and its fallback (`byte-case-edge`, `byte-dispatch-node-fallback`), a
sequence-dispatch node's mismatch edge (`sequence-dispatch-node-mismatch`), and
an integer-accumulate node's non-digit fallback edge
(`integer-accumulate-node-nondigit-edge`). A sequence *case* carries a bare
target and no mode: a successful sequence always consumes every byte in it
(`§10.6:546`), so only the mismatch edge has a choice to make. Zero-width kinds
(field action, field branch, callback, span start/end) and a pause node's single
out-edge take no byte and have no mode (`§11.4`). The interpreter routes both
modes in one place (`route-byte-step!` inside `parser-feed!`) and, in doing so,
sets the position kind — see §4.

## 2. The cursor and the absolute stream offset

`parser-feed!` takes `(parser bytevector start end)` and reads the half-open
slice `[start,end)`; `0 <= start <= end <= bytevector-length` or it raises an
API-contract condition before any mutation (`parser-feed!`, `§11.1`). An empty
slice is a valid feed, never EOF.

- The **cursor** is a position *within the current slice*. It starts at `start`
  and advances one byte per `advance` edge (and by the committed count of a
  counted consume). It is reported relative to the supplied bytevector as
  `parser-result-next` — the first unconsumed index — with
  `parser-result-consumed` equal to `next - start` (`§11.5`).
- The **absolute stream offset** is the total number of bytes committed across
  *every* feed so far. It is the parser's own running counter (`parser-offset`),
  exposed live as `parser-stream-offset` and on each result as
  `parser-result-stream-offset`. **It is not reset between messages or between
  feeds.** Only `parser-reset!` sets it back to 0 (`§12.5`); an HTTP-style message
  loop that reuses one parser without calling reset keeps a single monotonic
  offset across all messages (`§12.5:743`).

`parser-result-next` and `parser-result-consumed` are meaningful for
feed-originated results only (`§9.3:392-393`). On a `parser-finish!` result and
on the sticky short-circuit results, the constructor fills `next` with the
absolute stream offset and `consumed` with `0`; the accessors return those
values without raising (the "enforce where meaningful" note of `§9.3:425` is not
implemented — the values are simply inapplicable there).

## 3. Parser statuses

`parser-result-status` returns one of five symbols. To a caller they mean:

- **`need-input`** — the whole supplied slice was consumed and the machine is
  waiting for more bytes. It does **not** imply that a logical message finished
  (`§12.3`). It is a feed-only status: it is returned when execution reaches an
  input-dependent node (byte/sequence dispatch, integer accumulate, counted
  consume) with the cursor at `end`, and the parser lifecycle returns to `ready`.
- **`paused`** — execution stopped at a callback-requested pause or an explicit
  pause node. A feed pause leaves lifecycle `paused-feed` and `next` at the first
  unconsumed byte; an EOF pause leaves lifecycle `paused-finish`, for which
  `next`/`consumed` are inapplicable and only the stream offset is exposed
  (`§12.3`). The caller must call `parser-resume!` before feeding or finishing
  again.
- **`stopped`** — a successful explicit one-shot terminal. Sticky until reset.
- **`finished`** — the successful EOF terminal, reachable only through
  `parser-finish!` (`§10.6:616`). Sticky until reset.
- **`error`** — a declared machine error or a callback application error. Sticky
  until reset; `parser-result-error` carries the `parser-error` record (see §4),
  and it is `#f` on every non-error result.

Statuses are distinct from lifecycle values. `parser-lifecycle` reports the
state machine of `§12.1` — `ready`, `paused-feed`, `paused-finish`,
`finish-ready`, `stopped`, `error`, `finished`, plus the internal guards `busy`
and `poisoned`. Once a parser is `stopped`, `error`, or `finished`, a further
`parser-feed!`/`parser-finish!` short-circuits and re-returns that terminal
result consuming zero, offset unchanged (`§12.2:701`). Operations against a
`paused-*` or `finish-ready` state that the matrix forbids, a reentrant call
(`busy`), and a `poisoned` parser each raise a distinct coded contract condition;
only `parser-reset!` clears a poisoned parser.

## 4. Position kinds

`parser-error-position-kind` is one of `byte`, `boundary`, or `eof`
(`§12.7:760`), recording where in the stream the error sits. The stored offset is
always the absolute stream offset (`parser-error-offset`).

- **`byte`** — *at* the offending byte, at the current stream offset. Recorded
  when the failing node was entered over a `reexecute` edge, and for an integer
  accumulate that rejects the current digit — overflow does not consume the digit
  (`§12.7:768`, `§12.7:773`).
- **`boundary`** — a between-byte boundary. Recorded for an error edge taken
  after an `advance` (after the committed byte), and for a zero-width machine
  action or a callback failure (at the current stream offset) (`§12.7:769-770`). A
  callback-domain error always records `boundary` regardless of the loop's
  carried position kind (the constant `callback-failure-position` in
  `(byte-machine runtime)`), including the span boundary-flush error.
- **`eof`** — the EOF boundary at the final stream offset. Recorded for input
  truncated during `parser-finish!`: the machine default-EOF error, or an error
  reached while walking the eof-target chain (`§12.7:771`).

The position kind is initialized to `boundary` at the start of every feed and
finish (nothing has been committed yet), and a zero-width step carries the
current kind through unchanged. Position kind, source-node name, domain, code and
offset are compared across the two executors; the internal state id
(`parser-error-state-id`) is an executor-local debugging aid and is *not* compared
(`§12.7:777`).

> Known deviation (`§12.7:770`, tracked open in the plan): the field-action /
> machine-action arm records the loop's carried position kind rather than an
> unconditional `boundary`, so a machine-action error reached over a prior
> `reexecute` edge can report `byte` where `§12.7:770` specifies `boundary`.

## 5. `need-input` on a partial feed, and EOF at `parser-finish!`

`parser-feed!` and `parser-finish!` are different operations (`§12.4:723`), and an
empty feed is never EOF.

- **Partial feed → `need-input`.** When a feed reaches an input-dependent node
  with the cursor already at `end`, it returns `need-input` with `next` at the
  cursor, `consumed = next - start`, the stream offset unchanged, and lifecycle
  back to `ready`. A counted consume that runs out of input mid-count parks on the
  same node with `need-input`; when the remaining input exactly satisfies the
  count, completion wins and execution continues past the node in the same feed
  before any `need-input` (`§10.6:601-603`).
- **`parser-finish!` → EOF processing.** From the current state, `parser-finish!`
  runs the executor with the input exhausted. An input-dependent node takes its
  declared `eof-target` (a named node); a `#f` eof-target means the machine's
  declared default-EOF error (`§9.1:318`). Execution then follows the eof-target
  chain and the zero-width work along it until it reaches a finish node
  (→ `finished`), a pause (→ `paused`, lifecycle `paused-finish`), or an error
  node / the default-EOF error (→ `error`). A finish node is reachable only this
  way — the verifier rejects ordinary control flow into it.
- **Pausing during EOF.** A pause during finish yields `paused-finish`; after
  `parser-resume!` (which returns the symbol `finish-ready` and leaves lifecycle
  `finish-ready`), the caller calls `parser-finish!` again to continue the saved
  EOF path. Feeding bytes from `finish-ready` is prohibited. EOF processing admits
  no new bytes and must terminate in `finished` or `error` after finitely many
  resumes (`§12.4:729`). On every finish result `next` repeats the stream offset
  and `consumed` is `0` (§2).
