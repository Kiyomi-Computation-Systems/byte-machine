# Milestone 8 Slice ⑤ — conflicts, malformed input, pipelining, clean EOF, and the close

**Status: executed — the milestone close.** Built against `main` at `4d888cf` (Slice ④ merged,
#107), on branch `feat/m8-slice-5`. `§25:1641-1642` items 9 and 10, plus the Milestone 8 close-out.
Depends on ④. No new grammar node — the fixture machine was complete after ④; this slice is the
malformed sweep, pipelining, the leak check, the determinism golden, and the dispositions.

## The work

- **`test/common/http-close-tests.sps`** (`byte-machine.unit.http-close`) — the malformed sweep:
  every one of `§21.4`'s eighteen codes produced at the position Slice ⓪'s table states, with the
  sweep's code set asserted **set-equal to the table's** (`http-error-rows`), so the table and the
  fixture agree by construction. Pipelining: no-body, fixed and chunked requests back to back, each a
  complete message (one `message-begin`/`message-complete` each); the same request twice. Clean EOF
  only while idle (decision 0037); `unexpected-eof` from a representative of every non-idle region
  (method, target, version, header name/value, content-length, fixed body, chunk size/ext/data,
  trailer name/value). 6 cases, 37 checks.
- **`test/common/http-leak-tests.sps`** (`byte-machine.unit.http-leak`) — the leak check
  (`§25:1649`, `§21.7:1209`, §4.8 item 5), read from the tree as data: no `src/` library (five public
  + three private) imports `(byte-machine test …)`; no public library re-exports an HTTP-vocabulary
  name; the fixture libraries are named `(byte-machine test …)`, never `(byte-machine http-…)`. It
  fails if a future slice leaks the fixture into a public library. 16 cases, 27 checks.
- **`test/common/determinism-http-tests.sps`** (`byte-machine.determinism.http`) — deterministic
  emission: byte-identical rendering across two emissions, and the emitted library loads and runs,
  agreeing with the interpreter on a fixed-body and a chunked request. 2 cases, 3 checks. (The
  committed-golden-**file** variant is deferred — see the dispositions.)

## Exit criteria (§25:1646-1649), dispositioned against the tree

| Criterion | Met by |
| --- | --- |
| **:1646** the complete §21 behavior passes | `§21.2` productions built across ①–④; `§21.3` events asserted in order by the `unit.http-*` lanes and validated against the shared event-order grammar; `§21.4`'s eighteen codes each produced at its position — the `http-close` malformed sweep asserts the set is exactly Slice ⓪'s table. |
| **:1647** representative messages pass every split point | `§22.5` split coverage in `unit.http-request-line`, `http-framing`, `http-chunked` (skeleton invariant, raw fragments not — the negative sentinel), and `differential.http` at every single-cut and 32 seeded multi-split schedules; pipelining in `http-close`. **§4.9 item 3** (pipelining at *every* split point) is **decided by measurement here: declined** — the per-message split coverage plus the seeded multi-split differential already exercises the fragment boundaries; the full pipelined product multiplies schedules for no new boundary shape, and the seeded subset is the stated fallback. |
| **:1648** interpreter and generated traces match | `byte-machine.differential.http` compares the result tuple **and** the full event trace (its recorder binds every callback) across every framing shape, malformed input, and schedule. |
| **:1649** the fixture stays private, no HTTP API leaks | `byte-machine.unit.http-leak`, read from the tree, plus §4.7's gate (no `src/` change at all). |

## §4.8 obligations, both ends

1. **§21.4:1177 precondition** — the error table. Closed by Slice ⓪ (#103).
2. **Case-insensitive recognition and the byte classes** (Milestone 3 §8, `http-version-machine.sls`'s
   header). Closed by Slices ① and ③; the `http-version-machine.sls` header's "Milestone 8, not here"
   note is now discharged.
3. **The fixture's field work** (Milestone 4 §9). Closed by Slices ③ and ④.
4. **§25:1648 interpreter≡generated** (Milestone 4 §4.6). Met by `differential.http`, above.
5. **§21.7:1209's file location.** Disposed as an annotation: the fixture machines live under the
   harness library root because a lane must import them, and the intent — never re-exported by a
   public library — is asserted by the leak check. `§21.7:1209` is **not** reworded; the parent plan
   gets a dated disposition.
6. **§12.7:770's zero-width-machine-action half** — not this milestone's (§4.6). The receivers stay
   where Milestone 5's close-out put them; the close note carries P2's and P3's measurements so the
   next milestone need not re-derive them (P2: a framing-conflict zero-width branch after the LF
   answers `boundary`, both lanes; P3: a *fallible* zero-width action over a **reexecute** edge
   answers `byte` where the row says `boundary`, both lanes — `compile.sls`'s OWED note, unchanged).
7. **A property lane over the fixture** — declined for this milestone (§10), receiver Milestone 9 or
   a hardening slice: a generator of HTTP-shaped *inputs* is a different instrument from Milestone 7's
   generator over *machines*, and the ten increments already carry a lane pair per slice.

## §4.9 scope additions, as shipped

1. **Shared event-order oracle** — shipped in Slice ① (`http-event-order.sls`), extended each slice
   (headers, the fixed/chunked body sub-grammars); every `unit.http-*` lane validates its trace
   against it.
2. **Fixture-region → node-name map** — shipped as `http-error-region-nodes` with its totality row
   (keys set-equal the regions, node-lists pairwise disjoint). **The node-name lists are left empty**,
   deliberately: their only value is naming a node on a failure, no lane failure needs that, and
   listing ~130 churning node names would couple the table to them for no current benefit. Receiver:
   a future debugging need or Milestone 9. The region-keyed rows already survive every rename.
3. **Pipelining at every split point** — declined by measurement (see the Exit table, :1647).

## Not inherited, and the region map

`§12.7:770`'s zero-width-machine-action half is unchanged and dispositioned in §4.8 item 6.
`§27:1696`'s diagnostic catalog is untouched (the error table is fixture-owned, `§21.4:1177`).

## Verification

- `unit.http-close` 6/37; `unit.http-leak` 16/27; `determinism.http` 2/3 — all modes, green.
- Full `release` minus the mutation lane — **137/137, 0 failed**.
- Mutation lane — **65 passes / 602 mutations**, unaffected (no `src/` or mutation-suite change).
- **§4.7 gate**: `git diff --stat main..HEAD -- src/` prints nothing across the whole milestone.

## Status surfaces (all four)

README.org, the parent plan's `Status:` line and a dated `§21.7` disposition, this milestone's design
doc status, and the ledger — all updated to record Milestone 8 closed
([[status-surfaces-drift-independently]]: the fourth, README.org, is the one that drifts).

**Milestone 8 is complete.** Next: Milestone 9 — cross-platform hardening and the v0.1 release (final).
