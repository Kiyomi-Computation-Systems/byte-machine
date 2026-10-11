# Fields and counts

Most protocols carry numbers: a length, a status code, a version, a set of
flags. A *field* is a number the machine keeps while it parses. Nodes read
numbers from the input into fields, test them, change them, and use them to
count bytes.

There is one kind of field: an unsigned integer of 8, 16, 32 or 64 bits.
Every operation that could go out of range is checked, and every overflow
goes somewhere you named. Nothing wraps silently.

## Declaring a field

```scheme
(make-uint-field name width initial label)
(make-uint-field name width initial settable? label)
```

- `width` is `8`, `16`, `32` or `64`.
- `initial` is the value a new parser starts with, from `0` up to the
  largest value the width holds (`255` for 8 bits).
- `settable?` (default `#f`) lets your application choose the starting value
  when it makes a parser. See [Modes](#modes-fields-your-application-sets).

Fields go in `make-machine`'s third argument:

```scheme
(make-machine 'netstring 'len
  (list (make-uint-field 'len 32 0 #f))
  ...)
```

## A worked example: netstrings

A [netstring](https://cr.yp.to/proto/netstrings.txt) is a length, a colon,
that many bytes, and a comma: `5:hello,`. Parsing one takes two field nodes:
one reads the length, the other consumes exactly that many bytes.

```scheme
(make-machine 'netstring 'len
  (list (make-uint-field 'len 32 0 #f))
  (list (make-callback-declaration 'on-body 'span-data #t '() #f #f))
  (list (make-span-declaration 'body 'on-body #f #f))
  (list (make-error-declaration 'too-big 'length-overflow "length does not fit in 32 bits" #f)
        (make-error-declaration 'no-colon 'expected-colon "expected a digit or ':'" #f)
        (make-error-declaration 'no-comma 'expected-comma "expected ',' after the body" #f)
        (make-error-declaration 'eof 'unexpected-eof "input ended early" #f))
  (list
   ;; Read decimal digits into len. A non-digit goes to `colon`, unconsumed.
   (make-integer-accumulate-node 'len 'len 10 'len (make-edge 'colon 'reexecute) 'overflow #f #f)
   (make-byte-dispatch-node 'colon
     (list (make-byte-case (make-exact-byte-matcher (char->integer #\:)) (make-edge 'open 'advance) #f))
     (make-edge 'not-colon 'reexecute) #f #f)
   ;; Consume exactly len bytes as the span `body`.
   (make-span-start-node 'open 'body 'body #f)
   (make-counted-consume-node 'body 'len 'close #f #f)
   (make-span-end-node 'close 'body 'comma #f)
   (make-byte-dispatch-node 'comma
     (list (make-byte-case (make-exact-byte-matcher (char->integer #\,)) (make-edge 'done 'advance) #f))
     (make-edge 'not-comma 'reexecute) #f #f)
   (make-stop-node 'done #f)
   (make-error-node 'overflow 'too-big #f)
   (make-error-node 'not-colon 'no-colon #f)
   (make-error-node 'not-comma 'no-comma #f))
  'eof #f)
```

Feed it `"5:he"` and then `"llo,"`, with an `on-body` callback that prints the
fragment and `(parser-field-ref parser 'len)`:

```text
body "he" len 3
"5:he" -> need-input
body "llo" len 0
"llo," -> stopped
```

The counted consume subtracts the bytes it takes from `len`, so the field
says how many are still to come. Errors land where you'd expect:

| Input              | Result                                              |
|:-------------------|:----------------------------------------------------|
| `"99999999999:x"`  | `length-overflow` at offset 9: the tenth digit doesn't fit |
| `"12x"`            | `expected-colon` at offset 2, the `x`               |

## Reading a number: integer accumulate

```scheme
(make-integer-accumulate-node name field base digit-target nondigit-edge overflow-error eof-target label)
```

Reads one byte. `base` is `10` or `16` (hex accepts `0`-`9`, `a`-`f`, `A`-`F`).

- A **digit** sets `field` to `field × base + digit` and goes to
  `digit-target`, consuming the byte. Point `digit-target` back at the node
  itself to read many digits.
- A **non-digit** takes `nondigit-edge`. It is an edge, so you choose:
  usually `reexecute`, so the next node sees the delimiter.
- **Overflow** goes to the node `overflow-error`, without consuming the digit
  and without changing the field. The check happens before the arithmetic,
  so it never depends on the host's integer size.
- **End of input** goes to `eof-target`, or the machine default if `#f`.

The node does not clear the field first. Clear it yourself (see below) if a
machine reads more than one number into the same field.

## Counting bytes: counted consume

```scheme
(make-counted-consume-node name field next eof-target label)
```

Consumes up to `field` bytes in one step and subtracts what it took. Then:

- If the field reaches zero, it goes to `next`, in the same feed.
- If the feed runs out first, the result is `need-input`, and the next feed
  carries on counting.
- If the field is already zero, it goes straight to `next`.

It cannot underflow, so it has no error target. This is how a parser reads a
`Content-Length` body without looking at each byte.

## Changing a field: field actions

```scheme
(make-field-action-node name operation arguments next error label)
```

`arguments` starts with the field's name, followed by the operation's operands.

| Operation    | `arguments`       | Effect                          | Can fail? |
|:-------------|:------------------|:--------------------------------|:---------:|
| `store`      | `(field value)`   | field := value                  | no        |
| `clear`      | `(field)`         | field := 0                      | no        |
| `increment`  | `(field)`         | field := field + 1              | yes       |
| `decrement`  | `(field)`         | field := field − 1              | yes       |
| `add`        | `(field value)`   | field := field + value          | yes       |
| `set-mask`   | `(field mask)`    | turn on the bits in mask        | no        |
| `clear-mask` | `(field mask)`    | turn off the bits in mask       | no        |

An action that can fail needs an `error` node; one that can't takes `#f`. If
the result would be out of range, the field is left as it was and the parser
goes to `error`. A field action reads no input.

```scheme
;; Count headers in an 8-bit field. `too-many` is reached only if the count
;; would pass 255; a smaller limit is a field branch (below) after it.
(make-field-action-node 'count-header 'increment '(headers) 'check-headers 'too-many #f)
```

## Testing a field: field branches

```scheme
(make-field-branch-node name predicate arguments true-target false-target label)
```

| Predicate   | `arguments`         | True when                        |
|:------------|:--------------------|:---------------------------------|
| `equal`     | `(field value)`     | field = value                    |
| `zero`      | `(field)`           | field = 0                        |
| `nonzero`   | `(field)`           | field ≠ 0                        |
| `range`     | `(field low high)`  | low ≤ field ≤ high               |
| `mask-any`  | `(field mask)`      | some bit of mask is on           |
| `mask-all`  | `(field mask)`      | every bit of mask is on          |
| `mask-none` | `(field mask)`      | no bit of mask is on             |

Both targets are required. A field branch reads no input.

## Modes: fields your application sets

Some choices belong to the application, not the input: "parse a request or a
response", "allow lenient line endings". Declare the field *settable* and
pass its starting value to `make-parser`:

```scheme
(make-uint-field 'strict 8 0 #t #f)        ; settable, default 0

(make-parser compiled-machine callbacks context '((strict . 1)))
```

Then branch on it with a field branch. One generated parser serves every
mode, and two parsers made from it can run in different modes at once.

The override is checked when the parser is made: an unknown field, a field
not declared settable, a repeated name or an out-of-range value raises.
`parser-reset!` restores the value you passed, not the declared one, so the
mode survives a reset. A settable field may not be a counted-consume
counter.

## Reading fields from your code

```scheme
(parser-field-ref parser 'len)    ; => 3
```

Works from inside a callback and outside one. Fields are read-only to your
code: there is no setter, so the machine's own nodes are the only writers.
Asking for a field the machine doesn't declare raises.

## What the verifier checks

The constructors check that an operation name is real and that the
`error` slot is `#f` exactly when the operation can't fail. The verifier
checks the rest: that every field a node names is declared, that operand
counts are right, that values fit the field's width, and that a `range` has
`low ≤ high`. Each failure is an `invalid-field-operand` diagnostic. See
[The verifier](verifier.md).
