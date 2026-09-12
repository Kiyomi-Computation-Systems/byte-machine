# Milestone 8 Slice ④ — the chunked body, extensions, the zero chunk, and trailers

**Status: executed.** Built against `main` at `4d48062` (Slice ③ merged, #106), on branch
`feat/m8-slice-4`. `§25:1639-1640` items 7 and 8. Depends on ③. Replaces the `chunked-todo`
placeholder with the real chunked body.

## The §4.5 trailer node-sharing measurement (resolved)

The design handed this slice a measurement: share the header nodes for trailers, or duplicate them?
**Resolved: duplicate, by structural necessity.** Trailers fire *distinct* events
(`trailer-name-data`/`trailer-value-data`) bound to *distinct* spans (`trailer-name`/`trailer-value`),
and a span-start node names exactly one span — so the name/value reading nodes cannot be shared with
the header section (which opens `header-name`/`header-value`). Sharing was never a node-count
tradeoff; it is precluded. The trailers duplicate the header shape with their own spans.

## The chunked body

After `headers-complete`, a `Transfer-Encoding: chunked` message (has-te set) enters the chunked body:

- **chunk-size** — `1*HEXDIG`, base-16 checked `u64` accumulation, leading zeroes permitted
  (`§21.2:1108`); `invalid-chunk-size` for a non-HEXDIG, `chunk-size-overflow` at the offending digit.
- **chunk extensions** — `*(";" token ["=" token])`, names and values as spans excluding their
  `;`/`=` delimiters (`§21.3:1147`); a non-token byte is `invalid-chunk-extension` (quoted values are
  excluded, `§21.2:1109`).
- **`chunk-header`** after every chunk-size line CRLF, exposing the checked size (`§21.3:1146`); a
  zero-width `field-branch` on the size routes a nonzero chunk to its data and the zero chunk to the
  trailers.
- **chunk data** — a counted consume of `chunk-size` octets inside a **fresh `body` span per chunk**,
  no completion callback (`§21.3:1145`); `chunk-complete` after the data-terminating CRLF
  (`§21.3:1148`); `invalid-chunk-ending` when that CRLF is absent. The per-chunk `chunk-size` is
  cleared before the loop repeats.
- **the zero chunk → trailers** — the trailer section reuses the header grammar with distinct
  trailer spans; a recognized `Content-Length`/`Transfer-Encoding` trailer name is **forbidden at the
  colon** (`§21.2:1110`, `forbidden-trailer` = a `byte` at the colon) via two more generated
  recognizer chains that open the `trailer-name` span. `message-complete` after the trailer section's
  terminating CRLF; the `clear` chain now also resets `chunk-size`.

## The oracle extension

`http-event-order.sls` gains an `(opt T…)` term and the full body sub-grammar: after
`headers-complete`, `(star body-data)` (fixed) then the chunked structure — `(rep <nonzero chunk>)`,
`(opt <zero chunk>)`, `(rep <trailer>)` — then `message-complete`. The matcher stays greedy and
functional (a group that partially matches then fails leaves the position for the following `opt`,
which is how the zero chunk's lone `chunk-header` is told from a nonzero chunk's). Verified against
no-body, fixed, one-chunk and multi-chunk-with-extension-and-trailer traces.

## Lanes

- **`byte-machine.unit.http-chunked`** (new) — the chunk events in order (framing octets never body
  data), two chunks each a fresh body span, leading-zero sizes, extension name/value spans,
  `invalid-chunk-size`/`chunk-size-overflow`/`invalid-chunk-ending`/`invalid-chunk-extension` at
  their bytes, permitted vs `forbidden-trailer` (and the opaque `Content-Lengthy` allowed), and a
  chunked message across every split. 12 cases, 21 checks.
- **`byte-machine.differential.http`** — a chunked group, and its recorder now binds **every**
  callback so the interpreter-vs-generated trace comparison covers the body/chunk/trailer events too.
  12 cases, 54 checks.
- The ①–③ lanes are unchanged and green.

## The ⓪-table rows this slice makes true

`chunk-size` → `invalid-chunk-size` `byte`, `chunk-size-overflow` `byte`;
`chunk-ext-name`/`chunk-ext-value` → `invalid-chunk-extension` `byte`; `chunk-ending` →
`invalid-chunk-ending` `byte`; `trailer-name` → `invalid-header-name` `byte` and `forbidden-trailer`
`byte`; `trailer-value` → `invalid-header-value` `byte`; `chunk-data` → its `—` cells confirmed
(rejects nothing but EOF); and `unexpected-eof` `eof` from every new region.

## Mutation pass 65 (+3 → 65 passes / 602 mutations)

| Mutation | Signature | Pins |
| --- | --- | --- |
| chunk-size base 16→10 | `invalid-chunk-extension byte 46` | chunk sizes are base-16 |
| `chunk-body-decide` `nonzero`→`zero` | `trailer-name-data "HELLO"` | the size decides body vs trailers |
| `tcl-end` colon → not forbidden | `Content-Length trailer -- expected (forbidden-trailer byte 63), got #f` | a CL trailer is forbidden |

## Verification

- `unit.http-chunked` 12/21; `differential.http` 12/54; the ①–③ lanes unchanged and green — all modes.
- Full `release` minus the mutation lane — **131/131, 0 failed**.
- Mutation lane — **65 passes / 602 mutations**, Test #29 Passed; the three new pins caught.
- **§4.7 gate**: `git diff --stat main..HEAD -- src/` prints nothing.

## Deferred (receiver named)

The §4.9-item-2 region → node-name map is still empty; population lands in Slice ⑤ (the close) or when
a failure needs to name a node.

## Not in this slice

Framing conflicts as a full malformed sweep of Slice ⓪'s table, pipelining coverage, the leak check,
the determinism golden, and the milestone close — all Slice ⑤.
