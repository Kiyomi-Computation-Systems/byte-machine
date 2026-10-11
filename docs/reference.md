# API reference

Every binding the five public libraries export, grouped by job. For
explanations and examples, start with [Usage](usage.md); this page answers
the narrower question of what a binding is called, what it takes, and where
it comes from.

## Modules

| Module | Purpose | Needed at run time? |
|---|---|:---:|
| `(byte-machine graph)` | Build machines: nodes, edges, matchers and declarations. | no |
| `(byte-machine verify)` | Check a machine and read its diagnostics. | no |
| `(byte-machine compile)` | Turn a checked machine into a generated library. | no |
| `(byte-machine interpret)` | Run a checked machine directly, for testing. | no |
| `(byte-machine runtime)` | Make parsers, feed them, and read results and errors. | yes |

Libraries under `(byte-machine private ...)` are not public.

## Conventions

Signatures use `->` to separate arguments from the result; it is notation,
not Scheme syntax. Two signatures for one binding are two arities. A *name*
is a symbol of lowercase ASCII letters, digits and hyphens that starts with a
letter and is not an R6RS keyword such as `begin`. A *label* is `#f`, or a
symbol or string of printable ASCII (newlines allowed), carried into
diagnostics; byte-machine gives it no meaning. A *byte* is an exact integer from 0 to 255. *Node
name* means the name of a node in the same machine.

Constructors check their own arguments and raise on a wrong shape; whether
the machine makes sense as a whole is checked by `verify-machine`. Runtime
procedures raise on a programming mistake, such as an invalid slice or an
operation the parser's lifecycle forbids; see [Errors](errors.md#programming-mistakes).

## Building a machine

### `make-machine` (procedure)

`(make-machine name entry fields callbacks spans errors nodes default-eof-error label) -> machine`

Builds a machine. `entry` is the node a parser starts at. `fields`,
`callbacks`, `spans`, `errors` and `nodes` are lists of the values the
constructors below return; any of the first three may be `'()`.
`default-eof-error` names the error declaration used when input ends at a node
that names no end-of-input target of its own.

