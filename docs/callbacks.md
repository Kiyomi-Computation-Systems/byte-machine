# Callbacks and spans

A parser talks to your code through *callbacks*: procedures you hand to
`make-parser`, which the parser calls as it goes. A *span* is a range of input
the machine marks out, like a header name or a body. The parser delivers a
span's bytes to a callback, in pieces, as they arrive.

## The four kinds

Every callback is declared in the machine, with one of four kinds:

| Kind            | Called by                  | Receives                             | May return                         |
|:----------------|:---------------------------|:-------------------------------------|:-----------------------------------|
| `event`         | a callback node            | `(parser context)`                   | continue, pause, failure           |
| `decision`      | a callback node            | `(parser context)`                   | continue, pause, failure, a branch key |
| `span-data`     | a span, for each fragment  | `(parser context bv from to)`        | continue, pause, failure           |
| `span-complete` | a span, when it ends       | `(parser context)`                   | continue, pause, failure           |

`context` is whatever you passed to `make-parser`. byte-machine never copies
or looks inside it, so it can be a mutable record holding your state.

## Declaring a callback

```scheme
(make-callback-declaration name kind required? branch-keys default-branch label)
```

- `required?`: if `#t`, `make-parser` refuses to make a parser without a
  binding for it. If `#f`, you may leave it out.
- `branch-keys`: for a `decision`, the symbols it may answer. `'()` for the
  other kinds. `continue` and `pause` are reserved.
- `default-branch`: for an optional `decision`, the key to take when it isn't
  bound. `#f` otherwise.

An optional callback you don't bind costs nothing: an `event` continues, a
`decision` takes its default branch, and a span's bytes go nowhere.

## Binding callbacks

```scheme
(make-parser compiled-machine
  (list (list 'on-word (lambda (parser context bv from to) callback-continue))
        (list 'on-word-end (lambda (parser context) callback-continue)))
  context)
```

Each binding is a two-element list, `(name procedure)`. A name the machine
doesn't declare, a name bound twice, or a missing required callback makes
`make-parser` raise. A typo can't silently switch a callback off.

## What a callback returns

| Return                                | Meaning                                                  |
|:--------------------------------------|:---------------------------------------------------------|
| `callback-continue`                   | Carry on.                                                |
| `callback-pause`                      | Pause the parser after this callback. See [Running a parser](running.md#pausing). |
| a branch key symbol                   | `decision` callbacks only: take that branch.             |
| `(make-callback-failure code detail)` | Stop with an error. `code` is a name, spelled like a node name; `detail` is any value, or `#f`. |

`callback-continue` and `callback-pause` are fixed values. Return them; don't
build new ones. Anything else is a contract violation, reported as an error
with code `callback-contract-violation`.

A decision callback picks a path:

```scheme
;; The machine: ask `allow`, then go to `space` on yes or `deny` on no.
(make-callback-declaration 'allow 'decision #t '(yes no) #f #f)
(make-callback-node 'ask 'allow 'space (list (list 'yes 'space) (list 'no 'deny)) 'space #f)

;; Your code:
(list 'allow (lambda (parser context) (if (method-allowed? context) 'yes 'no)))
```

## Spans

```scheme
(make-span-declaration name data-callback complete-callback label)
(make-span-start-node name span next label)
(make-span-end-node name span next label)
```

A span declaration names its `span-data` callback and, optionally, its
`span-complete` callback (`#f` for none). A span-start node opens the span; a
span-end node closes it. Every byte consumed while the span is open belongs to
it.

Only one span is open at a time. The verifier checks that every path agrees
about which span is open at each node, that a span is never opened twice or
closed when it isn't open, and that no span is still open at a stop or
finish.

## Fragments

A span's bytes arrive as zero or more *fragments*, each a call to the data
callback with a range `[from, to)` of the bytevector you fed, followed by one
call to the complete callback. Where the fragments split depends only on your
feeds:

- When a span ends, the bytes since the last fragment are delivered.
- When a feed returns `need-input` with a span still open, the bytes so far
  are delivered. The span stays open, and the next fragment starts at the
  next feed.
- Empty fragments are not delivered, with one exception: a span that ends
  having delivered nothing at all gets one empty fragment. So an empty span
  is still visible.

The words parser fed `"hello wor"` then `"ld\n"` delivers `"wor"` and `"ld"`
for one word. Fed in one piece it delivers `"world"`. On every path that
doesn't end in an error, the joined bytes are the same however the input was
split. **Don't treat a fragment as a token**; join them if you need the
token.

An error is different: the bytes a span took since its last fragment are not
delivered, and the error says where they start. See
[Errors](errors.md#the-span-an-error-cuts-short).

## The lifetime rule

**The range a data callback receives is yours only while the callback runs.**
When it returns, the parser may be handed a different buffer, or you may
reuse this one. Copy what you need, inside the callback:

```scheme
(lambda (parser context bv from to)
  (let ((copy (make-bytevector (- to from))))
    (bytevector-copy! bv from copy 0 (- to from))
    (remember! context copy)
    callback-continue))
```

Keeping `bv`, or the triple `(bv from to)`, keeps a reference to memory that
is no longer yours.

In return, the runtime keeps nothing of yours. Once `parser-feed!` returns,
the parser holds no reference to the bytevector you fed, so you may reuse or
overwrite it at once. A paused parser holds no buffer either. The test suite
checks this with weak references, on both the generated parser and the
interpreter.

Three things you control can still hold your bytes: a closure you bound as a
callback, the context you passed to `make-parser`, and the `detail` of a
callback failure, which the parser keeps in its error until reset. If you put
a bytevector in one of those, it stays alive as long as the parser does.

## What a callback sees

Inside a callback the parser is in a consistent state:

- `parser-field-ref` answers with every field change made so far. Fields are
  read-only.
- `parser-stream-offset` counts every byte consumed so far.
- `parser-state-name` names the node that called you: the callback node, or
  the span-end node for a span. For the fragment delivered at the end of a
  feed, it names the node the parser stopped on.
- `parser-active-span` names the open span, or is `#f`. In a data callback
  it names your span; in a complete callback the span is already closed.
- `parser-lifecycle` is `busy`. Feeding, finishing, resuming or resetting the
  parser from inside its own callback raises.

## Pausing from a callback

A callback that returns `callback-pause` pauses the parser after its own
event has been handled. Resuming never repeats it: the fragment is not
delivered twice. A data callback accepts or refuses its whole range; there is
no "take only some of it". For finer control, feed smaller pieces.

Only a span's own data callback may pause while that span is open. The
verifier rejects any pause node or callback node that can run inside an open
span (`span-active-at-pause`). That rule is what lets a paused parser hold no
input.

## When a callback raises

Expected failures go through the return value. If a callback raises an
exception, or escapes with a continuation, the exception passes out of
`parser-feed!` and the parser is *poisoned*: feeding, finishing or resuming
it raises. The reading accessors still answer, and `parser-reset!` makes it
usable again. See [Errors](errors.md#a-callback-raised).
