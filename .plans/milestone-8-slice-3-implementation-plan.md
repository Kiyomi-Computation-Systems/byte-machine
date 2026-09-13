# Milestone 8 Slice ③ — framing recognition and the fixed body

**Status: executed.** Built against `main` at `83460e3` (Slice ② merged, #105), on branch
`feat/m8-slice-3`. `§25:1637-1638` items 5 and 6: case-insensitive recognition of the framing
headers, checked `Content-Length`, and the fixed body. Depends on ②. **This is the slice decision
[0035](../.decisions/0035-case-insensitive-recognition-is-a-byte-set-chain.md)/§4.2 exists for.**

## The recognizer (decision 0035)

`http-machine.sls` opens the header-name span, then dispatches the first byte into the framing
recognizers. A generator, `recognizer-chain`, builds one dispatch node per grammar character (its
matcher the byte-set of that character's two cases, `both-cases`, so `§16.2:893`'s overlap rule
holds by construction); each node **advances** to the next and its fallback **reexecutes** into the
opaque loop — so the opaque path keeps every byte (`Conx` delivers `Conx`, `Content-Lengthy`
delivers `Content-Lengthy`). `Content-Length` is 13 chain nodes after the shared first-byte
dispatch, `Transfer-Encoding` 16; `chunked` is a third 7-node chain for the value. Every name —
recognized or opaque — is delivered whole as `header-name-data` (§4.2).

## Content-Length, the fixed body, and Transfer-Encoding

- **The value is a header-value span AND accumulated** (§21.3): the digits are delivered as
  `header-value-data` and drive a base-10 checked `u64` accumulation into the `content-length` field;
  `invalid-content-length` for a non-digit, `content-length-overflow` at the offending digit
  (`§12.7:773`).
- **The fixed body** is a counted consume of exactly `content-length` octets inside the `body` span,
  with **no completion callback** (`§21.3:1145`); `Content-Length: 0` is an empty body straight to
  `message-complete`.
- **`Transfer-Encoding`'s value** is the case-insensitive `chunked` recognizer plus optional trailing
  OWS; anything else is `unsupported-transfer-encoding`. The chunked *body* is Slice ④'s — a
  `chunked-todo` **input-reading** placeholder (not a stop, so it is not an EOF-reachable stop,
  `§16.2:909`; EOF there is a truncated chunked message) that ④ replaces.

## The framing refusals (decision 0035, P2)

Three `u8` framing fields (`content-length`, `has-cl`, `has-te`) reset by the completion `clear`
chain (`§21.3:1150`). Each framing header line, **after its LF is consumed**, runs a zero-width
`field-branch` chain: a second `Content-Length` is `duplicate-content-length`, a second
`Transfer-Encoding` is `duplicate-transfer-encoding`, and one framing header after the other is
`framing-conflict` — each reported at the **between-byte boundary** (P2's measurement, `§21.4:1175`),
then the flag is set.

## The oracle extension

`http-event-order.sls` adds `body-data` to the data events and `(star body-data)` between
`headers-complete` and `message-complete` — the fixed body (Slice ④ inserts the chunk sub-grammar
there).

## Lanes

- **`byte-machine.unit.http-framing`** (new) — the recognizer hit/miss table keeping opaque bytes;
  the value span + fixed body + `Content-Length: 0`; `invalid-content-length`/`content-length-overflow`
  at their bytes; the three framing refusals at their boundaries; and the body across every split.
  10 cases, 26 checks.
- **`byte-machine.differential.http`** — a framing group: interpreter ≡ generated on recognized/opaque
  names, the fixed body, every framing refusal, and a Content-Length message at every split. Now 10
  cases, 45 checks.
- `unit.http-request-line` / `unit.http-message` — unchanged and green (opaque headers behave
  identically through the recognizer).

## The ⓪-table rows this slice makes true

`content-length-value` → `invalid-content-length` `byte`, `content-length-overflow` `byte`;
`transfer-encoding-value` → `unsupported-transfer-encoding` `byte`; `header-crlf` **boundary** →
`duplicate-content-length`, `duplicate-transfer-encoding`, `framing-conflict`; `fixed-body` → its `—`
cells confirmed (it rejects nothing but EOF).

## Mutation pass 64 (+3 → 64 passes / 599 mutations), and a re-anchor

Three framing decisions, caught by the http-framing lane with measured signatures:

| Mutation | Signature | Pins |
| --- | --- | --- |
| `both-cases` collapses to one case | `hit: content-length -- expected error` | recognition is case-insensitive |
| `cl-line-done` `nonzero`→`zero` | `duplicate-content-length boundary 35` | the duplicate is checked at the line boundary |
| `cl-value` base 10→16 | `content-length-overflow byte 48` | Content-Length is base-10 |

**Re-anchored** pass 63's "header name consumes its colon" pin ([[sites-assertion-fails-both-directions]]):
Slice ③'s `cl-end`/`te-end` also reexecute into `hn-close`, so `(make-edge 'hn-close 'reexecute)`
now occurs three times; the FIND now includes `hn-loop`'s own self-loop line to stay one site.

## Verification

- `unit.http-framing` 10/26; `differential.http` 10/45; the ② lanes unchanged and green — all modes.
- Full `release` minus the mutation lane — **129/129, 0 failed**.
- Mutation lane — **64 passes / 599 mutations**, Test #29 Passed; the three new pins caught, the
  re-anchored pin single-site.
- **§4.7 gate**: `git diff --stat main..HEAD -- src/` prints nothing.

## Deferred (receiver named)

The §4.9-item-2 region → node-name map is still empty (as ②); population lands when a failure needs
to name a node, Slice ⑤ at the latest.

## Not in this slice

The chunked body, chunk extensions, the zero chunk and trailers (Slice ④); framing conflicts as a
full malformed sweep, pipelining coverage and the close (⑤).
