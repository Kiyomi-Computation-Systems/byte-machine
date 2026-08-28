# 0011: EOF execution — a distinct finish node, chaining eof-targets, and a unified finish path

Date: 2026-08-28
Status: accepted
Milestone: 2, Gate 0 (milestone-2-design.md §3.1)

## Context

Milestone 1 constructed and verified EOF declarations without executing them
(parent §25 M1; milestone-1-design.md §7). `eof-target` on a byte-dispatch node
is either `#f` (route to the machine-wide `default-eof-error`) or a symbol naming
a node, and the M1 verifier checks only that the symbol resolves (parent §16.2,
verify `pass-eof`). Milestone 2 must decide what *executing* `parser-finish!`
means.

Parent §10.6 is a **closed** node-kind set that already separates **Stop**
("successful sticky one-shot terminal, returns `stopped`") from **Finish**
("successful sticky EOF terminal, returns `finished`; a finish node may be reached
only while processing `parser-finish!`; the verifier rejects ordinary byte or
non-EOF control flow into it"). §16.2 correspondingly **requires** the verifier to
reject "EOF-only zero-progress cycles and non-EOF control flow into a finish
terminal" (§16.2:908) and "EOF-reachable stop terminals" (§16.2:909, "every EOF
path must reach finish or error after finitely many explicit pauses"), and §12.4
mandates a separate EOF zero-progress-cycle check with a finite-resumes guarantee.
Those checks are only load-bearing once EOF processing is a multi-step traversal
into a distinct finish terminal.

## Decision

1. **`parser-finish!` runs the same executor loop as feed, with input permanently
   exhausted.** The only branch that differs is at a dispatch node with no byte
   available: feed returns `need-input`; finish instead takes that node's
   eof-target — the named node when set, else the machine `default-eof-error`.
   Execution then continues through zero-width nodes exactly as feed does.
2. **EOF success is a distinct `finish` node.** `stop` stays feed-only and returns
   `stopped`; `finished` comes from its own node kind (§10.6), which is reachable
   only while processing `parser-finish!`. There is no "polysemous stop"; modeling
   EOF success as a stop re-read on the finish path describes a machine §16.2
   requires the verifier to reject.
3. **eof-targets chain, terminating at `{finish, error, pause}` — never `stop`.**
   A dispatch's eof-target may name another dispatch node; finish, having no byte,
   immediately takes *that* node's eof-target, and so on, until a `finish` node
   (`finished`), an `error` node (`error`), or a pause (`paused-finish`). This is
   the general reading and is the same walk feed already performs; it avoids an
   "eof-target must resolve directly to a terminal" restriction that later
   milestones (zero-width action/callback/span nodes on the EOF path — §12.4) would
   only have to remove.
4. **Three EOF verification checks, each with an asserted diagnostic code.**
   (a) an eof traversal reachable from any state must reach a terminal in finitely
   many steps — an eof-target loop fails (§16.2:908; a pause consumes no input and
   never counts as progress, so a pause-loop on the EOF path fails the same way);
   (b) a `finish` node reached by non-EOF (byte) control flow is rejected
   (§16.2:908); (c) a `stop` node reachable through an eof-target chain is rejected
   (§16.2:909). Checks (b)/(c) require the verifier to distinguish byte-reachability
   from eof-reachability.

## Consequences

- M2 adds **two** node/state kinds — a **finish** node (Slice ②) and a **pause**
  node (Slice ③). The reference interpreter's `op` closure and the generated
  `exec` (decision 0012) gain a `finish` arm emitting `finished`, distinct from the
  `stop` arm.
- The normalizer changes in **two distinct ways** (not "the else guards become
  real arms"): (a) the existing **dispatch** state arm is extended to encode its
  `eof-target`; (b) the `else` guards are replaced by the new **finish** (Slice ②)
  and **pause** (Slice ③) arms, each with its own canonical tag byte. Because EOF
  routing is now hashed into the IR fingerprint (the collision-safe choice, so two
  machines differing only in EOF routing hash differently), the Milestone 1
  one-byte golden fingerprint **moves and is re-baselined** in Slice ②.
- The verifier gains the EOF zero-progress-cycle, finish-terminal, and
  EOF-reachable-stop checks, and computes byte-reachability and eof-reachability
  separately so an eof-only-reachable finish node is not falsely flagged
  unreachable.
- `finished` is a new sticky terminal status; its lifecycle rides the parser
  lifecycle-state field and coded conditions of decision 0013 (Slice ②).
