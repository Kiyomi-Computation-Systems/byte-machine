# Milestone 8 Slice ① — the request line

**Status: executed.** Built against `main` at `88febe1` (Slice ⓪ merged, #103), on branch
`feat/m8-slice-1`. `§25:1633-1634` items 1 and 2: the request method and target spans, the HTTP
version, and the strict request-line CRLF. Depends on ⓪.

## The fixture machine

`test/support/harness/byte-machine/test/http-machine.sls`, `make-http-machine`, built **only**
through `(byte-machine graph)` (`§21.5:1181`). It is grown one slice at a time; Slice ① is the
request line and ends at a `stop` node that Slice ② replaces with the header section. The graph:

- **`idle`** — a byte dispatch whose one case matches a `tchar` and **reexecutes** into
  `message-begin`, so the first method byte is available but unconsumed when the event fires
  (`§21.3:1139`); its eof-target is the finish, so clean EOF between messages is `finished`; its
  fallback rejects `invalid-method`. This one node also enforces `method = 1*tchar`'s "1*"
  (decision [0037](../decisions/0037-idle-node-message-begin-and-clean-eof.md)).
- **method / target spans** — each ends **before** its delimiter SP is consumed (`§21.3:1140`): the
  loop reexecutes the first non-member byte into the span-end, then a following dispatch reads that
  same byte (SP advances; anything else is the region's lexical error, now with no span open). The
  target sits behind a `target-gate` that enforces `1*target-byte`.
- **version** — the two-alternative sequence lifted from `http-version-machine.sls`; both reach
  `version-complete`, whose event fires before the CRLF.
- **strict CRLF** — a bare CR or bare LF is `invalid-line-ending`.
- **error nodes per span state** (decision
  [0036](../decisions/0036-error-node-is-per-span-state.md)): EOF with a span open gets its own node
  (`e-eof-method`, `e-eof-target`); no-span EOF uses the machine default `unexpected-eof`. The
  fixture verifies clean.

## §4.9 item 1 (owner-approved): the shared event-order oracle

`test/support/harness/byte-machine/test/http-event-order.sls` — the `§21.3` event contract as a
**grammar over events**. `trace-skeleton` drops fragments and coalesces a span-data run to one token
(`§22.5:1287`), and `event-sequence-matches?` greedily matches a skeleton against a grammar of
`(one E)` / `(star E)` terms. `http-request-grammar` is Slice ①'s request-line order; later slices
extend the grammar, not the matcher.

## The three lanes

- **`byte-machine.unit.http-request-line`** (source + aot) — absolute events and positions: the
  canonical request's full trace (both HTTP/1.0 and 1.1), the trace skeleton against the oracle
  (with a negative self-test), every request-line error at its `§21.4:1175` position, clean idle EOF
  vs `unexpected-eof`, and the split-point invariant (the skeleton is invariant across all 20
  single-cut splits; the raw fragment trace is **not** — the negative sentinel). 12 cases, 27 checks.
- **`byte-machine.differential.http`** (source + aot) — `§25:1648`, the lane every later slice
  extends: interpreter ≡ generated on the result tuple **and** the event trace, for every single-cut
  split, malformed inputs and their positions, `parser-finish!` at every region, and 32 seeded
  multi-split schedules; plus the cross-schedule skeleton invariant. 6 cases, 24 checks.

## The ⓪-table rows this slice makes true, and the one it corrected

Made true (measured through the fixture): `idle`/`method` → `invalid-method` `byte`; `target` →
`invalid-target` `byte`; `version` → `invalid-version` `byte`; `request-line-crlf` →
`invalid-line-ending` `byte`; those four regions and `idle` → `unexpected-eof` on eof;
`idle` eof → clean finish.

**Corrected in place (decision 0034's process working):** Slice ⓪ shipped the eof rows with
position-kind `boundary`; the built fixture reports position-kind **`eof`** for an `unexpected-eof`
raised by `parser-finish!` (`§12.7:405` `byte | boundary | eof`; `§12.7:771` "`eof` at the final
stream offset"). All 17 eof rows are now `eof`, and the ⓪ lane's shape guard admits `eof`. This is
exactly the table-measured-against-the-fixture value the precondition was written first for.

## Mutation pins (pass 62, +3 → 62 passes / 593 mutations)

Three decisions the request line encodes, each caught by the unit lane with a **measured** signature
(not a bare nonzero exit):

| Mutation | Signature | Pins |
| --- | --- | --- |
| idle's tchar edge `reexecute` → `advance` | `method-data "ET"` | the first method byte belongs to the span (0037) |
| method-loop's span-end `reexecute` → `advance` | `method-data "GET "` | a span ends before its delimiter SP (`§21.3:1140`) |
| version `HTTP/1.1` → `HTTP/1.2` | `invalid-version byte 18` | the version production |

## Verification

- Unit lane 12 cases / 27 checks; differential lane 6 cases / 24 checks — both modes, green.
- Full `release` minus the mutation lane — **125/125, 0 failed**.
- Mutation lane — **62 passes / 593 mutations**, Test #29 Passed; the three new pins caught.
- **§4.7 gate**: `git diff --stat main..HEAD -- src/` prints nothing.

## Not in this slice

Headers, the empty line and the no-body message loop (Slice ②); framing recognition and the fixed
body (③); the region → node map's node lists (they fill as regions gain nodes — Slice ① adds no
region→node entries yet, keeping the map's totality row vacuous but now exercised by real nodes in ②+).
