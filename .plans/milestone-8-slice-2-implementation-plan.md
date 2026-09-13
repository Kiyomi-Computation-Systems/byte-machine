# Milestone 8 Slice ② — headers, the empty line, and the no-body message loop

**Status: executed.** Built against `main` at `c1d1a93` (Slice ① merged, #104), on branch
`feat/m8-slice-2`. `§25:1635-1636` items 3 and 4: the general header name/value spans, the
headers-complete boundary, and the no-body message loop. Depends on ①.

## The machine extension

`http-machine.sls` grows: the `crlf-lf` of the request line now leads into the **header section**
instead of a stop, and `message-complete` loops back to `idle`. Added nodes:

- **`header-line-start`** — a CR begins the empty-line terminator; a `tchar` reexecutes into a header
  name; anything else is `invalid-header-name`. EOF here is a truncated message.
- **`header-name`** span (`1*tchar`, ends before the colon) → `after-hname` requires `:` → **OWS is
  skipped after the colon before the value span opens** (`§21.2:1097`) → **`header-value`** span
  (`*field-value-byte`, ends before CR, keeps internal/trailing OWS). An **all-OWS value** opens and
  closes empty — `header-value-complete` with no `header-value-data`.
- the header line's CRLF, then, for the empty line, `hdrs-end-lf` → **`headers-complete`**
  (`§21.3:1144`, after the CRLF) → **`message-complete`** → `idle` (`§21.3:1150`). No fields yet, so
  no `clear` chain (Slice ③ adds `Content-Length` and the reset).
- error nodes per span state (0036): `e-eof-hname`, `e-eof-hvalue` (span open); `e-hname`,
  `e-hvalue` (no span). Six new callbacks, two new spans, two new error codes. Verifies clean.

## The event-order oracle extension (§4.9 item 1)

`http-event-order.sls` gains a `(rep T...)` term — zero or more repetitions of a sub-sequence — and
`http-request-grammar` becomes the full no-body message: the request-line prefix, then
`(rep header-name-data* header-name-complete header-value-data* header-value-complete)`, then
`headers-complete` and `message-complete`. `header-name-data`/`header-value-data` join the coalesced
data events. The matcher (now `match-terms`, returning the remaining skeleton) stays greedy — the
terminals are distinct, so no backtracking.

## The lanes

- **`byte-machine.unit.http-request-line`** — updated for the new terminal: a bare request line now
  reaches `need-input` at the header section with the request-line event **prefix**; a complete
  no-body message finishes and matches the grammar. Its recorder now binds all twelve callbacks, and
  the split-point group drives a complete no-body message (skeleton invariant across all 22 splits;
  raw trace not). 12 cases, 28 checks.
- **`byte-machine.unit.http-message`** (new) — the header block's events in order, `headers-complete`
  only after the empty-line CRLF, the all-OWS value, the two-request loop (one `message-begin` each,
  the stream offset not reset), and every header error at its `§21.4:1175` position (including
  `unexpected-eof` from each header region). 10 cases, 21 checks.
- **`byte-machine.differential.http`** — extended: interpreter ≡ generated on tuple **and** trace for
  complete no-body messages, header-region errors, header splits, the two-request loop, and 32 seeded
  multi-splits spanning the whole message. 8 cases, 34 checks.

## The ⓪-table rows this slice makes true

`header-name`/`trailer-name`-shaped: `invalid-header-name` `byte`; `header-value`:
`invalid-header-value` `byte`; `header-crlf`: `invalid-line-ending` `byte`; and `header-name`,
`header-value`, `header-crlf` → `unexpected-eof` `eof`. (`header-crlf`'s **boundary** row — the
framing conflicts — is Slice ③/⑤'s; this slice makes the non-framing header rows true.)

## Mutation pass 63 (+3 → 63 passes / 596 mutations)

Three header-section decisions, caught by the http-message lane with measured signatures:

| Mutation | Signature | Pins |
| --- | --- | --- |
| `header-line-start`'s tchar edge `reexecute` → `advance` | `header-name-data "ost"` | the first header-name byte belongs to the span |
| `hn-close`'s `reexecute` → `advance` | `header-name-data "Host:"` | the name ends before its colon |
| `hv-open`'s `reexecute` → `advance` | `header-value-data "xample.com"` | the value opens after leading OWS is skipped |

## Verification

- Unit lanes 12/28 and 10/21; differential 8/34 — both modes, green.
- Full `release` minus the mutation lane — **127/127, 0 failed**.
- Mutation lane — **63 passes / 596 mutations**, Test #29 Passed; the three new pins caught.
- **§4.7 gate**: `git diff --stat main..HEAD -- src/` prints nothing.

## Deferred, and its receiver named

The §4.9-item-2 fixture-region → node-name map (`http-error-region-nodes`) still maps every region
to `'()`. Populating the header/request-line regions' node lists is **deferred**: its only value is
naming a node on a failure, no lane failure needs that yet, and listing node names now would couple
the table to names every slice churns. It lands in the first slice whose debugging wants a failure to
name the node (or Slice ⑤'s close at the latest); the totality row ("every declared node in exactly
one region") stays vacuously true until then. Flagged rather than left silent.

## Not in this slice

Framing recognition, `Content-Length` and the fixed body (Slice ③); the chunked body (④); framing
conflicts, pipelining coverage, malformed sweep and the close (⑤).
