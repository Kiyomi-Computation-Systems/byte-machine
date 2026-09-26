# 0055: The allocation audit is a census of runtime ops

Date: 2026-09-26
Status: accepted
Milestone: none. Follows [0054](0054-a-keyword-walk-reads-its-prefix-in-place.md) and [issue #139](https://github.com/Kiyomi-Computation-Systems/byte-machine/issues/139), after 0.6.0
Builds on: [0040](0040-allocation-audit-is-a-slope-with-a-control.md) (the slope and its live control), [0052](0052-a-callback-outcome-is-the-object.md) (the per-header slope), [0054](0054-a-keyword-walk-reads-its-prefix-in-place.md) (the per-matched-byte shape)

## Context

`§26:1680` says generated per-byte paths construct no lists, vectors, strings
or results, and the release ledger records it `met` on the strength of
`test/common/allocation-audit-tests.sps`. Until 0054 that lane measured one
machine, the HTTP fixture, fed valid messages. Issue #139 was a runtime op, the
keyword walk, that allocated per byte and that the lane never ran, because the
HTTP machine has no keyword table. 0054 fixed the op and added a group that
drives it directly. It did not ask which other ops the lane never ran.

Emitted code reaches the runtime only by name: a generated library imports
`(rnrs)` and `(byte-machine runtime)` and nothing else. So "every generated
per-byte path" is bounded by the set of runtime procedures emitted text can
name, and the audit covers the claim only if its inputs run each one.

Measured before this record, on `main` at `799870b`, with the census below and
no new witness: the emitter can call **twelve** runtime procedures and read one
constant (`callback-pause`). The lane's inputs reached **six**. The six it
never ran were `byte-machine-make-parser-error/v1`,
`byte-machine-make-callback-error/v1`, `callback-failure?`,
`callback-failure-code`, `callback-failure-detail`, and
`byte-machine-keyword-step/v1` as emitted code calls it. (The direct group runs
the op, but not the arm around it.)

## Decision

1. **The op set is derived from the emitter, not declared.** The lane reads
   `compile.sls` as a datum from the tree that is running
   (`BYTE_MACHINE_SOURCE_ROOT`, the diagnostic census's contract), collects
   every string literal, splits them on whitespace and parentheses, and keeps
   the tokens that are live `(byte-machine runtime)` exports. `render-machine`
   builds generated code only from string literals, so an op a new lowering
   calls joins the set when its template is written, whether or not any
   fixture renders it. Comments are not data, and `reserved-member-2` is a
   quoted list rather than a string, so neither counts. Exports that are not
   procedures are constants; emitted code reads them and they cannot allocate.
2. **Reach is counted, not inferred.** Each audited machine is emitted twice:
   once as is, for the allocation measurements, and once as a **counting
   twin**. The twin is the same text with its library name and its runtime
   import changed. It imports a library the lane writes from the live export
   list, which re-exports the runtime with a counter in front of every
   procedure. The import swap must hit exactly once, or the lane raises,
   because a twin still reaching the real runtime would undercount. Allocation
   is measured on the real library and calls on the twin. The code paths are
   the same text.
3. **A witness registers its reach from inside the case that asserts its
   shape.** Each case feeds its inputs to the twin after asserting what they
   allocate. Deleting a witness group deletes its reach, and the totality row
   (`census ops no witness reached`) names every derived op no case ran.
4. **Three witnesses close the gap**, each asserting its answer before its
   allocation, so an arm that stopped being reached cannot pass by allocating
   nothing. The shape each asserts is 0040's: what the event costs does not
   depend on how many bytes came before it. That is what copying the input, or
   a prefix, into a record would break.
   - *A machine error*: an HTTP request refused at a NUL inside a header value,
     after 44 or 40,044 good value bytes. The record reports offsets 40,000
     apart and costs the same.
   - *A callback failure*: `message-complete` answers a failure built once, and
     the seam turns it into a callback-domain error at the message's end, 70 or
     40,070 bytes in, at the same cost. This is what reaches the three
     failure readers and the callback error constructor.
   - *The emitted keyword arm*: the four-header case-insensitive machine fed
     `kw-field k` for k from 0 to 16. Each is refused at byte k by the no-match
     route, and each allocates what k = 0 does. k = 17 takes the keyword.
5. **Where each op sits is measured too.** On the twin, the lane counts every
   op's calls for 40,000 more header-value bytes, 200 more headers, and 16 more
   matched keyword bytes. It asserts that no op's count moves with the value
   bytes or the matched bytes. The slopes gate what an op allocates; this
   records whether the op is on the per-byte path at all. The per-header rates
   are recorded, not asserted.
6. **Three controls keep the derivation honest.** A second method: every
   runtime export the two rendered libraries name, read as data, must be in the
   derived set. A third: every op either twin was seen calling must be in it.
   And `compile.sls` must be exactly one datum, or a census reading only the
   first form would miss what a second one held.

## The census, as measured

Chez 10.4.1, `tarm64osx`, from the lane's own `byte-machine-alloc: op` lines
(`ctest --test-dir build/dev -R allocation-audit.chez.source -V`). The call
counts are for one short valid message with callbacks disabled, then the rate
per added header, then the calls made while each twin loads:

| op | calls / message | calls / header | at load | witness |
|---|---:|---:|---:|---|
| `byte-machine-callback-step/v2` | 8 | 2 | 0 | per-byte and per-header slopes |
| `byte-machine-span-open/v1` | 4 | 2 | 0 | per-byte and per-header slopes |
| `byte-machine-span-fragment-step/v2` | 4 | 2 | 0 | per-byte and per-header slopes |
| `byte-machine-span-close/v1` | 4 | 2 | 0 | per-byte and per-header slopes |
| `byte-machine-make-feed-outcome/v1` | 2 | 0 | 0 | per-byte slope (the feed and the finish) |
| `byte-machine-make-compiled-machine` | 0 | 0 | 1 per machine | loaded, never called during a feed |
| `byte-machine-make-parser-error/v1` | 0 | 0 | 0 | machine-error witness; the keyword arm (k < 17) |
| `byte-machine-make-callback-error/v1` | 0 | 0 | 0 | callback-failure witness |
| `callback-failure?` | 0 | 0 | 0 | callback-failure witness |
| `callback-failure-code` | 0 | 0 | 0 | callback-failure witness |
| `callback-failure-detail` | 0 | 0 | 0 | callback-failure witness |
| `byte-machine-keyword-step/v1` | 0 | 0 | 0 | emitted keyword arm; the direct group (0054) |

No op is entered per byte of a header value or per matched keyword byte. Four
are entered per header. Two per header comes from the two span-complete
callbacks, which are still crossed with no callback bound. Every op the
emitter can call is now reached by an input whose allocation the lane asserts.

## What this does not cover

- **The runtime's own per-feed work.** `parser-feed!`'s boundary flush and
  `make-parser` are not called from emitted code, so they are outside the
  census. The per-byte and per-header slopes run them on every feed, which is
  the coverage they had before.
- **A dimension a witness holds fixed.** The census proves that each op runs,
  not that it runs in the dimension where it would allocate. That is still the
  slope rule's question, asked per witness. The error witnesses vary the bytes
  before the event. They do not vary, for instance, the length of an error
  declaration's reason, which the record carries by reference.
- **A name the derivation cannot see.** A runtime name assembled from two
  literals, in an arm neither rendered fixture contains and no input reaches,
  would pass all three controls. The mutation suite shows each control catching
  the half of this it is for.

## Witnesses

- `byte-machine.unit.allocation-audit` gains four groups: the HTTP slopes'
  reach, the two error-record witnesses, the emitted keyword arm, and the
  census itself (derivation, second method, called ops, per-op placement,
  totality).
- The mutation lane goes from 77 passes and 651 mutations to 77 and 660. Nine
  mutations join Pass 77, the allocation lane:
  - an arm no audited input reaches calls a runtime op nothing else emits;
  - the same op with its name split across two literals, so only the rendered
    libraries carry it;
  - a reached op's name split the same way;
  - a pure op entered per dispatched byte, and one per matched keyword byte,
    neither allocating;
  - the keyword arm allocating per matched byte;
  - each of the two error records growing with its offset;
  - a second datum in `compile.sls`.

  Each was measured against a staged copy. Each pin resolves exactly once in
  its own mutant's output and in no sibling's, and Pass 77's two earlier
  mutants are included in both directions of the sweep.
