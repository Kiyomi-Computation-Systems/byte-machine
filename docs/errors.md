# Errors

Three different things can go wrong, and byte-machine reports each one
differently:

| What went wrong                  | How you find out                                     |
|:---------------------------------|:-----------------------------------------------------|
| The input broke the grammar.     | The result's status is `error`, with an error record. |
| A callback said no.              | The same, with the record's domain `callback`.       |
| Your code misused the API.       | The call raises an exception.                        |

The first two are about the data, and your program should handle them. The
third is a bug in the calling code. A machine that fails verification is a
fourth kind, caught before any parser exists; see [The verifier](verifier.md).

## The error record

When `parser-result-status` is `error`, `parser-result-error` returns a record:

| Accessor                     | Answers                                                              |
|:-----------------------------|:---------------------------------------------------------------------|
| `parser-error-domain`        | `machine` for a grammar error, `callback` for a callback failure.    |
| `parser-error-code`          | The code symbol, such as `unexpected-byte`. Match on this.           |
| `parser-error-reason`        | The human-readable reason string.                                    |
| `parser-error-detail`        | A callback failure's detail; `#f` for a grammar error.               |
| `parser-error-node-name`     | The node where it happened.                                          |
| `parser-error-offset`        | The stream offset where it happened.                                 |
| `parser-error-position-kind` | `byte`, `boundary` or `eof`: see below.                              |
| `parser-error-span`          | The span the error cut short, or `#f`.                               |
| `parser-error-span-offset`   | Where that span's undelivered bytes begin, or `#f`.                  |
| `parser-error-state-id`      | An internal state number, for debugging. It differs between the generated parser and the interpreter; don't compare it. |

For a grammar error, `code` and `reason` come from the error declaration the
error node names. A parser that hit an error stays in it: feeding again
returns the same result until `parser-reset!`.

A server typically maps codes to responses: `unexpected-byte` in a request
line to `400 Bad Request`, a length overflow to `413 Content Too Large`, and
so on. The code is a symbol you chose, so you can make that mapping as fine
as you like.

## Where the error is

`parser-error-offset` is a stream offset: bytes consumed since the parser was
made or reset, across every feed. `parser-error-position-kind` says how to
read it:

- **`byte`**: the error is *at* the byte at that offset. The node that raised
  it was reached by a `reexecute` edge, so the bad byte was looked at and not
  consumed. The words parser fed `"hi there!\n"` reports `unexpected-byte` at
  offset 8, the `!`.
- **`boundary`**: the error is *between* bytes: after an `advance`, before
  the feed or finish read anything, or after a callback.
- **`eof`**: the error happened while finishing. The offset is the end of the
  stream. The words parser fed `"abc"` then finished reports `unexpected-eof`
  at offset 3, kind `eof`, at node `in-word`.

## The span an error cuts short

An error with a span open doesn't flush the span's last bytes and doesn't call
its complete callback. Instead, the error says what was left:

- `parser-error-span` names the span.
- `parser-error-span-offset` is the stream offset where its undelivered bytes
  begin.

The bytes from `span-offset` up to `offset` were taken for the span and never
handed to you. Every earlier byte of the span reached the data callback in a
fragment.

Take a machine that reads a lowercase name up to a `:`, as a span. Feed it
`"ab"`, then `"cD:"`:

```text
fragment "ab"                 ; delivered when the first feed ended
"cD:" -> error invalid-name-byte at offset 3 (the D), kind byte
         span name, span-offset 2
```

The span took `c`, at offset 2, then failed on `D`. So `"ab"` was delivered,
and `"c"`, the range `[2, 3)`, was not. However the input is split, the
fragments plus that range always give the span's bytes up to the error. A
size limit counted that way doesn't depend on where the network split the
data.

The range can be empty: always at `parser-finish!` (the last feed already
flushed the span), and when a data callback fails (it was handed its bytes).

## A callback failure

A callback that returns `(make-callback-failure code detail)` stops the
parser with an error in the `callback` domain:

```scheme
(list 'on-word
      (lambda (parser context bv from to)
        (if (> (- to from) 64)
            (make-callback-failure 'word-too-long (- to from))
            callback-continue)))
```

The record's `code` is your code, `detail` is your detail, and `reason` is
`"callback failure"`. The position kind is always `boundary`. A callback
that returns anything other than a valid outcome produces the same kind of
error, with code `callback-contract-violation`.

The detail is kept in the parser's error until reset. Don't put the
bytevector you were handed in it; put a copy, or a number.

## A callback raised

Return a failure for problems you expect. If a callback raises an exception
or escapes through a continuation, the exception propagates out of
`parser-feed!` (or `parser-finish!`), and the parser is *poisoned*. A
poisoned parser can't tell what state it is in, so every later feed, finish
or resume raises. The reading accessors still answer, and `parser-reset!`
makes the parser usable again.

## Programming mistakes

Calls that break the API's rules raise an exception straight away, before
changing anything. Examples:

- feeding a range outside the bytevector;
- feeding or finishing a paused parser without resuming it;
- calling `parser-feed!` on a parser from inside its own callback;
- feeding, finishing or resuming a poisoned parser;
- `make-parser` with a missing required callback, an unknown callback name,
  or a bad field override;
- `parser-field-ref` with a field the machine doesn't declare;
- building a node with arguments of the wrong shape, such as an edge mode
  other than `advance` or `reexecute`;
- rendering a compilation that failed verification.

These conditions name the procedure and the rule that was broken. Their type
is internal: don't write code that recovers from them. Fix the call.

A generated library built for a different version of the generated-code
interface raises `generated-runtime ABI mismatch` when it loads, instead of
misbehaving. Regenerate it. See [Generated code](generating.md#versions).
