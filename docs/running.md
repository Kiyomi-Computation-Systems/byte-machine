# Running a parser

Everything on this page comes from `(byte-machine runtime)`. It works the same
on a generated parser and on the [interpreter](testing.md).

## The parser's life

1. `make-parser` makes a parser from a compiled machine.
2. `parser-feed!` gives it bytes, as many times as you like.
3. `parser-finish!` tells it the input has ended.
4. `parser-reset!` makes it as good as new, ready for the next stream.

Each feed and finish returns a *result*: what happened, and where.

## Making a parser

```scheme
(make-parser compiled-machine callback-bindings context)
(make-parser compiled-machine callback-bindings context field-initials)
```

- `compiled-machine`: the value a generated library exports, or one made by
  `make-interpreted-machine`.
- `callback-bindings`: `(list (list 'name procedure) ...)`, or `'()`. See
  [Callbacks and spans](callbacks.md#binding-callbacks).
- `context`: any value. Every callback receives it, and
  `parser-user-context` returns it.
- `field-initials`: optional starting values for settable fields, as
  `'((name . value) ...)`. See [Fields and counts](fields.md#modes-fields-your-application-sets).

A parser is cheap to make and holds one stream's state. It is not safe to
use one parser from two threads at once.

## Feeding

```scheme
(parser-feed! parser bv start end)
```

Parses the bytes of `bv` from index `start` up to, not including, `end`. You
can feed part of a bigger buffer without copying it. The range must satisfy
`0 ≤ start ≤ end ≤ (bytevector-length bv)`, or `parser-feed!` raises before
doing anything.

An empty feed (`start = end`) is fine. It is not the end of input.

## Reading a result

| Accessor                        | Answers                                                                 |
|:--------------------------------|:------------------------------------------------------------------------|
| `parser-result-status`          | What happened: one of the five statuses below.                          |
| `parser-result-next`            | The index in `bv` of the first byte not consumed.                       |
| `parser-result-consumed`        | How many bytes this call consumed: `next − start`.                      |
| `parser-result-stream-offset`   | How many bytes this parser has consumed in total, across every feed.     |
| `parser-result-error`           | On `error`, the error record. Otherwise `#f`.                           |
| `parser-result-pause`           | On `paused`, the pause's reason, if it declared one. Otherwise `#f`.    |

`next` and `consumed` are about this call's bytevector. The stream offset is
about the whole stream: it counts from the parser's creation or last reset,
across feeds and across messages. Error offsets use the stream offset.

## The five statuses

**`need-input`**: every byte was used, and the parser is waiting for more.
Feed again. This does not mean a message has ended.

**`stopped`**: the parser reached a stop node. `next` is where it stopped;
the bytes from `next` on were not read.

**`finished`**: the input ended cleanly. Only `parser-finish!` can get here;
after that, a feed repeats it.

**`paused`**: the parser handed control back to you. Call `parser-resume!`,
then continue. See [Pausing](#pausing).

**`error`**: the input was wrong, or a callback failed. See [Errors](errors.md).

`stopped`, `finished` and `error` *stick*. Feeding or finishing again returns
the same status and error, consuming nothing, until you reset the parser.
The repeat's `next` is the new call's `start` for a feed, and the stream
offset for a finish.

## Finishing

```scheme
(parser-finish! parser)
```

Tells the parser no more bytes are coming. From the node it is waiting at, it
follows that node's end-of-input route (see
[Building machines](machines.md#end-of-input)) to a finish node, an error, or
a pause. A finish result has `consumed` 0 and `next` equal to the stream
offset; nothing was read.

You must call it yourself: a parser can't tell a quiet connection from a
closed one. In the words parser, `"abc"` then `parser-finish!` gives an
`unexpected-eof` error, because the line never got its newline.

## One parser, many messages

A stop node ends one message, not the stream. To parse the next message on
the same connection, reset the parser and feed it the rest:

```scheme
(define buf (string->utf8 "one\ntwo\n"))
(define r (parser-feed! parser buf 0 8))
(parser-result-status r)    ; => stopped
(parser-result-next r)      ; => 4

(parser-reset! parser)
(parser-feed! parser buf (parser-result-next r) 8)   ; parses "two\n"
```

## Pausing

A parser pauses at a pause node, or when a callback returns `callback-pause`.
The result's status is `paused`, and `parser-result-pause` holds the reason,
if the pause declared one. The reason is an error record (read it with
`parser-error-code` and `parser-error-reason`) but the pause is not an error.

To continue, resume, then feed the rest:

```scheme
(define r (parser-feed! parser bv 0 n))
;; status: paused. Do whatever needed doing, then:
(parser-resume! parser)                          ; => feed-ready
(parser-feed! parser bv (parser-result-next r) n)
```

A paused parser refuses to be fed or finished until you resume it.
`parser-result-next` tells you where to pick up. The parser keeps no copy of
the input, so feeding from `next` is how the bytes it didn't reach get to it.

A pause during `parser-finish!` works the same way, except that
`parser-resume!` answers `finish-ready` and you call `parser-finish!` again
instead of feeding. A parser that is finishing takes no more bytes.

What pauses are for: backpressure ("stop, my buffer is full"), and hand-offs
("the HTTP headers are done; this connection is now a WebSocket"). The parser
stops at a known byte, and you decide what happens to the rest.

## Resetting

```scheme
(parser-reset! parser)
```

Returns the parser to how `make-parser` left it: back at the entry node,
stream offset 0, no error, no open span, fields at their starting values
(including any you passed to `make-parser`). Callbacks and context are kept.
Reset is also the only way to recover a [poisoned](errors.md#a-callback-raised)
parser.

## Looking at a live parser

| Procedure              | Answers                                                         |
|:-----------------------|:----------------------------------------------------------------|
| `parser-lifecycle`     | Where the parser is in its life (table below).                  |
| `parser-stream-offset` | Bytes consumed so far.                                          |
| `parser-state-name`    | The name of the node the parser is at.                          |
| `parser-active-span`   | The open span's name, or `#f`.                                  |
| `parser-field-ref`     | A field's current value.                                        |
| `parser-user-context`  | The context passed to `make-parser`.                            |

The lifecycle says which operations are allowed:

| Lifecycle       | Meaning                                         | Allowed next                    |
|:----------------|:------------------------------------------------|:--------------------------------|
| `ready`         | Waiting for bytes.                              | feed, finish, reset             |
| `paused-feed`   | Paused during a feed.                           | resume, reset                   |
| `paused-finish` | Paused during a finish.                         | resume, reset                   |
| `finish-ready`  | Resumed from a finish pause.                    | finish, reset                   |
| `stopped`       | Reached a stop node.                            | reset; feed and finish repeat the result |
| `finished`      | Ended cleanly at end of input.                  | reset; feed and finish repeat the result |
| `error`         | Failed.                                         | reset; feed and finish repeat the result |
| `busy`          | Inside one of its own callbacks.                | reading only                    |
| `poisoned`      | A callback raised.                              | reset; reading still works      |

An operation the lifecycle doesn't allow raises. These are programming
mistakes, not input problems; see [Errors](errors.md#programming-mistakes).