**Available from:** `(byte-machine graph)`\
**Details:** [Building machines](machines.md#the-machine)

### `make-edge` (procedure)

`(make-edge target mode) -> edge`

An edge to the node `target`. `mode` is `advance` (consume the current
byte) or `reexecute` (hand the same byte to the target).

**Available from:** `(byte-machine graph)`\
**Details:** [Edges](machines.md#edges)

### `make-error-declaration` (procedure)

`(make-error-declaration name code reason label) -> error-declaration`

Declares an error. `code` is the symbol a parser error reports;
`reason` is a string for people.

**Available from:** `(byte-machine graph)`\
**Details:** [Errors](machines.md#errors)

### `make-error-node` (procedure)

`(make-error-node name error-declaration label) -> node`

A node that ends the parse with the named error.

**Available from:** `(byte-machine graph)`

### `make-stop-node` (procedure)

`(make-stop-node name label) -> node`

A node that ends the parse successfully in the middle of the input. The
result's status is `stopped`.

**Available from:** `(byte-machine graph)`

### `make-finish-node` (procedure)

`(make-finish-node name label) -> node`

A node that ends the parse successfully at end of input. The result's
status is `finished`. Reachable only from an end-of-input route.

**Available from:** `(byte-machine graph)`\
**Details:** [End of input](machines.md#end-of-input)

### `make-pause-node` (procedure)

`(make-pause-node name continue-target label) -> node`\
`(make-pause-node name continue-target reason label) -> node`

A node that pauses the parser. After `parser-resume!` it continues at
`continue-target`. The optional `reason` names an error declaration reported,
as a pause reason, by `parser-result-pause`.

**Available from:** `(byte-machine graph)`\
**Details:** [Pausing](running.md#pausing)

## Matchers

### `make-exact-byte-matcher` (procedure)

`(make-exact-byte-matcher byte) -> matcher`

Matches one byte.

**Available from:** `(byte-machine graph)`

### `make-byte-range-matcher` (procedure)

`(make-byte-range-matcher low high) -> matcher`

Matches every byte from `low` to `high`, inclusive.

**Available from:** `(byte-machine graph)`

### `make-byte-set-matcher` (procedure)

`(make-byte-set-matcher bytes) -> matcher`

Matches every byte in the list `bytes`.

**Available from:** `(byte-machine graph)`

### `make-byte-complement-matcher` (procedure)

`(make-byte-complement-matcher matcher) -> matcher`

Matches every byte `matcher` does not.

**Available from:** `(byte-machine graph)`

### `ascii-bytes` (procedure)

`(ascii-bytes string) -> list-of-bytes`

The byte values of an ASCII string, as a list. Raises on a character
outside ASCII.

**Available from:** `(byte-machine graph)`

### `matcher?` (predicate)

`(matcher? x) -> boolean`

True for any of the four matcher kinds.

**Available from:** `(byte-machine graph)`

### `exact-byte-matcher?` (predicate)

`(exact-byte-matcher? x) -> boolean`

True for a matcher made by `make-exact-byte-matcher`.

**Available from:** `(byte-machine graph)`

### `exact-byte-matcher-byte` (accessor)

`(exact-byte-matcher-byte matcher) -> byte`

The byte it matches.

**Available from:** `(byte-machine graph)`

### `byte-range-matcher?` (predicate)

`(byte-range-matcher? x) -> boolean`

True for a matcher made by `make-byte-range-matcher`.

**Available from:** `(byte-machine graph)`

### `byte-range-matcher-low` (accessor)

`(byte-range-matcher-low matcher) -> byte`

The range's lowest byte.

**Available from:** `(byte-machine graph)`

### `byte-range-matcher-high` (accessor)

`(byte-range-matcher-high matcher) -> byte`

The range's highest byte.

**Available from:** `(byte-machine graph)`

### `byte-set-matcher?` (predicate)

`(byte-set-matcher? x) -> boolean`

True for a matcher made by `make-byte-set-matcher`.

**Available from:** `(byte-machine graph)`

### `byte-set-matcher-bytes` (accessor)

`(byte-set-matcher-bytes matcher) -> list-of-bytes`

The set's bytes, as a fresh list.

**Available from:** `(byte-machine graph)`

### `byte-complement-matcher?` (predicate)

`(byte-complement-matcher? x) -> boolean`

True for a matcher made by `make-byte-complement-matcher`.

**Available from:** `(byte-machine graph)`

### `byte-complement-matcher-matcher` (accessor)

`(byte-complement-matcher-matcher matcher) -> matcher`

The matcher being complemented.

**Available from:** `(byte-machine graph)`

## Nodes that read input

### `make-byte-dispatch-node` (procedure)

`(make-byte-dispatch-node name cases fallback eof-target label) -> node`

Reads one byte and takes the edge of the case that matches it, or the
`fallback` edge. `cases` is a list of byte cases. `eof-target` is a node name,
or `#f` for the machine's default end-of-input error.

**Available from:** `(byte-machine graph)`\
**Details:** [Byte dispatch](machines.md#byte-dispatch)

### `make-byte-case` (procedure)

`(make-byte-case matcher edge label) -> byte-case`

One case of a byte dispatch: take `edge` when `matcher` accepts the byte.

**Available from:** `(byte-machine graph)`

### `make-sequence-dispatch-node` (procedure)

`(make-sequence-dispatch-node name cases mismatch eof-target label) -> node`

Matches one of several fixed byte sequences and consumes it. `mismatch`
is the edge taken at the first byte that fits no case. No case may be a
prefix of another.

**Available from:** `(byte-machine graph)`\
**Details:** [Sequence dispatch](machines.md#sequence-dispatch)

### `make-sequence-case` (procedure)

`(make-sequence-case bytes target label) -> sequence-case`

A byte sequence, as a list of bytes, and the node to go to after it.

**Available from:** `(byte-machine graph)`

### `sequence-dispatch-node?` (predicate)

`(sequence-dispatch-node? x) -> boolean`

True for a node made by `make-sequence-dispatch-node`.

**Available from:** `(byte-machine graph)`

### `sequence-dispatch-node-name` (accessor)

`(sequence-dispatch-node-name node) -> name`

The node's name.

**Available from:** `(byte-machine graph)`

### `sequence-dispatch-node-cases` (accessor)

`(sequence-dispatch-node-cases node) -> list-of-sequence-cases`

The node's cases.

**Available from:** `(byte-machine graph)`

### `sequence-dispatch-node-mismatch` (accessor)

`(sequence-dispatch-node-mismatch node) -> edge`

The node's mismatch edge.

**Available from:** `(byte-machine graph)`

### `sequence-dispatch-node-eof-target` (accessor)

`(sequence-dispatch-node-eof-target node) -> node-name-or-false`

The node's end-of-input target, or `#f`.

**Available from:** `(byte-machine graph)`

### `sequence-case?` (predicate)

`(sequence-case? x) -> boolean`

True for a value made by `make-sequence-case`.

**Available from:** `(byte-machine graph)`

### `sequence-case-bytes` (accessor)

`(sequence-case-bytes case) -> list-of-bytes`

The case's bytes, as a fresh list.

**Available from:** `(byte-machine graph)`

### `sequence-case-target` (accessor)

`(sequence-case-target case) -> node-name`

The node the case goes to.

**Available from:** `(byte-machine graph)`

### `make-keyword-table-node` (procedure)

`(make-keyword-table-node name entries no-match eof-target case-insensitive? label) -> node`

Matches one of a set of keywords that may be prefixes of each other,
greedily and without backtracking. The byte that ends a keyword is not
consumed. `no-match` is the edge taken when no keyword matches. When
`case-insensitive?` is true, ASCII letters match in either case.

**Available from:** `(byte-machine graph)`\
**Details:** [Keyword table](machines.md#keyword-table)

### `make-keyword-entry` (procedure)

`(make-keyword-entry bytes target label) -> keyword-entry`

A keyword, as a list of bytes, and the node to go to when it matches.

**Available from:** `(byte-machine graph)`

### `make-integer-accumulate-node` (procedure)

`(make-integer-accumulate-node name field base digit-target nondigit-edge overflow-error eof-target label) -> node`

Reads one byte. A digit in `base` (10 or 16) is folded into `field` and
leads to `digit-target`; a non-digit takes `nondigit-edge`. Overflow goes to
the node `overflow-error`, leaving the field unchanged.

**Available from:** `(byte-machine graph)`\
**Details:** [Reading a number](fields.md#reading-a-number-integer-accumulate)

### `make-counted-consume-node` (procedure)

`(make-counted-consume-node name field next eof-target label) -> node`

Consumes up to `field` bytes, subtracting what it takes, and goes to `next`
when the field reaches zero.

**Available from:** `(byte-machine graph)`\
**Details:** [Counting bytes](fields.md#counting-bytes-counted-consume)

## Nodes that read nothing

### `make-field-action-node` (procedure)

`(make-field-action-node name operation arguments next error label) -> node`

Changes a field. `operation` is `store`, `clear`, `increment`,
`decrement`, `add`, `set-mask` or `clear-mask`; `arguments` starts with the
field name. `error` is the node to go to on overflow, and must be `#f` for
the operations that cannot overflow.

**Available from:** `(byte-machine graph)`\
**Details:** [Field actions](fields.md#changing-a-field-field-actions)

### `make-field-branch-node` (procedure)

`(make-field-branch-node name predicate arguments true-target false-target label) -> node`

Tests a field. `predicate` is `equal`, `zero`, `nonzero`, `range`,
`mask-any`, `mask-all` or `mask-none`; `arguments` starts with the field
name.

**Available from:** `(byte-machine graph)`\
**Details:** [Field branches](fields.md#testing-a-field-field-branches)

### `make-callback-node` (procedure)

`(make-callback-node name callback continue-target branch-targets pause-continuation label) -> node`\
`(make-callback-node name callback continue-target branch-targets pause-continuation reason label) -> node`

Calls an `event` or `decision` callback. `continue-target` follows
`callback-continue`; `branch-targets` maps each branch key to a node, as
`(list (list key target) ...)`; `pause-continuation` is where the parser
resumes after `callback-pause`. The optional `reason` names an error
declaration reported with the pause.

**Available from:** `(byte-machine graph)`\
**Details:** [Callbacks and spans](callbacks.md)

### `make-span-start-node` (procedure)

`(make-span-start-node name span next label) -> node`

Opens the span `span`.

**Available from:** `(byte-machine graph)`\
**Details:** [Spans](callbacks.md#spans)

### `make-span-end-node` (procedure)

`(make-span-end-node name span next label) -> node`

Closes the span `span`, delivering its last fragment and calling its complete callback.

**Available from:** `(byte-machine graph)`\
**Details:** [Spans](callbacks.md#spans)

## Fields

### `make-uint-field` (procedure)

`(make-uint-field name width initial label) -> uint-field`\
`(make-uint-field name width initial settable? label) -> uint-field`

Declares an unsigned integer field of `width` bits (8, 16, 32 or 64)
starting at `initial`. A `settable?` field's starting value can be chosen at
`make-parser`.

**Available from:** `(byte-machine graph)`\
**Details:** [Fields and counts](fields.md#declaring-a-field)

### `uint-field?` (predicate)

`(uint-field? x) -> boolean`

True for a value made by `make-uint-field`.

**Available from:** `(byte-machine graph)`

### `uint-field-name` (accessor)

`(uint-field-name field) -> name`

The field's name.

**Available from:** `(byte-machine graph)`

### `uint-field-width` (accessor)

`(uint-field-width field) -> integer`

The field's width in bits.

**Available from:** `(byte-machine graph)`

### `uint-field-initial` (accessor)

`(uint-field-initial field) -> integer`

The field's declared starting value.

**Available from:** `(byte-machine graph)`

### `uint-field-settable?` (accessor)

`(uint-field-settable? field) -> boolean`

Whether `make-parser` may override the starting value.

**Available from:** `(byte-machine graph)`

### `uint-field-source-label` (accessor)

`(uint-field-source-label field) -> label`

The label given when the field was declared.

**Available from:** `(byte-machine graph)`

## Callbacks and spans

### `make-callback-declaration` (procedure)

`(make-callback-declaration name kind required? branch-keys default-branch label) -> callback-declaration`

Declares a callback. `kind` is `event`, `decision`, `span-data` or
`span-complete`. A `required?` callback must be bound at `make-parser`.
`branch-keys` lists a decision's answers; `default-branch` is the answer an
unbound optional decision takes.

**Available from:** `(byte-machine graph)`\
**Details:** [Callbacks and spans](callbacks.md#declaring-a-callback)

### `callback-declaration?` (predicate)

`(callback-declaration? x) -> boolean`

True for a value made by `make-callback-declaration`.

**Available from:** `(byte-machine graph)`

### `callback-declaration-name` (accessor)

`(callback-declaration-name declaration) -> name`

The callback's name.

**Available from:** `(byte-machine graph)`

### `callback-declaration-kind` (accessor)

`(callback-declaration-kind declaration) -> symbol`

The callback's kind.

**Available from:** `(byte-machine graph)`

### `callback-declaration-required?` (accessor)

`(callback-declaration-required? declaration) -> boolean`

Whether the callback must be bound.

**Available from:** `(byte-machine graph)`

### `callback-declaration-branch-keys` (accessor)

`(callback-declaration-branch-keys declaration) -> list-of-symbols`

A decision's branch keys; `'()` for other kinds.

**Available from:** `(byte-machine graph)`

### `callback-declaration-default-branch` (accessor)

`(callback-declaration-default-branch declaration) -> symbol-or-false`

The default branch, or `#f`.

**Available from:** `(byte-machine graph)`

### `callback-declaration-source-label` (accessor)

`(callback-declaration-source-label declaration) -> label`

The label given when the callback was declared.

**Available from:** `(byte-machine graph)`

### `make-span-declaration` (procedure)

`(make-span-declaration name data-callback complete-callback label) -> span-declaration`

Declares a span. `data-callback` names a `span-data` callback;
`complete-callback` names a `span-complete` callback, or is `#f`.

**Available from:** `(byte-machine graph)`\
**Details:** [Spans](callbacks.md#spans)

### `span-declaration?` (predicate)

`(span-declaration? x) -> boolean`

True for a value made by `make-span-declaration`.

**Available from:** `(byte-machine graph)`

### `span-declaration-name` (accessor)

`(span-declaration-name declaration) -> name`

The span's name.

**Available from:** `(byte-machine graph)`

### `span-declaration-data-callback` (accessor)

`(span-declaration-data-callback declaration) -> name`

The span's data callback.

**Available from:** `(byte-machine graph)`

### `span-declaration-complete-callback` (accessor)

`(span-declaration-complete-callback declaration) -> name-or-false`

The span's complete callback, or `#f`.

**Available from:** `(byte-machine graph)`

### `span-declaration-source-label` (accessor)

`(span-declaration-source-label declaration) -> label`

The label given when the span was declared.

**Available from:** `(byte-machine graph)`

## Verifying

### `verify-machine` (procedure)

`(verify-machine machine) -> verification`

Checks a machine and returns a verification result. Never raises on a bad
machine: problems are returned as diagnostics. A value that is not a machine
yields an `invalid-shape` diagnostic.

**Available from:** `(byte-machine verify)`\
**Details:** [The verifier](verifier.md)

### `verification-ok?` (accessor)

`(verification-ok? verification) -> boolean`

True when there are no diagnostics.

**Available from:** `(byte-machine verify)`

### `verification-diagnostics` (accessor)

`(verification-diagnostics verification) -> list-of-diagnostics`

Every problem found, or `'()`.

**Available from:** `(byte-machine verify)`

### `verification-machine` (accessor)

`(verification-machine verification) -> machine`

The machine that was checked.

**Available from:** `(byte-machine verify)`

### `diagnostic?` (predicate)

`(diagnostic? x) -> boolean`

True for a diagnostic.

**Available from:** `(byte-machine verify)`

### `diagnostic-code` (accessor)

`(diagnostic-code diagnostic) -> symbol`

The diagnostic's code.

**Available from:** `(byte-machine verify)`\
**Details:** [Every diagnostic code](verifier.md#every-diagnostic-code)

### `diagnostic-node` (accessor)

`(diagnostic-node diagnostic) -> symbol-or-false`

The node, or other named thing, the diagnostic concerns.

**Available from:** `(byte-machine verify)`

### `diagnostic-message` (accessor)

`(diagnostic-message diagnostic) -> string`

A sentence describing the problem.

**Available from:** `(byte-machine verify)`

### `diagnostic-edge` (accessor)

`(diagnostic-edge diagnostic) -> symbol-or-false`

For `non-eof-into-finish`, which edge of the node leads into the finish (`case`, `fallback`, ...); otherwise `#f`.

**Available from:** `(byte-machine verify)`

### `diagnostic-severity` (accessor)

`(diagnostic-severity diagnostic) -> symbol`

The severity: `error`.

**Available from:** `(byte-machine verify)`

### `diagnostic-machine` (accessor)

`(diagnostic-machine diagnostic) -> symbol-or-false`

The name of the machine checked.

**Available from:** `(byte-machine verify)`

### `diagnostic-declarations` (accessor)

`(diagnostic-declarations diagnostic) -> list-of-symbols`

Declarations involved, such as two sharing a name; often `'()`.

**Available from:** `(byte-machine verify)`

### `diagnostic-path` (accessor)

`(diagnostic-path diagnostic) -> list-of-symbols-or-false`

For loops, end-of-input problems and span-state problems, the node names along the offending path; otherwise `#f`.

**Available from:** `(byte-machine verify)`

## Compiling and generating

### `compile-machine` (procedure)

`(compile-machine machine options) -> compilation`

Verifies `machine` and prepares it for code generation. `options` must be
`'()`; anything else raises. Does no I/O.

**Available from:** `(byte-machine compile)`\
**Details:** [Generated code](generating.md#from-machine-to-file)

### `compilation-ok?` (accessor)

`(compilation-ok? compilation) -> boolean`

True when the machine verified and can be rendered.

**Available from:** `(byte-machine compile)`

### `compilation-diagnostics` (accessor)

`(compilation-diagnostics compilation) -> list-of-diagnostics`

The verifier's diagnostics; `'()` when ok.

**Available from:** `(byte-machine compile)`

### `render-machine` (procedure)

`(render-machine compilation binding) -> bytevector`

The generated library, as UTF-8 source with LF line endings. It is named
`(generated <machine-name>)` and exports `binding`. Raises if the compilation
is not ok, or if `binding` is not a valid name, is a core keyword such as
`define` or `lambda`, a runtime export, or an internal name of the generated
code. Other `(rnrs)` names, such as `list`, are not refused but produce a
library that fails to load.

**Available from:** `(byte-machine compile)`\
**Details:** [What the library looks like](generating.md#what-the-library-looks-like)

### `emit-machine` (procedure)

`(emit-machine compilation binding port) -> metadata`

Renders as `render-machine` does and writes the bytes to the binary
output `port`. Returns an opaque value describing what was written.

**Available from:** `(byte-machine compile)`

### `reserved-member-2` (constant)

`reserved-member-2 : list-of-symbols`

The runtime's exports, which no generated binding may use. Exported for
byte-machine's own tests; not for applications.

**Available from:** `(byte-machine compile)`

### `reserved-member-3` (constant)

`reserved-member-3 : list-of-symbols`

The identifiers generated code binds internally, which no generated
binding may use. Exported for byte-machine's own tests; not for
applications.

**Available from:** `(byte-machine compile)`

## Interpreting

### `make-interpreted-machine` (procedure)

`(make-interpreted-machine verification) -> compiled-machine`

A compiled machine that runs the verified machine directly, without
generated code. Use it with `make-parser` exactly like a generated one.
Raises if `verification` is not ok.

**Available from:** `(byte-machine interpret)`\
**Details:** [Testing a grammar](testing.md#two-implementations)

## Parsers

### `make-parser` (procedure)

`(make-parser compiled-machine callback-bindings context) -> parser`\
`(make-parser compiled-machine callback-bindings context field-initials) -> parser`

Makes a parser. `callback-bindings` is a list of `(name procedure)` lists;
`context` is passed to every callback; `field-initials` is an alist of
starting values for settable fields. Raises on an unknown, repeated or
missing required callback, and on a bad field override.

**Available from:** `(byte-machine runtime)`\
**Details:** [Making a parser](running.md#making-a-parser)

### `parser?` (predicate)

`(parser? x) -> boolean`

True for a parser.

**Available from:** `(byte-machine runtime)`

### `parser-feed!` (procedure)

`(parser-feed! parser bv start end) -> parser-result`

Parses the bytes of `bv` from `start` up to, not including, `end`.
Requires `0 <= start <= end <= (bytevector-length bv)`.

**Available from:** `(byte-machine runtime)`\
**Details:** [Feeding](running.md#feeding)

### `parser-finish!` (procedure)

`(parser-finish! parser) -> parser-result`

Signals end of input and follows the end-of-input route.

**Available from:** `(byte-machine runtime)`\
**Details:** [Finishing](running.md#finishing)

### `parser-resume!` (procedure)

`(parser-resume! parser) -> symbol`

Resumes a paused parser. Returns `feed-ready` after a pause during a feed
(feed again) and `finish-ready` after one during a finish (call
`parser-finish!` again).

**Available from:** `(byte-machine runtime)`\
**Details:** [Pausing](running.md#pausing)

### `parser-reset!` (procedure)

`(parser-reset! parser) -> unspecified`

Returns the parser to its state just after `make-parser`, keeping its
callbacks, context and field overrides. Also recovers a poisoned parser.

**Available from:** `(byte-machine runtime)`\
**Details:** [Resetting](running.md#resetting)

### `parser-lifecycle` (accessor)

`(parser-lifecycle parser) -> symbol`

One of `ready`, `paused-feed`, `paused-finish`, `finish-ready`,
`stopped`, `finished`, `error`, `busy` or `poisoned`.

**Available from:** `(byte-machine runtime)`\
**Details:** [Looking at a live parser](running.md#looking-at-a-live-parser)

### `parser-stream-offset` (accessor)

`(parser-stream-offset parser) -> integer`

Bytes consumed since the parser was made or reset.

**Available from:** `(byte-machine runtime)`

### `parser-state-name` (accessor)

`(parser-state-name parser) -> name`

The name of the node the parser is at.

**Available from:** `(byte-machine runtime)`

### `parser-active-span` (accessor)

`(parser-active-span parser) -> name-or-false`

The open span, or `#f`.

**Available from:** `(byte-machine runtime)`

### `parser-field-ref` (procedure)

`(parser-field-ref parser field) -> integer`

A field's current value. Raises for a field the machine does not declare.

**Available from:** `(byte-machine runtime)`\
**Details:** [Reading fields](fields.md#reading-fields-from-your-code)

### `parser-user-context` (accessor)

`(parser-user-context parser) -> any`

The context given to `make-parser`.

**Available from:** `(byte-machine runtime)`

## Results

### `parser-result?` (predicate)

`(parser-result? x) -> boolean`

True for a result.

**Available from:** `(byte-machine runtime)`

### `parser-result-status` (accessor)

`(parser-result-status result) -> symbol`

`need-input`, `paused`, `stopped`, `finished` or `error`.

**Available from:** `(byte-machine runtime)`\
**Details:** [The five statuses](running.md#the-five-statuses)

### `parser-result-next` (accessor)

`(parser-result-next result) -> integer`

The index of the first byte this feed did not consume.

**Available from:** `(byte-machine runtime)`

### `parser-result-consumed` (accessor)

`(parser-result-consumed result) -> integer`

How many bytes this call consumed.

**Available from:** `(byte-machine runtime)`

### `parser-result-stream-offset` (accessor)

`(parser-result-stream-offset result) -> integer`

Bytes consumed since the parser was made or reset.

**Available from:** `(byte-machine runtime)`

### `parser-result-error` (accessor)

`(parser-result-error result) -> parser-error-or-false`

The error, when the status is `error`; otherwise `#f`.

**Available from:** `(byte-machine runtime)`

### `parser-result-pause` (accessor)

`(parser-result-pause result) -> parser-error-or-false`

When the status is `paused` and the pause declared a reason, that reason
as an error-shaped record; otherwise `#f`.

**Available from:** `(byte-machine runtime)`

## Parser errors

### `parser-error?` (predicate)

`(parser-error? x) -> boolean`

True for an error record.

**Available from:** `(byte-machine runtime)`\
**Details:** [The error record](errors.md#the-error-record)

### `parser-error-domain` (accessor)

`(parser-error-domain error) -> symbol`

`machine` for a grammar error, `callback` for a callback failure.

**Available from:** `(byte-machine runtime)`

### `parser-error-code` (accessor)

`(parser-error-code error) -> symbol`

The error's code.

**Available from:** `(byte-machine runtime)`

### `parser-error-reason` (accessor)

`(parser-error-reason error) -> string`

The error's reason.

**Available from:** `(byte-machine runtime)`

### `parser-error-detail` (accessor)

`(parser-error-detail error) -> any`

A callback failure's detail; `#f` for a grammar error.

**Available from:** `(byte-machine runtime)`

### `parser-error-node-name` (accessor)

`(parser-error-node-name error) -> name`

The node where the error happened.

**Available from:** `(byte-machine runtime)`

### `parser-error-state-id` (accessor)

`(parser-error-state-id error) -> integer-or-symbol`

An internal state identifier, for debugging. It differs between a
generated parser and the interpreter.

**Available from:** `(byte-machine runtime)`

### `parser-error-offset` (accessor)

`(parser-error-offset error) -> integer`

The stream offset where the error happened.

**Available from:** `(byte-machine runtime)`

### `parser-error-position-kind` (accessor)

`(parser-error-position-kind error) -> symbol`

`byte`, `boundary` or `eof`.

**Available from:** `(byte-machine runtime)`\
**Details:** [Where the error is](errors.md#where-the-error-is)

### `parser-error-span` (accessor)

`(parser-error-span error) -> name-or-false`

The span the error cut short, or `#f`.

**Available from:** `(byte-machine runtime)`\
**Details:** [The span an error cuts short](errors.md#the-span-an-error-cuts-short)

### `parser-error-span-offset` (accessor)

`(parser-error-span-offset error) -> integer-or-false`

Where that span's undelivered bytes begin, or `#f`.

**Available from:** `(byte-machine runtime)`

## Callback outcomes

### `callback-continue` (constant)

`callback-continue : callback-outcome`

Returned by a callback to carry on.

**Available from:** `(byte-machine runtime)`\
**Details:** [What a callback returns](callbacks.md#what-a-callback-returns)

### `callback-pause` (constant)

`callback-pause : callback-outcome`

Returned by a callback to pause the parser.

**Available from:** `(byte-machine runtime)`

### `make-callback-failure` (procedure)

`(make-callback-failure code detail) -> callback-failure`

Returned by a callback to stop with an error. `code` is a name; `detail`
is any value, or `#f`.

**Available from:** `(byte-machine runtime)`\
**Details:** [A callback failure](errors.md#a-callback-failure)

### `callback-failure?` (predicate)

`(callback-failure? x) -> boolean`

True for a value made by `make-callback-failure`.

**Available from:** `(byte-machine runtime)`

### `callback-failure-code` (accessor)

`(callback-failure-code failure) -> symbol`

The failure's code.

**Available from:** `(byte-machine runtime)`

### `callback-failure-detail` (accessor)

`(callback-failure-detail failure) -> any`

The failure's detail.

**Available from:** `(byte-machine runtime)`

## Compiled machines

### `compiled-machine?` (predicate)

`(compiled-machine? x) -> boolean`

True for a compiled machine: what a generated library exports, or what
`make-interpreted-machine` returns.

**Available from:** `(byte-machine runtime)`

### `make-compiled-machine` (procedure)

`(make-compiled-machine executor) -> compiled-machine`

Wraps an executor procedure as a compiled machine. `(byte-machine
interpret)` uses it; applications don't.

**Available from:** `(byte-machine runtime)`

## The generated-code interface

Generated libraries import `(byte-machine runtime)` and nothing else, so the
procedures they call are exported from it. They are an internal, versioned
interface between generated code and the runtime. Don't call them yourself.
Names ending `/v1` or `/v2` that a newer interface replaced remain as
*tombstones*: they exist so that an old generated library fails with a clear
message instead of an unbound identifier.

### `byte-machine-make-compiled-machine` (procedure)

`(byte-machine-make-compiled-machine abi-version fingerprint entry-state exec metadata) -> compiled-machine`

Builds the compiled machine a generated library exports. Raises
`generated-runtime ABI mismatch` when `abi-version` is not the runtime's.

**Available from:** `(byte-machine runtime)`\
**Details:** [Versions](generating.md#versions)

### `byte-machine-make-compiled-machine/v1` (procedure)

`(byte-machine-make-compiled-machine/v1 abi-version arg ...) -> raises`

Tombstone: always raises.

**Available from:** `(byte-machine runtime)`

### `byte-machine-make-compiled-machine/v2` (procedure)

`(byte-machine-make-compiled-machine/v2 abi-version arg ...) -> raises`

Tombstone: always raises.

**Available from:** `(byte-machine runtime)`

### `byte-machine-make-feed-outcome/v1` (procedure)

`(byte-machine-make-feed-outcome/v1 status next error next-state offset) -> feed-outcome`

What generated code returns to the runtime at the end of a feed or finish.

**Available from:** `(byte-machine runtime)`

### `byte-machine-make-parser-error/v1` (procedure)

`(byte-machine-make-parser-error/v1 entry node-name state-id offset position-kind) -> parser-error`

Builds a grammar error for generated code.

**Available from:** `(byte-machine runtime)`

### `byte-machine-make-callback-error/v1` (procedure)

`(byte-machine-make-callback-error/v1 code detail node-name state-id offset position-kind) -> parser-error`

Builds a callback-domain error for generated code.

**Available from:** `(byte-machine runtime)`

### `byte-machine-callback-step/v1` (procedure)

`(byte-machine-callback-step/v1 arg ...) -> raises`

Tombstone: always raises.

**Available from:** `(byte-machine runtime)`

### `byte-machine-callback-step/v2` (procedure)

`(byte-machine-callback-step/v2 parser state offset callback branches continue default) -> outcome`

Calls an event or decision callback for generated code and classifies its answer.

**Available from:** `(byte-machine runtime)`

### `byte-machine-span-open/v1` (procedure)

`(byte-machine-span-open/v1 parser span mark data-slot) -> unspecified`

Records that a span opened.

**Available from:** `(byte-machine runtime)`

### `byte-machine-span-fragment-step/v1` (procedure)

`(byte-machine-span-fragment-step/v1 arg ...) -> raises`

Tombstone: always raises.

**Available from:** `(byte-machine runtime)`

### `byte-machine-span-fragment-step/v2` (procedure)

`(byte-machine-span-fragment-step/v2 parser state offset callback bv to continue) -> outcome`

Delivers a span's fragment for generated code and classifies the callback's answer.

**Available from:** `(byte-machine runtime)`

### `byte-machine-span-close/v1` (procedure)

`(byte-machine-span-close/v1 parser) -> unspecified`

Records that the open span closed.

**Available from:** `(byte-machine runtime)`

### `byte-machine-keyword-step/v1` (procedure)

`(byte-machine-keyword-step/v1 entries no-match case-insensitive? path bv pos end) -> step`

Advances a keyword-table match for generated code.

**Available from:** `(byte-machine runtime)`
