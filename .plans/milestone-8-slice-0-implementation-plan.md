# Milestone 8 Slice ⓪ — the fixture-state → expected-error table

**Status: executed.** Built against `main` at `6c371f8` (the Milestone 8 design #101 and Gate 0 #102
merged), on branch `feat/m8-slice-0`. Discharges `§21.4:1177`'s precondition — the milestone's
first slice, and the one artefact that can be complete before any grammar node exists (decision
[0034](../.decisions/0034-http-error-table-is-first-and-fixture-owned.md)).

## Scope, as an allocation

`§21.4:1177`, addressed to tests: "Before Milestone 8 implementation begins, tests must expand this
catalog into a table mapping every fixture state family to its expected byte, boundary, or EOF
error." Depends on Gate 0 only. **Ships no machine.**

## What shipped

- **`test/support/harness/byte-machine/test/http-error-table.sls`** — the hand-written, exported,
  fixture-owned table. Five exports: `http-error-rows`, `http-error-inapplicable`,
  `http-error-regions`, `http-error-triggers`, `http-error-region-nodes`. Imports only `(rnrs)`.
  A row is `(region trigger code position-kind offset-rule production)` (decision 0034 item 2); a
  `(region trigger)` pair that cannot produce an error is an `http-error-inapplicable` entry
  carrying its reason **as data**. The header states it is the fixture's and never becomes
  `§27:1696`'s catalog (`§21.4:1177` second sentence).
- **`test/common/http-error-table-tests.sps`** — the lane program, `byte-machine.unit.http-error-table`,
  a ratchet that ships green. The eighteen `§21.4` codes are **spelled out in the test** as the
  oracle; the table's rows are checked against them, never the reverse.
- **`test/CMakeLists.txt`** — the `.chez.source` and `.chez.aot` lane pair (harness manifest + the
  table library + the program; no core, the table being pure data).

## The rows this slice makes true

**All of `§21.4`'s eighteen codes**, since the table is the whole error surface (`§21.2`'s regions ×
`§21.4:1175`'s three triggers). Eighteen regions in stream order, from `idle` through
`trailer-value`. Every non-idle region carries an `unexpected-eof` row (`§21.4:1175`'s EOF
sentence); `idle`'s EOF is a clean finish and is an `http-error-inapplicable` entry, not a row
(decision [0037](../.decisions/0037-idle-node-message-begin-and-clean-eof.md)). Later slices restate,
by region and trigger, which rows their nodes make executable.

## The two rows decided with the grammar in front of us (design Appendix)

1. **`forbidden-trailer` is a `byte` at the colon, position-kind `byte`** — not the `boundary` the
   Appendix skeleton guessed. `§21.4:1175`: "at the colon following the completed forbidden name".
   The name's bytes are consumed; the colon is then the first offending **unconsumed** byte, and
   `§21.4:1175`'s first sentence makes a lexical error `byte`. `framing-conflict`, by contrast, is a
   genuine `boundary` — a zero-width decision after the later header line's LF, with no byte of its
   own — and is pinned as `header-crlf boundary boundary`.
2. **`fixed-body` and `chunk-data` reject nothing but EOF.** They consume exactly the counted number
   of octets; their `byte` and `boundary` cells are `http-error-inapplicable` with that reason, and
   only their `eof` cell is a row (`unexpected-eof`). Stated as the claim it is.

## §4.9 item 2 (owner-approved): the fixture-region → node-name map

`http-error-region-nodes` maps every region to its node names. At Slice ⓪ no grammar node exists, so
every region maps to `'()`; the map grows a row's node list per slice, and its totality row —
"every declared node is in exactly one region" — is vacuously true here and bites once nodes exist.

## Oracle (results)

The lane ran **17 cases / 502 checks / 0 failures** in both `source` and `aot` modes. It asserts:

- *Shape* (decision 0034 item 2): every row a six-tuple over the declared domains; every region
  distinct; the three triggers exactly `byte`/`boundary`/`eof`; every inapplicable cell a
  `(region trigger reason)` with a non-empty reason.
- *Totality over the codes* (item 3a): every row code is one of the eighteen (no fixture-invented
  code at ⓪); the row codes contain all eighteen (`§21.4:1154`'s floor); at Slice ⓪ the union
  **set-equals** the eighteen — the "read from the machine" half is Slice ⑤'s, and the file says so.
- *Totality over the grid* (item 3b): every `(region trigger)` is covered by a row **XOR** an
  inapplicable reason; every non-idle region has an `unexpected-eof` row; `idle`'s EOF is a clean
  finish carried as data.
- *The two grammar-decided rows*, pinned exactly (`forbidden-trailer` = `trailer-name byte byte`;
  `framing-conflict` = `header-crlf boundary boundary`; `fixed-body`/`chunk-data` reject nothing but
  EOF).
- *The region → node map*: keys set-equal the regions, each once; every node list empty; no node in
  two regions.

## Verification

- `byte-machine.unit.http-error-table.chez.{source,aot}` — **Passed**, 502 checks each.
- Full `release` minus the mutation lane — **121/121, 0 failed**.
- **§4.7 gate**: `git diff --stat main..HEAD -- src/` prints nothing.
- **No mutation-suite entry.** The table is a self-ratcheting data table, exactly like
  `diagnostic-census` / `kind-position-census` / `error-projection`, none of which the Scheme
  mutation suite targets; the test *is* the ratchet. `EXPECTED_PASSES`/`EXPECTED_MUTATIONS` are
  untouched, and the mutation lane — which reads only `src/` and the generative harness — cannot be
  affected by this additive, test-only change, so it was not re-run.

## Not in this slice

Any grammar node (Slice ①+); the event-order oracle (§4.9 item 1, Slice ①); the "read from the
machine" half of the code set-equal (Slice ⑤); asserting the region names match the fixture's actual
nodes (grows with the map, per slice).
