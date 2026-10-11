# Building machines

A machine is a graph of *nodes*. Each node is a state the parser can be in.
Some nodes read a byte and choose where to go next. Others do one thing
without reading anything (start a span, call your code, change a number) and
move on. A few end the parse.

Everything here comes from `(byte-machine graph)`. Constructors check only
their own arguments: a name is a valid symbol, a byte is between 0 and 255.
Whether the graph as a whole makes sense is the [verifier](verifier.md)'s job.

## The machine

```scheme
(make-machine name entry fields callbacks spans errors nodes default-eof-error label)
```

| Argument            | What it is                                                                           |
|:--------------------|:-------------------------------------------------------------------------------------|
| `name`              | The machine's name. The generated library is called `(generated name)`.              |
| `entry`             | The node the parser starts at.                                                       |
| `fields`            | Unsigned integer fields; see [Fields and counts](fields.md). Often `'()`.            |
| `callbacks`         | Callback declarations; see [Callbacks and spans](callbacks.md). Often `'()`.         |
| `spans`             | Span declarations. Often `'()`.                                                      |
| `errors`            | Error declarations: every error the machine can report.                              |
| `nodes`             | Every node, in any order.                                                            |
| `default-eof-error` | The error used when input ends at a node that names no end-of-input target of its own. |
| `label`             | Your own tag for this value. See below.                                              |

## Names and labels

Every name (machine, node, field, callback, span, error, branch key) is a
symbol made of lowercase ASCII letters, digits and hyphens, starting with a
letter: `header-name`, `crlf2`. It may not be an R6RS keyword such as
`begin`, `if`, `do` or `let`. Names end up as identifiers in generated code,
so the rule keeps them portable.

The machine, node, case and declaration constructors end with a *label*:
`#f`, or a symbol or string of printable ASCII (newlines allowed). It means
nothing to byte-machine. It travels with the value into diagnostics, so you
can point a problem back at your own grammar: a line number, a rule name,
whatever helps. Edges and matchers take no label.

## Errors

```scheme
(make-error-declaration name code reason label)
(make-error-node name error-declaration label)
```

An error declaration names an outcome: a `code` symbol your application can
match on, and a `reason` string for people. An error node, when reached, ends
the parse with that error. Several error nodes can share one declaration.

```scheme
(make-error-declaration 'bad-version 'unsupported-version "expected HTTP/1.0 or HTTP/1.1" #f)
```

## Edges

```scheme
(make-edge target mode)     ; mode is 'advance or 'reexecute
```

An edge says where to go after a node reads a byte, and what to do with the
byte:

- **`advance`** consumes it. The target sees the next byte.
- **`reexecute`** does not. The target sees the same byte.

There is no backtracking. A byte can be looked at again only while it is the
current byte: through a `reexecute` edge, or when a keyword table's match or
an integer accumulate's overflow leaves it for the next node. `reexecute` is
how you peek at a delimiter without eating it, and how a span can stop just
before the byte that ended it.

## Matchers

A matcher is a set of bytes:

```scheme
(make-exact-byte-matcher 58)                     ; the byte 58, ':'
(make-byte-range-matcher 48 57)                  ; '0' to '9', inclusive
(make-byte-set-matcher (ascii-bytes " \t"))      ; space or tab
(make-byte-complement-matcher m)                 ; every byte m doesn't match
```

`ascii-bytes` turns an ASCII string into a list of byte values; it refuses
any other character.

## Nodes that read a byte

### Byte dispatch

```scheme
(make-byte-dispatch-node name cases fallback eof-target label)
(make-byte-case matcher edge label)
```

Reads one byte and takes the edge of the case that matches it, or the
`fallback` edge if none does. Cases may not overlap. This is the workhorse:
most machines are mostly byte dispatches.

### Sequence dispatch

```scheme
(make-sequence-dispatch-node name cases mismatch eof-target label)
(make-sequence-case bytes target label)
```

Matches one of several fixed byte strings and consumes it whole:

```scheme
(make-sequence-dispatch-node 'version
  (list (make-sequence-case (ascii-bytes "HTTP/1.0") 'version-done #f)
        (make-sequence-case (ascii-bytes "HTTP/1.1") 'version-done #f))
  (make-edge 'bad-version 'reexecute) #f #f)
```

The match can span feeds: `"HTTP/"` then `"1.0"` works. When a byte fails to
match, the parser takes the `mismatch` edge at that byte; the bytes before it
stay consumed. `"HTTX"` reaches `bad-version` at offset 3, the `X`.

