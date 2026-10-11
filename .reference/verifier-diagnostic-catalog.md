# Verifier diagnostic catalog

The diagnostic codes `(byte-machine verify)` can report and what each means. A
source machine that fails verification carries one or more diagnostics, each
with a `code` (the symbol below), the node or subject it concerns, and a
message.

**This catalog is checked against the verifier.** The authoritative code set is
computed by `test/common/diagnostic-census-tests.sps`, which reads `verify.sls`
as a datum and walks every diagnostic-constructor site. That test also asserts
that the code set listed here equals the census, so a code added to
`verify.sls` (or dropped from it) fails until this list is updated; the catalog
cannot silently drift from the verifier. Per-site counts live in that test.

The codes are grouped by the property they check.

## Shape and references

- `invalid-shape` — the argument is not a machine, or a node/field/declaration is
  structurally malformed.
- `invalid-name` — a machine, node, field, callback, span, or branch-key name is
  outside the portable ASCII name grammar (`(byte-machine private names)`).
- `duplicate-name` — two nodes share a name.
- `duplicate-error-declaration` — two error declarations share a name.
- `missing-target` — an edge names a node that does not exist.
- `missing-error-declaration` — an error node names an error declaration that was
  not declared.
- `overlapping-cases` — two byte-dispatch cases match a common byte.
- `ambiguous-sequence-prefix` — one sequence-dispatch case is a proper prefix of
  another.
- `duplicate-keyword` — two keyword-table entries have the same bytes. Proper
  prefixes are permitted; an exact duplicate is not.
- `case-insensitive-keyword-collision` — two entries of a case-insensitive
  keyword table are equal after ASCII case-folding (e.g. `Content-Length` and
  `content-length`). Byte-distinct case variants are legal in a case-sensitive
  table; the fold makes their terminal choice ambiguous.

## Fields

- `invalid-field-declaration` — a field declaration is malformed or two fields
  share a name.
- `invalid-field-operand` — a field action or branch names operands that do not
  fit its operand schema (wrong arity, or a value outside the field's width — for
  example a `range` bound wider than the field).
- `settable-consume-counter` — a counted-consume node's counter is a settable
  field. A settable field's initial is chosen by the embedder at `make-parser`,
  but the EOF-execution pass reasons that a counted-consume at the entry state
  holds its declared initial (and may be zero); an embedder override would
  falsify that, so a settable field may not be a count.

## Reachability and EOF

- `unreachable-node` — a node no execution can reach.
- `zero-progress-cycle` — a cycle that consumes no byte: one made only of
  `reexecute` edges and zero-width steps (pause continuations, field actions and
  branches, accumulate overflow edges).
- `invalid-eof-target` — an EOF target (a node's or the machine default) names no
  declared error / valid node.
- `non-eof-into-finish` — a finish terminal is reached over a byte edge; a finish
  is reachable only over an EOF route.
- `eof-reachable-stop` — from a state a parser can be parked on, the EOF path
  reaches a stop terminal; end of input must end in a finish or an error.
- `eof-zero-progress-cycle` — an EOF path cycles without reaching a terminal.

## Callback and span declarations

- `duplicate-callback-declaration` — two callback declarations share a name.
- `duplicate-span-declaration` — two span declarations share a name.
- `duplicate-branch-key` — a decision callback lists a branch key twice.
- `reserved-branch-key` — a branch key is `continue` or `pause`, which are
  reserved for the callback outcomes of the same names.
- `invalid-callback-declaration` — a callback declaration is inconsistent (for
  example an optional decision callback with no valid default branch).
- `missing-callback-declaration` — a span or node names a callback that was not
  declared.
- `invalid-span-callback` — a span names a callback of the wrong kind.
- `unreferenced-callback-declaration` — a span-kind callback that no span names,
  so nothing can ever invoke it.
- `missing-span-declaration` — a span node names a span that was not declared.

## Callback invocation

- `invalid-callback-invocation` — a callback node names an undeclared branch key,
  omits a target for a declared key, or invokes a span-kind callback.

## Span-state lattice

- `invalid-span-state` — the span state at a node is wrong for what the node
  does: a span start re-opens the span already open or opens one while another
  is open, or a span end closes a span that is not the open one or finds none
  open.
- `inconsistent-span-state` — two control paths into a node disagree on the span
  state; it is reported at the node where the paths merge.
- `span-active-at-pause` — a pause node or a callback node is reachable with a
  span open.
- `span-active-at-exit` — a span is still open at a stop/finish terminal.

---

*Thirty-three codes. If this list and `verify.sls` disagree, `diagnostic-census-tests`
fails by name — see the [grammar-author testing guide](grammar-author-testing-guide.md).*
