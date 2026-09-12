# 0037: The idle node, `message-begin`, and clean EOF only while idle

Date: 2026-09-12
Status: accepted
Milestone: 8, Gate 0 (milestone-8-design.md §4.4)

## Context

Decided against `main` at `bf6e56d`; `src/` and `test/` byte-identical to `741e0ca` (0034's
Context).

**Three `§21` sentences meet at one node.** `§21.3:1139`: `message-begin` fires only when the first
method byte is **available**, before it is consumed — an empty feed and a clean idle EOF do not
start a message. `§21.3:1150`: completion resets the explicit message fields and returns to request
start **without** resetting the absolute stream offset. `§25:1642`: pipelined requests and clean
idle EOF.

**The shipped shape this reuses, read at `bf6e56d`.** `counted-machine.sls` already builds this
loop and says so: its header reads "`idle`'s eof-target is the FINISH, so EOF between messages is
`finished`" and "§12.4:725's idle-versus-partial distinction, which a machine whose entry is the
accumulate node cannot make. The entry reexecutes the first digit into `len`". The machine's `idle`
is a dispatch whose case reexecutes into the accumulator, whose eof-target is a `make-finish-node`,
and whose completion is a `make-field-action-node 'clear … 'idle` chain looping to request start.

**The verifier gate this rests on.** `§16.2:908`'s "non-EOF control flow into a finish terminal" is
decision [0011]'s check: a finish reached over a byte edge is refused. The design measured it (P1a,
at `741e0ca`) as `non-eof-into-finish`. And `clear` is in `ir.sls`'s infallible field operations
(`'(store clear set-mask clear-mask)`, read at `bf6e56d`), so the completion chain takes no error
edge.

## Decision

**1. `idle` is a byte dispatch, not a callback node.** Its single case matches `tchar` and
**reexecutes** into the `message-begin` callback node, so the byte is available but unconsumed when
the event fires. Its **eof-target is the finish terminal**, so EOF while idle is `finished`. Its
fallback rejects with `invalid-method`. *Rejected, with the failure it would cause*: `idle` as a
callback node — control reaches a callback node whether or not a byte is available, so it would fire
`message-begin` on an empty feed and pass its own test while violating `§21.3:1139`.

**2. Every other input-reading node routes EOF to an `unexpected-eof` error node for its region**
(per 0036), which the machine's default-eof declaration names. So `§21.4:1175`'s "EOF in any
non-idle state" is the machine's **default** and `idle` is the one override.

**3. The finish terminal is reachable only over an EOF route**, enforced by `§16.2:908`
(`non-eof-into-finish`). "Clean EOF only while idle" is therefore not a constraint the fixture works
around — it *is* the verifier's, and the fixture inherits it.

**4. Completion loops to `idle` through a chain of `clear` field actions**, which are infallible and
so take no error edge and cannot produce `§12.7:770`'s broken zero-width-action shape (design §4.6
measures that the fixture has no producer of it; the receivers stay where Milestone 5's close-out
put them). The absolute stream offset is the runtime's and is not reset.

## Consequences

- **Handed to Slice ①**: the `idle` dispatch with its finish eof-target and reexecuting
  `message-begin`, built through `(byte-machine graph)` only.
- **Handed to Slice ②**: the completion `clear` chain and the return to `idle` with the offset
  untouched — the no-body message loop, whose two-requests-in-one-feed property `counted-machine.sls`
  already demonstrates for a length-prefixed loop.
- **Handed to Slice ⑤**: clean idle EOF as `finished`, and `unexpected-eof` witnessed from every
  non-idle region (the per-region nodes of 0036).
- **A mutation pin** on `idle`'s eof-target (finish, not an error node) and on the reexecute of its
  `message-begin` case, each with its failure signature asserted.

[0011]: ./0011-eof-execution-model.md
