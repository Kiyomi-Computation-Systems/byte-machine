# Transition and cursor semantics

How a byte moves the parser, what the cursor and the absolute stream offset
mean, what each parser status tells a caller, and how `parser-feed!` and
`parser-finish!` differ at the end of the input.

Everything below describes the code — `(byte-machine runtime)`,
`(byte-machine interpret)`, and `(byte-machine private ir)`. Both executors —
the reference interpreter and a generated parser — behave identically here
except where a difference is called out.

---

## 1. The two edge modes

A byte-reading transition is an **edge** (`make-edge` in
`(byte-machine private ir)`), and every edge declares one of exactly two modes,
`advance` or `reexecute`. The mode decides what happens to the
current byte after the edge's target is chosen.

- **`advance`** commits the examined byte: it enters the target, moves the cursor
  forward by one, and increments the absolute stream offset by one. The
  byte is consumed; the parser will not see it again.
- **`reexecute`** enters the target *without* moving the cursor or the stream
  offset. The target observes the same current byte. This is how
  delimiter handling and span exclusion work without any pushback — there is no
  general rewind or backtracking. Peeking at a delimiter is expressed as a
  one-byte dispatch with a `reexecute` edge.

Edges with a mode occur on the byte-reading kinds only: a byte-dispatch node's
cases and its fallback (`byte-case-edge`, `byte-dispatch-node-fallback`), a
sequence-dispatch node's mismatch edge (`sequence-dispatch-node-mismatch`), and
an integer-accumulate node's non-digit fallback edge
(`integer-accumulate-node-nondigit-edge`). A sequence *case* carries a bare
target and no mode: a successful sequence always consumes every byte in it,
so only the mismatch edge has a choice to make. (A keyword table's no-match edge
carries a mode the same way.) Zero-width kinds
(field action, field branch, callback, span start/end) and a pause node's single
out-edge take no byte and have no mode. The interpreter's feed loop routes both
modes in one place (`route-byte-step!` inside `parser-feed!`) and, in doing so,
sets the position kind — see §4.

## 2. The cursor and the absolute stream offset

`parser-feed!` takes `(parser bytevector start end)` and reads the half-open
slice `[start,end)`; `0 <= start <= end <= bytevector-length` or it raises an
API-contract condition before any mutation. An empty
slice is a valid feed, never EOF.

- The **cursor** is a position *within the current slice*. It starts at `start`
  and advances one byte per `advance` edge (and by the committed count of a
  counted consume). It is reported relative to the supplied bytevector as
  `parser-result-next` — the first unconsumed index — with
  `parser-result-consumed` equal to `next - start`.
- The **absolute stream offset** is the total number of bytes committed across
  *every* feed so far. It is the parser's own running counter (`parser-offset`),
  exposed live as `parser-stream-offset` and on each result as
  `parser-result-stream-offset`. **It is not reset between messages or between
  feeds.** Only `parser-reset!` sets it back to 0; an HTTP-style message
  loop that reuses one parser without calling reset keeps a single monotonic
  offset across all messages.

`parser-result-next` and `parser-result-consumed` are meaningful for results of
a feed that ran. Elsewhere they are filled with placeholder values, which the
accessors return without raising: a `parser-finish!` result carries `next` equal
to the absolute stream offset and `consumed` equal to `0`, and a sticky
short-circuit result (see §3) carries `consumed` equal to `0` with `next` equal
to the call's `start` for a feed and to the stream offset for a finish.

## 3. Parser statuses

`parser-result-status` returns one of five symbols. To a caller they mean:

- **`need-input`** — the whole supplied slice was consumed and the machine is
  waiting for more bytes. It does **not** imply that a logical message finished
  It is a feed-only status: it is returned when execution reaches an
  input-dependent node (byte/sequence dispatch, integer accumulate, counted
  consume) with the cursor at `end`, and the parser lifecycle returns to `ready`.
- **`paused`** — execution stopped at a callback-requested pause or an explicit
  pause node. A feed pause leaves lifecycle `paused-feed` and `next` at the first
  unconsumed byte; an EOF pause leaves lifecycle `paused-finish`, for which
  `next`/`consumed` are inapplicable and only the stream offset is exposed.
  The caller must call `parser-resume!` before feeding or finishing
  again. `parser-result-error` stays `#f` (a pause is not an error); if the pause
  node — or the callback node whose callback returned `callback-pause` — declared
  an optional reason, `parser-result-pause` carries it as a `parser-error`-shaped
  `(code, reason)` value, else `#f`.
- **`stopped`** — a successful explicit one-shot terminal. Sticky until reset.
- **`finished`** — the successful EOF terminal, reachable only through
  `parser-finish!`. Sticky until reset.
- **`error`** — a declared machine error or a callback application error. Sticky
  until reset; `parser-result-error` carries the `parser-error` record (see §4),
  and it is `#f` on every non-error result.

