# 0035: Case-insensitive framing recognition is a byte-set chain with reexecuting fallbacks

Date: 2026-09-12
Status: accepted
Milestone: 8, Gate 0 (milestone-8-design.md §4.2)

## Context

Decided against `main` at `bf6e56d`; `src/` and `test/` byte-identical to `741e0ca`, the base the
design measured (0034's Context).

**What the parent plan constrains.** `§25:1637` item 5 is "case-insensitive fixture recognition of
framing headers". `§21.5:1181` puts *all* recognition in declared graph nodes and `§21.5:1189`
forbids a callback parsing header contents in those words. `§21.2:1101` adds that "ordinary header
names remain opaque spans" — so recognition must not cost the opaque path its bytes. `§16.2:893`'s
overlap rule refuses a dispatch node whose cases' byte sets intersect.

**What the design measured, by prototype (P1, at `741e0ca`; reproduces at `bf6e56d` because the
mechanism is byte-identical).** The recognizer is not yet in the tree — it is Slice ③'s — so these
are prototype numbers, re-measured through the registered lane when ③ lands:

- the two framing-header recognizer chains plus an opaque-name loop, with the header-name span open
  across both, **emitted and loaded**; the probe **verifies**; interpreter ≡ generated on all eight
  inputs;
- `Content-Length:` / `content-length:` / `CoNtEnT-lEnGtH:` / `Transfer-Encoding:` → recognized;
  `Conx:` / `Content-Lengthy:` / `X:` → opaque, **each delivering every byte it consumed**;
- **28 925** emitted bytes for the recognizer alone. Milestone 7 Slice ④'s `§16.2:911` witness
  already compiled a larger generated library with `compile-file` and ran it, so emission size is a
  measurement to take, not a risk.

## Decision

**1. One dispatch node per grammar character; each node carries exactly one case.** The case's
matcher is the `byte-set` of that character's two cases (one byte where the character has no case,
such as the hyphen), advancing to the next node. Because a node has exactly one case, `§16.2:893`'s
overlap rule is satisfied **by construction** — no node needs `tchar` minus the accepted bytes, and
the first draft that computed set differences is not built. *Rejected, with the failure it would
cause*: a case whose matcher is `tchar` with a fallthrough — it overlaps the accepted byte and the
verifier refuses it at `§16.2:893`.

**2. The fallback of every chain node reexecutes into the generic opaque-name loop.** A mismatch
hands control to the opaque loop **without consuming** the current byte, so the byte is re-read
there. This is why no case-set arithmetic is needed (item 1) and why the opaque path keeps its
bytes (item 3).

**3. The header-name span is opened before the chain and closed at the colon, so it accumulates
every consumed byte on both paths.** `Conx:` delivers `Conx`; `Content-Lengthy:` delivers
`Content-Lengthy` — measured, both lanes. *Rejected, with the failure it would cause*: a recognizer
built from a `sequence` node — `§21.2:1101`'s case-insensitivity would need 2^13 and 2^16
alternatives, and a sequence mismatch has no way to hand the consumed prefix to a span, so the
opaque name would lose its bytes.

**4. Recognition never lives in a callback.** `§21.5:1189` forbids it in those words; a callback may
record but not decide.

**5. The cost, to be re-measured through the lane in Slice ③.** `Content-Length` is thirteen nodes
after the shared first-byte dispatch, `Transfer-Encoding` sixteen; with the branch node and the
opaque loop that is **31** nodes. The **28 925** emitted bytes are P1's and are re-measured, not
copied, when the lane exists.

## Consequences

- **Handed to Slice ③** (design §8): the two recognizer chains built through `(byte-machine graph)`
  only, the opaque loop, the header-name span open across both paths, and a recognition oracle — a
  table of names (canonical, lowercase, mixed case, a prefix, an extension, a near miss) each
  asserted to hit or miss **and** to deliver its whole name as span data. `Transfer-Encoding`'s
  value is a second, shorter application of the same chain (case-insensitive `chunked`).
- **A mutation pin per recognizer node's byte set**, its failure signature asserted, never a bare
  nonzero exit (design §12; AGENTS.md).
- **Not decided here**: the exact node count and emitted-byte literal, which Slice ③ measures
  through the registered lane and writes into the comment and the pin then.
