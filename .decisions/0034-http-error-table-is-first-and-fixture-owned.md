# 0034: The HTTP error table is the milestone's first artefact, and it is fixture-owned

Date: 2026-09-12
Status: accepted
Milestone: 8, Gate 0 (milestone-8-design.md §4.1)

## Context

Decided against `main` at `bf6e56d` — the Milestone 8 design (PR #101) written against
`741e0ca` and rebased `--onto main 741e0ca` onto Milestone 7's squash. `src/` and `test/` are
byte-identical between `741e0ca` and `main` (`git diff --stat 741e0ca..main -- src/ test/` prints
nothing), so every count the design measured carries over unchanged.

**What the parent plan leaves open.** `§21.4:1177` is a precondition addressed to *tests*, in these
words: "Before Milestone 8 implementation begins, tests must expand this catalog into a table
mapping every fixture state family to its expected byte, boundary, or EOF error. The table is
fixture-owned and does not become a generic byte-machine error catalog." It does not say what a row
is, where the table lives, or how "expand" is checked — and every later slice is measured against
its rows, which is why the answers are a record.

**The catalog as shipped, measured** (each read at `bf6e56d`):

- **Eighteen stable codes.** `§21.4:1156-1173` lists, in order, `invalid-method`, `invalid-target`,
  `invalid-version`, `invalid-line-ending`, `invalid-header-name`, `invalid-header-value`,
  `duplicate-content-length`, `invalid-content-length`, `content-length-overflow`,
  `duplicate-transfer-encoding`, `unsupported-transfer-encoding`, `framing-conflict`,
  `invalid-chunk-size`, `chunk-size-overflow`, `invalid-chunk-extension`, `invalid-chunk-ending`,
  `forbidden-trailer`, `unexpected-eof` — counted from the list at `bf6e56d`, not transcribed from
  memory. `§21.4:1154`'s verb is "include", so the list is a **floor, not a ceiling**.
- **Five position sentences** (`§21.4:1175`): a lexical error at the first offending **unconsumed**
  byte; numeric overflow at the digit that would overflow, left unconsumed; a duplicate/conflicting
  framing error at the **between-byte boundary** after the later header line's LF; a forbidden
  trailer at the **colon** following the completed forbidden name; EOF in any non-idle state as
  `unexpected-eof` at the final stream boundary.
- **`§27:1696`'s diagnostic catalog is a different, unscheduled document.** Milestone 7's design §10
  says so; this table is not its first instalment.
- **The ratchet technique exists and is Milestone 7's.** Decision
  [0032](./0032-diagnostic-record-seven-fields-and-path-policy.md) and the totality-row discipline
  (a set-equal against a floor read from the artefact, not transcribed) are the shape this record
  reuses.

## Decision

**1. Slice ⓪ ships the table first, and it ships no machine.** The table is the one artefact that
can be complete before any grammar exists; written *after* the fixture it would be a transcription
of what the fixture does, and written *first* it is the thing the fixture is measured against. Slice
⓪ therefore depends on Gate 0 only, ships a hand-written exported table library and its test lane,
and builds no fixture node. *Rejected, with the failure it would cause*: folding the table into the
first grammar slice (①) — the rows would be read off the nodes, and the precondition's entire value,
that the rows predate the nodes, would be lost with no trace that it ever held.

**2. A row is `(state-family trigger expected-code position-kind offset-rule)`.**
`state-family` is a named region of `§21.2`'s grammar, **not a node name** — `request-line`,
`method`, `target`, `version`, `header-name`, `header-value`, `content-length-value`, `fixed-body`,
`chunk-size`, `chunk-ext-name`, `chunk-ext-value`, `chunk-data`, `chunk-ending`, `trailer-name`,
`trailer-value`, `idle` and the CRLF regions — so a row survives the node renames every later slice
performs. `trigger` is one of the three symbols `byte`, `boundary`, `eof`, matching `§21.4:1175`'s
three sentences. `expected-code` is one of the eighteen. `position-kind` and `offset-rule` restate
`§21.4:1175` per row as data. A cell the region cannot produce carries its **reason as data**, not
as a comment or an omission.

**3. Two totality rows, on Milestone 7's ratchet and for its reason.** (a) The union of the table's
`expected-code` column **set-equals** the codes the fixture's own error declarations name, read from
the machine rather than transcribed — so a nineteenth code cannot ship without a row — **and
contains all eighteen** `§21.4` names. Both halves are load-bearing: `§21.4:1154` says the list
"include"s those codes, so the spec is a floor a table checked only against it would let a
fixture-invented code slip past. At Slice ⓪ the "read from the machine" half has no machine to read,
so it is asserted against the eighteen alone and the design records that ⑤ closes the set-equal once
the declarations exist. (b) Every `state-family` the table names has **at least one row of each
trigger kind it can produce**, and a family that cannot produce one names its reason as data.

**4. The table is fixture-owned and never becomes a generic catalog.** `§21.4:1177`'s second
sentence is a scope constraint. The table lives in a fixture-owned library beside the fixture, its
header states in the file that it is the HTTP fixture's and that `§27:1696`'s catalog is a
different, unscheduled document, and the §4.7 gate plus Slice ⑤'s leak check assert no `src/`
library imports it. *Rejected*: a shared `(byte-machine …)` error-catalog library — `§21.4:1177`
forbids it in those words, and it would couple every future grammar's error vocabulary to HTTP's.

## Consequences

- **Handed to Slice ⓪**: the table library
  (`test/support/harness/byte-machine/test/http-error-table.sls`), its lane pair
  (`byte-machine.unit.http-error-table`), the eighteen-code floor spelled out in the test, the two
  totality rows in the form item 3 permits at ⓪ (no machine yet), and — per §4.9 item 2, approved by
  the owner — the exported fixture-region → node-name map, which starts empty and grows a row per
  slice.
- **Handed to every later slice**: each slice's plan states which rows it makes true, by region and
  trigger (design §12); that is how the table stops being a document and becomes the milestone's
  spine.
- **Handed to Slice ⑤**: the "read from the machine" half of the code set-equal, once the fixture's
  error declarations exist, and the leak check that asserts the table is imported by no `src/`
  library.
- **Two rows the table cannot fill from reading**, left to Slice ⓪ with the grammar in front of it
  (design Appendix): whether `forbidden-trailer` is a `byte` at the colon or a `boundary` after the
  name completes (`§21.4:1175`'s "at the colon following the completed forbidden name" reads as the
  colon unconsumed, therefore `byte`), and whether `fixed-body` and `chunk-data` can produce any
  non-EOF error once the count is fixed (they consume exactly N octets and reject nothing, so the
  *—* is expected to survive — but it is a claim, stated as one).
