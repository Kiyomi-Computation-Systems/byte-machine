# The verifier

Before byte-machine writes any code, it checks the machine. The verifier
looks for machines that would misbehave at run time: loop without reading,
get stuck, end in the wrong place, or deliver spans wrongly. It reports every
problem it finds, each with a code and the node it concerns.

You can't skip it. `compile-machine` runs it, and a machine that fails can't
be rendered. The [interpreter](testing.md) refuses an unverified machine
too.

## Running it

```scheme
(import (byte-machine verify))

(define v (verify-machine machine))
(verification-ok? v)            ; #t or #f
(verification-diagnostics v)    ; a list, empty when ok
```

`verify-machine` doesn't raise on a bad machine: problems are data. Even a
value that isn't a machine at all comes back as an `invalid-shape`
diagnostic.

Each diagnostic has:

| Accessor                  | Answers                                                         |
|:--------------------------|:----------------------------------------------------------------|
| `diagnostic-code`         | The code symbol, listed below.                                  |
| `diagnostic-node`         | The node (or other named thing) it concerns, or `#f`.           |
| `diagnostic-message`      | A sentence describing the problem.                              |
| `diagnostic-path`         | For loops, end-of-input problems and span-state problems, the path of node names that shows it; else `#f`. |
| `diagnostic-severity`     | `error`.                                                        |
| `diagnostic-machine`      | The machine's name.                                             |
| `diagnostic-edge`         | For `non-eof-into-finish`, which edge of the node leads into the finish (`case`, `fallback`, ...); else `#f`. |
| `diagnostic-declarations` | Declarations involved, such as two that share a name.           |

## An example

[Usage](usage.md#2-verify-it) shows one: an early draft of the words parser
had a loop of `reexecute` edges, and the verifier reported

```scheme
(diagnostic-code d)   ; => zero-progress-cycle
(diagnostic-node d)   ; => between
(diagnostic-path d)   ; => (between open in-word close between)
```

It reports the same loop once for each node on it, so the draft drew four
diagnostics. Fix the loop and all four go.

## The rules, in plain words

**Every node can be reached, and every name points at something.** No
orphan nodes, no edges to missing nodes, no undeclared errors, callbacks,
spans or fields.

**Every loop reads a byte.** A cycle made only of `reexecute` edges and nodes
that read nothing could spin forever. The verifier doesn't reason about which
bytes take which edge; it requires each cycle to consume at least one byte.

**At each byte, one choice.** Byte-dispatch cases can't overlap, sequence
cases can't be prefixes of each other, and keyword entries can't repeat.

**End of input ends properly.** From any place a parser can be waiting,
`parser-finish!` must reach a finish node or an error, never a stop node,
and never a loop. A finish node can only be reached at end of input.

Which places count as "waiting" catches people out. It's every node that
reads input, plus the entry node, every pause node, every callback node, and
every span-end node. A span end counts because its data callback can pause
there. So after a span end, the parser must read a byte before it reaches a
stop. In the words parser, `close` goes to `after-word`, which reads the space
or newline, rather than straight to `done`.

**Spans nest correctly.** Every path into a node agrees on which span is
open; a span is opened only when none is, and closed only when it is open; no
span is open at a stop or finish; and nothing but the span's own data
callback can pause while it is open.

**Fields are used correctly.** Every operand fits the field, every
operation has the right number of operands, and a counted-consume counter is
not a settable field.

## Every diagnostic code

### Shape and names

- `invalid-shape`: the argument isn't a machine. (A malformed node or
  declaration is refused earlier, by its constructor.)
- `invalid-name`: a name or error code isn't lowercase ASCII letters, digits
  and hyphens starting with a letter, or is an R6RS keyword such as `begin`;
  or a reason string or label holds something other than printable ASCII
  and newlines.
- `duplicate-name`: two nodes share a name.
- `duplicate-error-declaration`: two error declarations share a name.
- `missing-target`: an edge names a node that doesn't exist.
- `missing-error-declaration`: an error node, or a pause's or callback
  node's reason, names an undeclared error.
- `overlapping-cases`: two byte-dispatch cases match a common byte.
- `ambiguous-sequence-prefix`: one sequence case is a prefix of another.
- `duplicate-keyword`: two keyword-table entries are the same bytes.
- `case-insensitive-keyword-collision`: two entries of a case-insensitive
  keyword table are the same once case is ignored.

### Fields

- `invalid-field-declaration`: a field declaration is malformed, or two
  fields share a name.
- `invalid-field-operand`: a field action or branch has the wrong number of
  operands, an operand that doesn't fit the field, a `range` with low above
  high, or names an undeclared field.
- `settable-consume-counter`: a counted consume counts down a settable field.

### Reachability and end of input

- `unreachable-node`: no execution can reach the node.
- `zero-progress-cycle`: a loop that never consumes a byte.
- `invalid-eof-target`: an end-of-input target names no valid node, or the
  machine's default end-of-input error is not declared.
- `non-eof-into-finish`: a byte edge leads into a finish node.
- `eof-reachable-stop`: from a place a parser can wait, end of input reaches
  a stop node.
- `eof-zero-progress-cycle`: an end-of-input route loops without reaching an
  end.

### Callback and span declarations

- `duplicate-callback-declaration`: two callback declarations share a name.
- `duplicate-span-declaration`: two span declarations share a name.
- `duplicate-branch-key`: a decision callback lists a branch key twice.
- `reserved-branch-key`: a branch key is `continue` or `pause`.
- `invalid-callback-declaration`: a callback declaration contradicts
  itself, for example an optional decision callback without a valid default
  branch.
- `missing-callback-declaration`: a span or node names an undeclared
  callback.
- `invalid-span-callback`: a span names a callback of the wrong kind.
- `unreferenced-callback-declaration`: a span-kind callback that no span
  uses, so nothing could ever call it.
- `missing-span-declaration`: a span node names an undeclared span.

### Calling callbacks

- `invalid-callback-invocation`: a callback node names an undeclared branch
  key, leaves out a target for a declared one, or calls a span-kind
  callback.

### Span state

- `invalid-span-state`: a span start opens a span while one is open, or a
  span end closes a span that isn't the open one.
- `inconsistent-span-state`: two paths into a node disagree about which span
  is open.
- `span-active-at-pause`: a pause node or callback node can run with a span
  open.
- `span-active-at-exit`: a span is still open at a stop or finish.

This list is checked against the verifier's source by the test suite, so it
can't fall out of date unnoticed.