Statuses are distinct from lifecycle values. `parser-lifecycle` reports the
parser's lifecycle state — `ready`, `paused-feed`, `paused-finish`,
`finish-ready`, `stopped`, `error`, `finished`, plus the internal guards `busy`
and `poisoned`. Once a parser is `stopped`, `error`, or `finished`, a further
`parser-feed!`/`parser-finish!` short-circuits and re-returns that terminal
result consuming zero, offset unchanged. An operation the lifecycle forbids
(feeding or finishing while `paused-feed` or `paused-finish`, feeding while
`finish-ready`, resuming a parser that is not paused), a reentrant call
(`busy`), and a `poisoned` parser each raise a distinct coded contract condition;
only `parser-reset!` clears a poisoned parser.

`parser-reset!` returns the parser to its just-constructed state: field values go
back to the initials `make-parser` started from, which for a settable field
are the embedder's overrides, not the declared initials — so a mode
chosen at construction survives a reset rather than silently reverting on the
first one.

## 4. Position kinds

`parser-error-position-kind` is one of `byte`, `boundary`, or `eof`,
recording where in the stream the error sits. The stored offset is
always the absolute stream offset (`parser-error-offset`).

- **`byte`** — *at* the offending byte, at the current stream offset. Recorded
  when the failing node was entered over a `reexecute` edge, and for an integer
  accumulate that rejects the current digit — overflow does not consume the digit.
- **`boundary`** — a between-byte boundary. Recorded for an error edge taken
  after an `advance` (after the committed byte), and for an error reached before
  the feed or finish has taken any edge. A callback-domain error always records
  `boundary` at the current stream offset regardless of the loop's carried
  position kind (the constant `callback-failure-position` in
  `(byte-machine runtime)`), including the span boundary-flush error.
- **`eof`** — the EOF boundary at the final stream offset. Recorded for input
  truncated during `parser-finish!`: the machine default-EOF error, or an error
  reached while walking the eof-target chain.

The position kind is initialized to `boundary` at the start of every feed and
finish (nothing has been committed yet). A zero-width step — a field action, a
field branch, a counted consume with a zero count — carries the current kind
through unchanged, because it does not move the parser in the input. So an
error reached through a field action's `error` target reports the kind the
preceding edge set: `byte` after a `reexecute` edge, `boundary` after an
`advance`, `eof` on an eof-target chain.

Position kind, source-node name, domain, code and
offset are compared across the two executors; the internal state id
(`parser-error-state-id`) is an executor-local debugging aid and is *not*
compared.

### The span an error abandons

An error that stops the parser with a span open abandons that span:
no final fragment is flushed and no completion is synthesized. The error
records it instead. `parser-error-span` names the span and
`parser-error-span-offset` is the stream offset where its withheld bytes begin,
both `#f` when no span was open. The bytes in
`[parser-error-span-offset, parser-error-offset)` are the ones the parser took
for the span and never delivered; every earlier byte of the span went out in a
fragment.

The position kind says where the error sits, not whether the range ends with a
refused byte. When the error node was entered over an `advance` edge — which
records `boundary` — the parser took the byte whose transition led to the error,
so it is the range's last byte; over a `reexecute` edge (`byte`) it was not
taken and is not in the range. But `boundary` is also recorded where no byte
was refused, and the range can then be empty: a span data callback that fails
records it, and was handed its bytes. Subtracting one "at `boundary`" is a rule
about one grammar, not about this record.

Both members are compared across the two executors, like the five above.

## 5. `need-input` on a partial feed, and EOF at `parser-finish!`

`parser-feed!` and `parser-finish!` are different operations, and an
empty feed is never EOF.

- **Partial feed → `need-input`.** When a feed reaches an input-dependent node
  with the cursor already at `end`, it returns `need-input` with `next` at the
  cursor, `consumed = next - start`, the stream offset unchanged, and lifecycle
  back to `ready`. A counted consume that runs out of input mid-count parks on the
  same node with `need-input`; when the remaining input exactly satisfies the
  count, completion wins and execution continues past the node in the same feed
  before any `need-input`.
- **`parser-finish!` → EOF processing.** From the current state, `parser-finish!`
  runs the executor with the input exhausted. An input-dependent node takes its
  declared `eof-target` (a named node); a `#f` eof-target means the machine's
  declared default-EOF error. Execution then follows the eof-target
  chain and the zero-width work along it until it reaches a finish node
  (→ `finished`), a pause (→ `paused`, lifecycle `paused-finish`), or an error
  node / the default-EOF error (→ `error`). A finish node is reachable only this
  way — the verifier rejects ordinary control flow into it.
- **Pausing during EOF.** A pause during finish yields `paused-finish`; after
  `parser-resume!` (which returns the symbol `finish-ready` and leaves lifecycle
  `finish-ready`), the caller calls `parser-finish!` again to continue the saved
  EOF path. Feeding bytes from `finish-ready` is prohibited. EOF processing admits
  no new bytes and must terminate in `finished` or `error` after finitely many
  resumes. On every finish result `next` repeats the stream offset
  and `consumed` is `0` (§2).
