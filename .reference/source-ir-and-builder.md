# Source IR and builder reference

The construction API of `(byte-machine graph)`: the constructors a grammar author
calls to build a **source machine**, which `(byte-machine verify)` then checks and
`(byte-machine compile)` lowers and emits. Everything here is public and
procedural; the private tagged-vector representation is never constructed directly
(§27:1703). Every constructor takes a final `source-label` argument — an
author-supplied datum (or `#f`) carried through diagnostics for provenance; it is
shown as `label` below.

Constructors validate **local shape only** (a name is a legal symbol, an argument
is the right type). Cross-node properties — reachability, target existence, EOF
routing, span/callback consistency — are the verifier's job; see the
[verifier diagnostic catalog](verifier-diagnostic-catalog.md).

## The machine

```
(make-machine name entry fields callbacks spans errors nodes default-eof-error label)
```

- `name` — the machine's symbol, in the portable ASCII name grammar.
- `entry` — the name of the node execution starts at.
- `fields` — a list of `make-uint-field` declarations (may be `()`).
- `callbacks` — a list of `make-callback-declaration`s (may be `()`).
- `spans` — a list of `make-span-declaration`s (may be `()`).
- `errors` — a list of `make-error-declaration`s.
- `nodes` — the list of node descriptors below.
- `default-eof-error` — the name of the error declaration used when a node
  reading input hits end of input and declares no EOF target of its own.

## Edges

```
(make-edge target mode)          mode ∈ { advance , reexecute }
```

An edge names a target node and how the current byte is treated: `advance`
consumes it and moves on; `reexecute` re-presents the same byte to the target.
See [transition and cursor semantics](transition-and-cursor-semantics.md).

## Byte matchers

A byte-dispatch case matches with one of:

```
(make-exact-byte-matcher byte)            one byte value
(make-byte-range-matcher low high)        an inclusive range
(make-byte-set-matcher bytes)             an explicit set (a list of byte values)
(make-byte-complement-matcher matcher)    every byte the inner matcher does not match
(ascii-bytes string)                      helper: a string → its list of byte values
```

Predicates and accessors are exported for each (`exact-byte-matcher?`,
`byte-range-matcher-low`, …).

## Nodes

**Byte dispatch** — branch on the next byte.

```
(make-byte-dispatch-node name cases fallback eof-target label)
(make-byte-case matcher edge label)
```

`cases` is a list of `make-byte-case`; `fallback` is an `make-edge` taken when no
case matches; `eof-target` is a node name (or `#f` to use the machine default) for
end of input.

**Sequence dispatch** — match one of several fixed byte sequences.

```
(make-sequence-dispatch-node name cases mismatch eof-target label)
(make-sequence-case bytes target label)
```

`cases` is a list of `make-sequence-case` (each a list of byte values and a target
node); `mismatch` is an `make-edge`. No case may be a proper prefix of another
(the verifier rejects `ambiguous-sequence-prefix`).

**Terminals and control.**

```
(make-stop-node name label)              accept: parsing stops here
(make-finish-node name label)            clean end of input (reachable only over an EOF route)
(make-pause-node name continue-target label)   yield to the caller, resume at continue-target
(make-error-node name error-declaration label)  reject with the named declared error
```

**Fields.**

```
(make-uint-field name width initial label)   an unsigned integer field, `width` bits
(make-field-action-node name operation arguments next error label)
    operation ∈ { store , clear , increment , decrement , add , set-mask , clear-mask }
    (the infallible four — store, clear, set-mask, clear-mask — take error = #f;
     increment, decrement, add can overflow and require an error target)
(make-field-branch-node name predicate arguments true-target false-target label)
    predicate ∈ { equal , zero , nonzero , range , mask-any , mask-all , mask-none }
(make-integer-accumulate-node name field base digit-target nondigit-edge overflow-error eof-target label)
    base ∈ { 10 , 16 }
(make-counted-consume-node name field next eof-target label)
```

See [fields and overflow](field-and-overflow.md) for the operand shapes of each
operation and predicate, accumulation, and overflow behaviour.

**Callbacks and spans.**

```
(make-callback-declaration name kind required? branch-keys default-branch label)
    kind ∈ { event , decision , span-data , span-complete }
(make-span-declaration name data-callback complete-callback label)
(make-callback-node name callback continue-target branch-targets pause-continuation label)
(make-span-start-node name span next label)
(make-span-end-node name span next label)
(make-error-declaration name code reason label)
```

A callback node names a declared callback; a `decision` callback returns one of
its declared `branch-keys` (routed through `branch-targets`) or the reserved
`continue`/`pause` outcomes. Spans mark a byte range and are delivered to their
declared `span-data` / `span-complete` callbacks. See the
[callback and span lifetime reference](callback-span-lifetime.md).

## From a built machine to a parser

```scheme
(import (byte-machine graph) (byte-machine verify) (byte-machine compile))
(define m (make-machine ...))              ; construct
(verify-machine m)                          ; check (raises on a defect)
(define c (compile-machine m '()))          ; verify + lower + compile
(compilation-ok? c)                         ; => #t
```

`compile-machine` verifies internally, so emission cannot bypass verification
through the public API (§26:1672). To emit the generated library, and to run it,
see the [generated-code integration guide](generated-code-integration-chez.md).
A worked end-to-end program is in
[`examples/generate-simple-machine/`](../examples/generate-simple-machine/).
