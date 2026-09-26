# 0054: A keyword walk reads its prefix in place

Date: 2026-09-26
Status: accepted
Milestone: none. From [issue #139](https://github.com/Kiyomi-Computation-Systems/byte-machine/issues/139), filed from chez-http-server's M3 exit record, after 0.6.0
Builds on: [0044](0044-keyword-table-lowers-to-a-compact-table-and-bumps-the-abi.md) (the walk and its `/v1` contract), [0040](0040-allocation-audit-is-a-slope-with-a-control.md) and [0052](0052-a-callback-outcome-is-the-object.md) (the allocation audit's two slopes)

## Context

`byte-machine-keyword-step/v1` is the runtime walk every keyword-table state
calls (0044). For each byte it consumed it built the prefix matched so far as a
new list, `(append p (list b))`, so a walk matching k bytes copied 1 + 2 + ... + k
pairs, and it closed a fresh `exists` predicate over each copy.

The HTTP grammar downstream runs five tables, and one of them is every header
name. A header whose name matches k bytes of `transfer-encoding` therefore cost
about k²/2 pairs. The issue measured this in chez-httparse and chez-http-server:
+16 B for each matched byte beyond the one before, 2,944 B for one
`Connection: keep-alive` field, and 297,767 B for a 2,162-byte request carrying
97 `Transfer-Encodinx` fields. That is 138 times the request's own size, driven
by the client.

**The allocation audit could not see it.** Its HTTP fixture has no keyword
table. Its two slopes (per byte in 0040, per header in 0052) both hold a
header name's match length fixed. So `§26:1680`'s "generated per-byte paths
contain no deliberate list ... construction" was recorded `met` while every
keyword state reached a per-byte list construction through the runtime. This is
[the slope rule](../AGENTS.md) ("a slope is blind in the dimension it holds
fixed") a third time, and it is the first time the dimension ran through the
runtime instead of the emitted text.

## Decision

1. **The walk reads its prefix where it lies, once per entry.** Greedy
   consumption, which goes on while some keyword agrees one byte further, stops
   exactly where the **longest** prefix any keyword shares with
   `path ++ bv[pos, end)` ends. So one pass over the entries finds that length
   and the terminal together. `kw-common` compares each entry against the parked
   `path` and then against `bv`, in place, and returns how far they agree and
   whether that is the whole keyword. The terminal is the entry covered whole at
   the longest length. At most one entry can be: two would be equal, which the
   verifier refuses (`duplicate-keyword`, `case-insensitive-keyword-collision`).
   A list is built only for a `need` answer, because the arm parks the prefix as
   the compound `(state-id . path)` and needs one. When the call consumed nothing
   (the finish path enters at `pos = end`), the parked `path` is handed back as
   the same object.
2. **The `/v1` contract is unchanged.** The arguments, the two answers, the
   no-backtracking result and the fold are the same, so no generated parser
   needs regenerating and no golden moves. The issue proposed reading in place
   but kept the byte-by-byte loop; this record goes one step further. Both were
   checked against the invariants the walk rests on (the AGENTS.md rule for
   outside proposals). The parked-prefix representation the emitted arm stores
   and passes back is still a byte list in order. The delimiter is still left
   unread at position `i`. And the walk never stops before the length it
   resumed at, which the old loop had by starting there and which the scan has
   by starting `best` at `(length path)`.
3. **The audit gains a third dimension: bytes matched per keyword.** The
   allocation lane drives the op directly over the five header names downstream
   reads by name. It asserts **the shape, not a number**: for every k from 0
   to 17, one walk allocates what k = 0 allocates. A resumed walk allocates
   what a fresh one does, and a walk that consumed nothing allocates the same
   whatever its parked prefix. The live control is the pre-fix walk, kept in
   the test verbatim. It must allocate more at k = 16 than at k = 1, or the
   apparatus cannot see the defect (0040 item 2, a third time).

## What it costs

Chez 10.4.1, `tarm64osx`, the op alone. Three runs of
`chez --libdirs src --script bench/runner/keyword-walk.sps` from the repository
root, which drives 200,000 walks per cell over `kw-field k` against the
five-name case-insensitive table, beside the pre-fix walk. The allocation lane
carries the same control. The ranges below are across the three runs:

| k | copying: B/call | copying: ms | one pass: B/call | one pass: ms |
|---:|---:|---:|---:|---:|
| 0 | 144 | 18.2–19.4 | **64** | 6.0–6.2 |
| 4 | 496 | 51.9–55.9 | **64** | 8.9–9.3 |
| 10 | 1,504 | 127.2–137.4 | **64** | 13.0–13.8 |
| 17 | 3,408 | 267.1–278.7 | **64** | 17.7–17.9 |

The allocation column is exact: the lane asserts its shape to the byte and
records `keyword walk B/call=64`. Time now grows linearly in k, 3× from k = 0 to
k = 17, where the copying walk grew 15×. That is 15× faster at k = 17. This
is not an admission under 0048, because the bench machine has no keyword table
and `§23.3`'s instrument cannot see this op. The driver is not a gating lane.

A first version of this fix, following the issue's patch, read in place but
kept the byte-by-byte loop. It re-compared the whole prefix against every entry
at each byte, so it was still O(entries × k²): 12.4 to 223.6 ms across the same
k range. A review of that version named the cost, and the single pass replaced
it before merge. The issue's own in-situ figures, measured through chez-httparse
and chez-http-server with that first patch, are in the issue: the base request
drops from 1,600 B to 704 B, and the worst case from 297,767 B to 6,784 B. The
allocation half of those figures holds for this version too, since both
allocate only the answer.

## What this does not fix

Two costs remain. Neither is measured in situ, and each has a way to settle it:

- **Every entry is compared on every walk.** A call is O(entries × k), so the
  47-method table pays 47 comparisons at the first byte even when the byte rules
  out all but one. A lexicographically sorted table would let the live keywords
  narrow as a range by binary search. That changes what the emitted arm embeds,
  so it would be a `/v2` op and a golden move. It is worth doing if
  chez-httparse's whole-buffer msg/s, measured in situ as 0053 measured the
  feed entry, moves by 0048's material threshold. It has not been tried.
- **A byte-at-a-time feed still copies the prefix once per feed.** Each `need`
  answer builds `path ++ bv[pos, i)`, so a keyword fed one byte per feed costs
  O(k²) pairs across the feeds. That is the same as before, and it is inherent
  to parking the prefix as an in-order list. A reversed or counted
  representation would move the compound `current` the emitted arm stores. It
  is worth doing only if the `byte-at-a-time-fragmentation` cell, on a machine
  with a keyword table, shows it.

## Witnesses

- `byte-machine.unit.allocation-audit` has the group "the keyword walk
  allocates nothing per matched byte (issue #139)": the live control and three
  shape cases, plus the `need` answer checked for content.
- `byte-machine.differential.keyword-table` has the group "the walk reads its
  parked prefix and this feed's bytes in place". It adds a GET/SET table whose
  keywords agree after their first byte, one input per wrong way of comparing,
  counting, choosing or parking, and two direct op calls: a parked capital on a
  case-insensitive table, and a parked prefix that begins no keyword. The
  generated side is asserted absolutely.
- The mutation lane goes from 76 passes and 637 mutations to 77 and 651.
  Twelve mutations join Pass 67 and two form the new Pass 77, which is the
  allocation lane. Every new pin resolves exactly once in its own mutant's
  output and in no sibling's (a whole-pass sweep in both directions). One of
  them, the parked-fold pin, needs two records together: each of its records
  is shared with a different sibling. One shipped pin was re-anchored, the
  generated terminal-length pin, onto `whole?`, which is where the terminal
  decision now lives.
