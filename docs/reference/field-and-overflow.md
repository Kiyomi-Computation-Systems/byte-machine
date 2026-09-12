# Fields and overflow

Declaring unsigned fields, the operations and predicates that read and write
them, integer accumulation, and counted consumption — with fixed widths and
explicit overflow edges throughout.

This is `§27:1695` of
[the implementation plan](../plans/byte-machine-implementation-plan.md). Every
claim was checked against the code: `(byte-machine graph)` /
`(byte-machine private ir)` for the constructors, `(byte-machine verify)` for
the operand schemas, `(byte-machine interpret)` for the semantics. Both
executors — the reference interpreter and a generated parser — behave
identically here.

---

## 1. Declaring a field

```scheme
(make-uint-field name width initial source-label)
```

- `name` — a symbol in the portable grammar `[a-z][a-z0-9-]*`.
- `width` — one of `8`, `16`, `32`, `64` (bits); nothing else is accepted.
- `initial` — an exact integer with `0 <= initial <= (- (expt 2 width) 1)`,
  inclusive at both ends. The `u64` bound is a bignum on every supported runtime;
  the check uses exact integer arithmetic, never fixnum.
- `source-label` — an optional diagnostic label (`#f`, a symbol, or a string).

A field's value ranges over `0 .. 2^width - 1`. There is exactly **one** field
type in v0.1 — an unsigned integer; more are deferred (`§29:1754`). Because only
one type exists, the verifier's "incompatible field" checks reduce to "the named
field is not declared" (§6).

## 2. Field actions — writing a field

```scheme
(make-field-action-node name operation arguments next error source-label)
```

`operation` is one of these seven (`field-operations`); `arguments` is a proper
list whose **first element is the field name**, followed by the operands the
operation takes. Effect on the field's value `v`, per `(byte-machine interpret)`:

| Operation | `arguments` | Effect |
| --- | --- | --- |
| `store` | `(field constant)` | `v := constant` |
| `clear` | `(field)` | `v := 0` |
| `increment` | `(field)` | `v := v + 1` |
| `decrement` | `(field)` | `v := v - 1` |
| `add` | `(field constant)` | `v := v + constant` |
| `set-mask` | `(field mask)` | `v := (bitwise-ior v mask)` |
| `clear-mask` | `(field mask)` | `v := (bitwise-and v (bitwise-not mask))` |

A field action **consumes no input**. The result is computed first and committed
last: if it lies in `0 .. 2^width - 1` the field is written and control goes to
`next`; otherwise the field is **left unchanged** and control goes to `error`.

`error` names a target node, or is `#f` **exactly** when the operation cannot
overflow or underflow. The four infallible operations — `store`, `clear`,
`set-mask`, `clear-mask` — require `error` to be `#f`; the three checked ones —
`increment`, `decrement`, `add` — require `error` to name a node. The constructor
enforces this correspondence itself.

## 3. Field branches — testing a field

```scheme
(make-field-branch-node name predicate arguments true-target false-target source-label)
```

`predicate` is one of these seven (`field-predicates`); `arguments` again begins
with the field name. The node consumes no input and routes to `true-target` or
`false-target` — both mandatory, no fallthrough. The test against `v`:

| Predicate | `arguments` | Tests |
| --- | --- | --- |
| `equal` | `(field constant)` | `v = constant` |
| `zero` | `(field)` | `v = 0` |
| `nonzero` | `(field)` | `v /= 0` |
| `range` | `(field low high)` | `low <= v <= high` |
| `mask-any` | `(field mask)` | `(bitwise-and v mask) /= 0` |
| `mask-all` | `(field mask)` | `(bitwise-and v mask) = mask` |
| `mask-none` | `(field mask)` | `(bitwise-and v mask) = 0` |

## 4. Integer accumulation

```scheme
(make-integer-accumulate-node name field base digit-target
                              nondigit-edge overflow-error eof-target source-label)
```

Unlike a field action, this node **reads the current byte**. It converts an ASCII
digit for `base` (`10` or `16`) and folds it into `field` by the checked
multiply-add `next = current * base + digit`:

- A **valid digit** updates the field and advances to `digit-target`.
- A **non-digit** takes `nondigit-edge` — an *edge* (`make-edge`), not a bare
  target, so it carries its own `advance`/`reexecute` mode; the delimiter is
  normally reexecuted.
- **Overflow** takes `overflow-error` (a mandatory node name — accumulation can
  always overflow, so there is no `#f` arm). The overflow edge is non-consuming
  and **leaves the previous field value unchanged**.
- **EOF** takes `eof-target` (a node name, or `#f` for the machine default EOF
  error).

The check is made *before* the arithmetic — conceptually
`current <= floor((maximum - digit) / base)` — so it never relies on host word
size or silent wrapping (`§15:856-868`).

## 5. Counted consumption

```scheme
(make-counted-consume-node name field next eof-target source-label)
```

Consumes up to the remaining value of `field` worth of octets in bulk,
subtracting exactly the number of bytes it commits:

- A **zero count** transitions to `next` immediately, consuming nothing.
- If **input ends first**, the available bytes are consumed and the parser
  returns `need-input`; truncation at EOF routes to `eof-target` (a node name, or
  `#f` for the machine default EOF error).
- If the **count reaches zero first**, execution continues at `next` with any
  remaining input.

There is **no `error` slot**: the subtraction cannot underflow, because the
committed count never exceeds the field's value (`§15:872`).

## 6. What the verifier checks

`(byte-machine verify)` validates field use beyond the local shape the
constructors enforce. For each field action and field branch,
`field-operand-schemas` fixes the exact arity and operand kinds; the verifier
emits `invalid-field-operand` for a wrong operand count, an operand outside the
named field's declared width, a `range` whose `low` exceeds its `high`, or an
operand naming no declared field. An accumulate or counted-consume node whose
`field` is undeclared draws the same code. Duplicate or non-portable field
declarations draw `invalid-field-declaration`.

## 7. Example: read a length, then consume that many bytes

A netstring-like machine — decimal digits, a delimiter, then exactly that many
body bytes (`3:abc` parses `abc`). Every constructor argument is exactly as the
source defines it.

```scheme
(make-machine
 'netstring 'scan-len
 (list (make-uint-field 'len 32 0 #f))          ; one u32 count field
 '() '()                                         ; no callbacks, no spans
 (list (make-error-declaration 'over 'length-overflow "length field overflowed" #f)
       (make-error-declaration 'eof  'unexpected-eof   "input ended early" #f))
 (list
  ;; Fold ASCII decimal digits into `len`; a non-digit delimiter is consumed.
  (make-integer-accumulate-node
   'scan-len 'len 10
   'scan-len                              ; digit-target: loop, one byte per digit
   (make-edge 'consume-body 'advance)     ; non-digit: consume the delimiter
   'on-overflow                           ; overflow -> error node, len unchanged
   'on-eof #f)                            ; EOF -> error node
  ;; Consume exactly `len` body bytes, then finish.
  (make-counted-consume-node 'consume-body 'len 'done 'on-eof #f)
  (make-finish-node 'done #f)
  (make-error-node 'on-overflow 'over #f)
  (make-error-node 'on-eof 'eof #f))
 'eof #f)                                        ; default EOF error
```

Feeding `3:abc`: `3` is a digit (`len` becomes 3); `:` is a non-digit and is
consumed, entering `consume-body`; the counted consume draws the count 3,
consumes `abc`, reaches zero, and continues to `done`.
