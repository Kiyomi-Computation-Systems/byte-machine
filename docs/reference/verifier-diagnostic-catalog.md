# Verifier diagnostic catalog

The diagnostic codes `(byte-machine verify)` can raise, what each means, and the
`§16.2` rule it enforces. A source machine that fails verification carries one or
more diagnostics, each with a `code` (the symbol below), the node or subject it
concerns, and a message.

**This catalog is derived, not hand-maintained.** The authoritative code set is
computed by `test/common/diagnostic-census-tests.sps`, which reads `verify.sls`
as a datum and walks every `(make-diagnostic … )` site — **thirty codes over
fifty-six sites** at v0.1. That lane also asserts the code set here matches the
census, so a code added to `verify.sls` (or dropped from it) fails until this list
is updated; the catalog cannot silently drift from the verifier. Per-site counts
live in that lane, the single place they are pinned.

The codes are grouped by the verifier pass that raises them.

## Shape and references (pass-schema)

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

## Fields (pass-schema)

- `invalid-field-declaration` — a field declaration is malformed or two fields
  share a name.
- `invalid-field-operand` — a field action or branch names operands that do not
  fit its operand schema (wrong arity, or a value outside the field's width — for
  example a `range` bound wider than the field).

## Reachability and EOF (pass-reachability)

- `unreachable-node` — a node no execution can reach.
- `zero-progress-cycle` — a cycle of `reexecute` edges that consumes no byte.
- `invalid-eof-target` — an EOF target (a node's or the machine default) names no
  declared error / valid node.
- `non-eof-into-finish` — a finish terminal is reached over a byte edge; a finish
  is reachable only over an EOF route.
- `eof-reachable-stop` — a stop node a parser can be parked on at end of input
  where the EOF walk requires a finish.
- `eof-zero-progress-cycle` — an EOF-driven cycle that makes no progress.

## Callback and span declarations (pass-declarations)

- `duplicate-callback-declaration` — two callback declarations share a name.
- `duplicate-span-declaration` — two span declarations share a name.
- `duplicate-branch-key` — a decision callback lists a branch key twice.
- `reserved-branch-key` — a branch key is `continue` or `pause`, which are
  reserved (`§9.3`).
- `invalid-callback-declaration` — a callback declaration is inconsistent (for
  example an optional decision callback with no valid default branch).
- `missing-callback-declaration` — a span or node names a callback that was not
  declared.
- `invalid-span-callback` — a span names a callback of the wrong kind.
- `unreferenced-callback-declaration` — a span-kind callback that no span names,
  so nothing can ever invoke it.
- `missing-span-declaration` — a span node names a span that was not declared.

## Callback invocation (pass-callback-nodes)

- `invalid-callback-invocation` — a callback node names an undeclared branch key,
  omits a target for a declared key, or invokes a span-kind callback.

## Span-state lattice (pass-spans)

- `invalid-span-state` — the span state at a node is wrong for what the node does
  (one of §16.2:899's transfer faults).
- `inconsistent-span-state` — two control paths into a node disagree on the span
  state (the merge disagreement, decision 0029).
- `span-active-at-pause` — a span is still open at a pause node.
- `span-active-at-exit` — a span is still open at a stop/finish terminal.

---

*Thirty codes. If this list and `verify.sls` disagree, `diagnostic-census-tests`
fails by name — see the [grammar-author testing guide](grammar-author-testing-guide.md).*