No case may be a prefix of another (`GET` and `GETX`): when the input reads
`GET`, the parser couldn't tell whether to stop. Use a keyword table for that.

### Keyword table

```scheme
(make-keyword-table-node name entries no-match eof-target case-insensitive? label)
(make-keyword-entry bytes target label)
```

Like a sequence dispatch, but entries *may* be prefixes of each other, and
matching can ignore ASCII case. HTTP methods are the classic use:

```scheme
(make-keyword-table-node 'method
  (list (make-keyword-entry (ascii-bytes "GET") 'method-done #f)
        (make-keyword-entry (ascii-bytes "GET-ALL") 'method-done #f)
        (make-keyword-entry (ascii-bytes "PUT") 'method-done #f))
  (make-edge 'unknown-method 'reexecute) #f #t #f)
```

The walk reads forward one byte at a time and never backs up. It follows the
longest keyword the input can still become. It accepts a keyword when the
next byte can't extend the match and the bytes so far spell a whole keyword.
That next byte is **not** consumed: the target sees it.

- `"GET "` matches `GET`; the space goes to `method-done`.
- `"get-all "` matches `GET-ALL`, because the table is case-insensitive.
- `"POST"` fails at the `O`: no entry starts `PO`, so the `no-match` edge is
  taken there.
- `"GET-A "` fails at the space. The walk had committed to `GET-ALL`, and it
  does not fall back to the shorter `GET` it passed on the way.

A keyword is never accepted at end of input, because no byte has closed it
yet: `"GET"` followed by `parser-finish!` goes to the EOF target. Case folding
covers `A`-`Z` and `a`-`z` only.

### Number and count nodes

`make-integer-accumulate-node` reads a decimal or hex number into a field,
and `make-counted-consume-node` consumes as many bytes as a field says. Both
are on [Fields and counts](fields.md).

## End of input

Every node that reads input takes an `eof-target`: the node to go to if the
input ends while the parser is waiting there. `#f` means the machine's
`default-eof-error`.

Input ends when you call `parser-finish!`, never when a feed is empty or short.
From the EOF target the parser follows the route (through nodes that read
nothing, and through other reading nodes' own EOF targets) until it reaches
one of:

- a **finish node**, `(make-finish-node name label)`: a clean end. This is the
  only way to reach a finish node; the verifier rejects any byte edge into one.
- an **error node**, or the default EOF error: the input ended too early.
- a **pause node**: the parser yields, and `parser-finish!` continues the EOF
  route after you resume.

A stop node may not be reachable this way: input that ends must end in a
finish or an error.

## Nodes that read nothing

These do their one thing and move on without touching the input.

```scheme
(make-span-start-node name span next label)
(make-span-end-node name span next label)
```

Open and close a span. See [Callbacks and spans](callbacks.md).

```scheme
(make-callback-node name callback continue-target branch-targets pause-continuation label)
(make-callback-node name callback continue-target branch-targets pause-continuation reason label)
```

Call an `event` or `decision` callback and route on its answer.
`branch-targets` maps a decision callback's answers to nodes, as
`(list (list 'key 'target) ...)`; it is `'()` for an event. If the callback
asks to pause, the parser resumes at `pause-continuation`. The optional
`reason` names an error declaration reported with the pause.

```scheme
(make-field-action-node name operation arguments next error label)
(make-field-branch-node name predicate arguments true-target false-target label)
```

Change a field, or test one. See [Fields and counts](fields.md).

## Nodes that stop

```scheme
(make-stop-node name label)
```

A successful end in the middle of the input: "this message is done". The
result says `stopped` and reports where the parser stopped. Bytes after that
point were not read.

```scheme
(make-finish-node name label)
```

A successful end of input. Reachable only from an EOF target.

```scheme
(make-pause-node name continue-target label)
(make-pause-node name continue-target reason label)
```

Hands control back to your code with status `paused`. After
`parser-resume!`, the parser carries on at `continue-target`. `reason` is an
optional error declaration, reported in the result so your code knows why it
paused. See [Running a parser](running.md#pausing).

```scheme
(make-error-node name error-declaration label)
```

Ends the parse with an error. See [Errors](errors.md).

## Reading a machine back

`(byte-machine graph)` is for building. A few predicates and accessors are
exported (for matchers, sequence cases, and the field, callback and span
declarations), but there is no general API for walking a built machine.
Keep your own description of the grammar if you need to inspect it.
