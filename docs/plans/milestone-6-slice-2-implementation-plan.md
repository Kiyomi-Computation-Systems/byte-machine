# Milestone 6 — Slice ② (span interaction, pause at fragment boundaries, and the close) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

Authority: `milestone-6-design.md` §7 (the slice), §4.8 (the span interaction is
the runtime's, not the arm's), §4.11 (the five obligations, each to be disposed),
§8 (what stays out, and the one deferral this slice writes both ends of), §9 (the
close-out's three questions) and its Exit table; [decision 0030](../decisions/0030-counted-consume-is-input-reading-with-a-zero-count-route.md)
item 2 (count completion wins, and the exact case's placement is asserted as a
value per feed); then the parent plan: `§25:1599` (span interaction), `§25:1600`
(pause at body fragment boundaries), `§25:1608`'s **fragment** clause, `§25:1609`'s
span variant, `§10.6:603-604`, `§14:830-843` (the fragment rules), `§21.3:1145`
(one span, no completion callback, for a fixed-length body), `§22.5:1278-1289`
(schedules, coalescing, the error path), `§25:1615` (Milestone 7's scope, the
receiver of the one deferral).

This slice adds **no mechanism** (design §4.8): every rule it exercises already
runs at the `parser-feed!` seam or in the span-end substeps, and Slice ① showed
the placement value holding as one case. What it adds is the **oracle** — the
fragment trace with per-feed event placement over every schedule, in both lanes
— a body-shaped arm in the retention lane, and the milestone's **close-out**: the
`§25:1593-1609` disposition, the five obligations of §4.11 disposed with both
ends, the Exit table's remaining rows, the deferral of the reachability narrowing
to Milestone 7, and every status surface.

Everything below was measured at **`8ec814f`** (`main` after PR #79, Slice ①):
`release` **112/112**; Scheme mutation suite **57 passes / 520 mutations**; the
diagnostic census **30 codes over 56 sites**. Every `§N:LINE` was resolved by
opening the parent plan at that line; every `file:line` names its construct.

---

## 1. Twelve findings from re-measuring what Slice ① shipped (design §9)

### F1 — the placement value already holds as one case, on a machine defined inside Slice ①'s program

`differential-counted-tests.sps`, group "Slice ②'s placement oracle, one case
(§10.6:603)", drives a span-wrapped message loop **with a completion callback**
byte-at-a-time and asserts, per lane, that the `c` feed records `((data 1)
complete)` and the `,` feed records nothing. The machine is a `define` inside
that program (`make-span-loop`). It stays there as Slice ①'s witness; this slice
puts the machine into `test/support/harness/byte-machine/test/counted-machine.sls`
as `(make-counted-span-machine complete?)` — two variants, because the emitter
renders two span-completion arms and only one is a call (Milestone 5 Slice ③'s
reason for two machines; `§10.4:516` makes the completion callback optional) —
so the new lane, the mutation pass's baseline and both CTest lanes share it.

### F2 — the completion event is observable only through the completion callback

The recorder records `complete` through the `ondone` closure and nothing else
(Slice ①'s plan, F10). The **bare** variant — `§21.3:1145`'s fixed-body shape,
"one span with no span-complete callback" — has no such event to place, so its
placement is observed differently: after the feed that delivers the last body
byte, `parser-active-span` answers `#f` in both lanes (the span closed in that
feed) and the data fragment for that byte was delivered by the span-end substep,
not by a boundary flush — which the trace cannot tell apart, but the active-span
value can.

### F3 — "no mechanism" is measurable, and stronger than §7 says

§7's oracle 4 allows comment-only hunks in `runtime.sls` and `compile.sls` for
the two receiver notes the close-out was to rewrite. Both were rewritten already:
`make-callback-failure`'s by Slice ⓪ (design §4.11 item 3) and the field-action
arm's by Slice ① (§4.9). So this slice touches **neither file at all**, and the
gate is `git diff 8ec814f..HEAD -- src/byte-machine/runtime.sls
src/byte-machine/compile.sls` printing **nothing**. The only hunk under `src/` is
the `pass-reachability` comment in `verify.sls` (F8), a deferral's source end.

### F4 — the six rules over a counted body reuse the span lane's machinery, not its machine

`differential-span-tests.sps` ships the recorder-per-lane (`recorder`, `:146`),
the lane runner (`make-lane`, `run`, `both`), `record-span` (feed a schedule,
finish, return the trace), `coalesce`, and a schedule generator (`span-splits`,
`span-pairs`, `span-others`, `all-schedules`, thirty-seven schedules over a
five-byte payload). Its machine has a **byte dispatch** inside the span and a
delimiter byte to close on; this slice's has a **counted consume**, so the span
end is reached by count completion and there is no delimiter inside the span —
exactly the difference that makes decision 0030 item 2's placement visible. The
new program copies the helpers and generates its schedules over `3:abc,` (six
bytes): seven split points, twenty-eight ordered pairs, and the span lane's ten
"others" adapted — the sentinel reads the observed count and the generator's
length, as the span lane's does.

### F5 — the pause during the flush must show the count surviving

Rule 8 (`§14:837`, `§25:1600`): a data callback returning `callback-pause` at the
boundary flush after a **partial** commit. The feed reports `paused` with the
need-input tuple's cursor and offset (the flush moves neither), the span stays
open, and — the part a byte-dispatch body cannot show — the field still holds the
remaining count: `parser-field-ref` reads it after the pause, `parser-resume!`
then the next feed consumes exactly that many bytes and completes the span. The
flush touches no field; the assertion is what makes that a fact rather than an
assumption.

### F6 — the retention arm fits the shipped probes without changing them

`retention-tests.sps`' probes feed the fixed payload `A b c d Z` (`fresh-payload`,
`:114`) in one feed, and `A b` then `c d Z` from two different bytevectors
(`fresh-head`/`fresh-tail`). A machine whose body is a counted consume of three
(`A` opens, the count takes `bcd`, `Z` follows the span end) consumes the same
five bytes under both probes: the split probe leaves the span open after `b`
with a count of two — the flush delivers `b` out of the first bytevector — and
the second feed completes the count, closes the span and stops on `Z`. So the
arm is a second machine (`retention-counted-machine`, defined inline as the
shipped one is, so the retention lanes' `SOURCES` do not change) driven by the
**same** probes: layer 1 (gone, both lanes, one feed and split), and layer 2's
negative controls on it (`stashing` for the one-feed probe and `stashing-first`
for the split probe must read RETAINED on the counted machine too, or the arm is
not falsifiable). Design §7 asks for "the same three-layer oracle"; layer 3's
carriers — user context, a callback closure, the failure detail — are
application-owned and machine-independent, so the counted machine adds no arm
there, and this is a stated deviation, not an omission. Of the three shipped
retention pins only "runtime: the fed bytevector is stored in the parser and
survives the return" can redden the counted arm; the sweep confirms that it does.

### F7 — the status surfaces, measured, and one of them is empty

`README.org`'s Milestone 6 paragraph, `CHANGELOG.md`'s `[Unreleased]`, the parent
plan's `Status:` line (one physical line; it stays one), the design's `Status:`
header — four. The fifth, the source comments naming Milestone 6 as a
**receiver**: exactly one — `verify.sls`'s `pass-reachability` note, "failing
that by Milestone 6's close-out" (`rg -n "Milestone 6's close-out" src/` prints
one line at `8ec814f`); the other thirty-two `Milestone 6` mentions under `src/`
(`rg -c`) are provenance ("Milestone 6 Slice ①", "Milestone 6 design §4.9"), not
receivers. The sixth, the closed slice plans' own status lines: Milestone 6's two
slice plans carry **none** (`rg -n '^\*\*Status|^Status:'
docs/plans/milestone-6-slice-*` prints nothing), so there is nothing to move
there; Milestone 5's ⓪ and ⓪b plans carry `**Status:** CLOSED 2026-09-04` lines
that are already true. The close note says which surfaces were swept and which
were empty.

### F8 — the reachability deferral needs both ends, and one of them is a heading that exists

Design §8 and §4.11 item 5 defer narrowing `pass-reachability` to Milestone 7
(`§25:1615`, "generative and diagnostic hardening of all mandatory verification
passes"). Both ends: the source note above `pass-reachability` in `verify.sls`
(thirteen comment lines at `8ec814f`; commit B rewrites its last sentence, so
it is cited by construct) re-addressed from
"Milestone 6's close-out" to Milestone 7, naming design §8's pricing (the
narrowed set is `byte-reached` ∪ the EOF walk's visited set, decision 0027's
family flips `unreachable-node`, one shipped fixture and the matrix's pruning
count move); and an appended disposition under a `### §25:1611` heading — parent-plan line
1611 is `### Milestone 7: Verification and generative hardening`, and the two
Milestone 5 dispositions already under that heading are where Milestone 7's
designer reads first (they record what Slice ⓪ built and that Milestone 7 keeps
its generator scope unchanged; neither hands anything over, so this is the first
disposition under `§25:1611` that does). "Milestone 7's scope is unchanged" is
true under one stated reading: `§25:1615`'s "generative and diagnostic hardening
of all mandatory verification passes already introduced" already covers
narrowing a pass, and the disposition says so rather than asserting it.

### F9 — the Exit table has two rows left to dispose

Slice ① disposed `:1607`, `:1609`'s criterion and `:1608`'s field, cursor and
offset clauses in place. This slice disposes `:1608`'s **fragment** clause (over
the counted-span lane's schedules, per feed and coalesced) and `:1609`'s **span
variant** (two completion events in one feed's trace for `3:abc,0:,`), dated,
naming the case.

### F10 — the third close-out question has an answer

§9 asks what this milestone approved that the tree does not contain. §4.12's two
items — the label clause made total, the shared name grammar — both shipped in
Slice ⓪ and are dispositioned in the parent plan; nothing else was approved. The
five §4.11 obligations: items 1 and 2 discharged by finding (§4.9, the field-action
note corrected by ①); items 3 and 4 closed by ⓪; item 5 deferred by this slice
with both ends (F8). The close note answers all three questions by name.

### F11 — the new lane's pins are the placement, and the same mutants are already pinned elsewhere on other records

The only decision the counted-span lane witnesses that no other lane does is
decision 0030 item 2's **placement**: the completion event in the feed that
delivered the last body byte. The mutants that move it are the two
count-completion-order mutants — `interpret.sls`'s `(if (= k v) …)` and the
emitted arm's `(if (= n v)` — both already declared in Slice ①'s passes on other
records (the exact case's answer; the exact body's parked node). Here they are
declared again under the new SPEC, pinned on the **placement record** per lane
("interpreter: the c feed delivers the last fragment and the completion" /
"generated: …"), which is the value §7's oracle 3 exists for; a symmetric wrong
reading puts the completion in the `,` feed in both lanes and agrees with itself.
Two pins; the retention arm adds none (F6). `EXPECTED_PASSES` 57 → **58**,
`EXPECTED_MUTATIONS` 520 → **522**, both in the lane commit.

### F12 — two commits, each green

Commit A: the harness library's span variants, `differential-counted-span-tests.sps`,
the retention arm, two CTest lanes, the new pass with its two pins and the
totals. Commit B: the close-out — the parent plan's two appended dispositions
and its Status line, `verify.sls`'s re-addressed comment (the one `src/` hunk),
the design's §7, §4.11, §8, Exit table, Amendments and Status, README and
CHANGELOG. A whole-branch review follows, then the PR; `main` is merged on the
owner's go-ahead, and the closing ritual closes the milestone.

---

## Global constraints

- **Authority order.** Design §7 and §4.8, decision 0030 item 2, then the parent
  plan's `§14` rules. Where an authority is wrong, stop and say so in this plan's
  findings and correct the instruction in place.
- **No mechanism.** `git diff 8ec814f..HEAD -- src/byte-machine/runtime.sls
  src/byte-machine/compile.sls src/byte-machine/interpret.sls
  src/byte-machine/private/normal-ir.sls src/byte-machine/private/ir.sls` prints
  **nothing** at the slice's head. If a case cannot pass without a code change,
  design §4.8 was wrong and the design is amended before the code lands.
- **One recorder per lane**, each with its own accumulator (Milestone 5's
  correction, carried forward again); every placement asserted as a **value per
  feed** in each lane before the lanes are compared.
- **Every FIND at one site in both directions**, and the sweep once after commit
  A with a control on `8ec814f`.
- **A mutant can hang the suite.** Scripts are literal lists of at most a few
  steps; no fixture re-enters the runtime under a data-dependent bound.
- **Dates are literal.** Today is 2026-09-06.

---

## Task 1 — The counted-span differential (commit A)

**Files:** `test/support/harness/byte-machine/test/counted-machine.sls`,
`test/common/differential-counted-span-tests.sps` (new), `test/CMakeLists.txt`.

- [ ] **Step 1: The machine, two variants.** `(make-counted-span-machine
      complete?)` in `counted-machine.sls`: Slice ①'s message loop with `body`
      wrapped — `:` → `open` (span start, `sp`) → `body` (counted consume on
      `len`, eof-target its **own** truncation node `trunc2`, because the shared
      one is reached with no span open and one node cannot carry both states) →
      `close` (span end) → `,` → clear → `idle`; callbacks `on-data`
      (`span-data`, required) and, when `complete?`, `on-done`
      (`span-complete`); span `sp` with or without the completion callback.
      Both verify clean (the first case of the program asserts it, with the
      diagnostic list). The export list gains the constructor; both new CTest
      lanes list the file in `SOURCES`.
- [ ] **Step 2: The program's harness**, copied from the span lane's shape: a
      `generated` loader per variant under distinct library and binding names
      (`load` twice into one library name leaves whichever ran last resident
      under both — the span lane's own note); `recorder` with `(data n)` events
      and `complete`, an `events` thunk that returns and clears; `make-lane`,
      `run` over scripts of `(feed "str")`, `(slice bv start end)`, `(finish)`,
      `(resume)`; `both` returning each lane's result and their equality;
      `record-span` over a schedule ending in `parser-finish!`; `coalesce`. Feeds
      are driven by `for-each` or a named `let`, never `map` (R6RS leaves
      `map`'s order unspecified; Slice ① lost an afternoon to it).
- [ ] **Step 3: The six rules over a counted body**, one group each, both lanes,
      expected trace as a value per lane then agreement:
      1. rule 2 (`§14:831`): `3:abc,` in one feed — one fragment `abc` from the
         span end after the bulk commit, then the completion, then the loop is
         back at `idle` with `len` 0 and the span inactive;
      2. rule 4 (`§14:833`): `3:ab` then `c,` — the flush delivers `ab` at the
         boundary, the span stays open (`parser-active-span` = `sp` between the
         feeds, `len` = 1), the second feed delivers `c` and the completion;
      3. rule 5 (`§14:834`): `0:,` — no data callback at all and one completion.
         In one feed the trace is `(complete)`; byte-at-a-time the per-feed
         traces are `(() (complete) ())`: the `:` feed opens the span, takes the
         zero-count route at once (decision 0030 item 1), suppresses the empty
         fragment and fires the completion, and the `,` feed records nothing;
      4. rule 8 (`§14:837`, `§25:1600`): `3:ab` with the data callback answering
         `callback-pause` — the feed reports `paused` with the need-input tuple's
         cursor and offset, the fragment `ab` was committed, the span is open,
         **`len` reads 1** (F5); `parser-resume!`; `c,` delivers `c`, the
         completion, and the loop returns to `idle` — the fragment is never
         re-delivered;
      5. rule 9 (`§14:838`): `3:abc` with the data callback answering pause on the
         span-end fragment — `paused`, then resume, then `,` delivers the
         completion only (the pause between the substeps);
      6. rule 10 (`§14:839`): `3:ab` then `parser-finish!` — the truncation error
         (`trunc2`'s code, `eof` at offset 4), **no** final fragment beyond the
         earlier flush, **no** completion; the flush from the first feed is still
         in the trace.
- [ ] **Step 4: The placement oracle, per schedule** (design §7 oracle 3; decision
      0030 item 2). For every schedule the generator produces over `3:abc,`, the
      expected feed index of the completion is **derived before the run**, in
      STREAM offsets: summing the lengths of the preceding slices, the first
      slice whose cumulative range covers stream offset 4 (the last body byte,
      `c`) is the feed the completion must land in — never the slice's own
      `start`/`end` arguments, which for a padded sub-slice schedule such as
      `(padded 2 5) (padded 5 8)` name bytevector positions and would pick the
      wrong feed. The program records the trace per feed in each lane and
      asserts: the completion appears exactly once, in that feed; no feed after
      it records anything but the delimiter's silence; `len` reads 0 from that
      feed on and the remaining count before it; and the two lanes' per-feed
      traces and per-feed counts are equal. For the bare variant (F2): after the
      feed containing offset 4, `parser-active-span` is `#f` in both lanes, and
      it was the span's name after every earlier feed that delivered a body
      byte.
- [ ] **Step 5: Schedules, coalescing, the error path** (`§22.5:1278-1289`):
      every split point (7), ordered pairs (28), the span lane's ten "others"
      adapted to six bytes (leading, trailing and intermediate empty feeds; two
      and three sub-slices of a padded bytevector; byte-at-a-time; a mixed one)
      — "forty-five schedules driven" as the sentinel, compared with the
      generator's length; same-schedule exactness (`§22.5:1285`): identical
      traces across lanes for every schedule; cross-schedule invariance
      (`§22.5:1287`): coalesced traces identical to the one-feed baseline, and
      the raw set has more than one member; the error path (`§22.5:1289`): every
      truncating schedule of `3:ab` agrees on `(error 4 eof)` and synthesizes no
      completion, compared exactly between lanes on one schedule only.
- [ ] **Step 6: `§25:1609`'s span variant.** `3:abc,0:,` in one feed — **two**
      completion events in one feed's trace, the first after `abc` and the
      second with no data callback before it (`§14:834`), the loop at `idle`.
- [ ] **Step 7: CMake** — `byte-machine.differential.counted-span.chez.{source,aot}`
      on the counted differential's registration shape (`test/CMakeLists.txt`,
      the "Milestone 6 Slice ①: the counted consume in both lanes" block),
      `SOURCES` listing `counted-machine.sls`.
- [ ] **Step 8: Verify** — `ctest --preset release -R 'differential\.counted-span'`:
      `100% tests passed, 0 tests failed out of 2`; the no-mechanism diff prints
      nothing.

## Task 2 — The retention lane's body-shaped arm (commit A)

**Files:** `test/common/retention-tests.sps`.

- [ ] **Step 1:** `retention-counted-machine`, inline: `start` (`A` → `sopen`,
      advance; fallback `reject`; eof-target `fin`) → `sopen` (span `payload`) →
      `body` (counted consume on `len`, u8 initial 3, eof-target `trunc`) →
      `sclose` → `after` (`Z` → `done`) with the shipped declarations; its
      `cm-ref`/`cm-gen` pair built as the shipped one is (a distinct generated
      file and binding), and a `both-counted-lanes` list.
- [ ] **Step 2:** layer 1 on the counted machine — the one-feed probe reads
      **gone** in both lanes, and the split probe (`A b` then `c d Z`, two
      bytevectors, the flush delivering `b` out of the first) reads **gone** for
      both buffers; layer 2's negative control on the counted machine reads
      **RETAINED** in both lanes (`stashing` for the one-feed probe,
      `stashing-first` for the split one), and its trace shows the data callback
      fired (`stashed complete`). Layer 3 is not repeated (F6). The sentinel is
      the lane list's observed length.
- [ ] **Step 3: Verify** — `ctest --preset release -R 'unit\.retention'` prints
      `100% tests passed, 0 tests failed out of 2`; the arm's checks are
      labelled "counted" so a red one names its machine.

## Task 3 — The pass, the two pins, the totals, the sweep (commit A)

- [ ] **Step 1:** a new pass in `SchemeMutationSuite.cmake` after the last one,
      SPEC `byte-machine.differential.counted-span.chez.source`, two pins on the
      placement record: "interpret: count-step continues only when input remains
      -- seen as the completion landing in the delimiter's feed" (FIND the
      `(cons k (if (= k v) …` line; REPLACE `(and (= k v) (< (+ pos k) end))`;
      EXPECT the interpreter's per-feed record for the byte-at-a-time schedule)
      and "compile: the emitted counted arm continues only when input remains --
      seen as the completion landing in the delimiter's feed" (FIND the rendered
      `"                  (if (= n v)\n"` line; REPLACE the `and`; EXPECT the
      generated lane's record). Each regex spells the expected list in full —
      no `.*` between `expected` and `got` (Slice ①'s sweep) — and each FIND is
      already at one site (it is Slice ①'s pin text; a second declaration under
      another SPEC does not change occurrence counts).
- [ ] **Step 2:** `set(EXPECTED_PASSES 58)`, `set(EXPECTED_MUTATIONS 522)`, and a
      count-narrative entry.
- [ ] **Step 3:** the full `release` (expect `100% tests passed, 0 tests failed
      out of 114`) and the mutation lane's line `58 passes, 522 mutations`.
- [ ] **Step 4: Commit A** — `test(counted-span): the fragment trace over every
      schedule, the placement per feed, and a body-shaped retention arm`.
- [ ] **Step 5: The sweep**, both directions, over the touched passes (the new
      one and retention), control on `8ec814f`, the Slice ① script; expected
      **0 self-failures** and **0 collisions** in the new pass (two mutants, two
      ordered pairs; Slice ①'s declarations of the same mutants live in other
      passes and are never judged against this pass's outputs), and the shipped
      retention pin "runtime: the fed bytevector is stored in the parser and
      survives the return" confirmed to redden the counted arm's layer-1 checks
      (the detail and user-context pins exercise layer-3 cases the counted arm
      does not have, and are expected NOT to).

## Task 4 — The close-out (commit B)

**Files:** `docs/plans/byte-machine-implementation-plan.md`, `src/byte-machine/verify.sls`
(one comment), `docs/plans/milestone-6-design.md`, `README.org`, `CHANGELOG.md`.

- [ ] **Step 1: The close note, appended.** Under `## Dated dispositions`, `###
      §25:1593-1609 — Milestone 6 closes, dispositioned against the tree`, on
      Milestone 5's shape: the delivery (Gate 0 as decision 0030; Slice ⓪; Slice
      ①; Slice ②, with PRs and dates); **each scope bullet and exit criterion
      against the tree**, naming the file and case (`:1597`, `:1598`, `:1601`,
      `:1602`, `:1603`, `:1607`, `:1608`'s field/cursor/offset clauses and
      `:1609`'s criterion by Slice ①'s cases; `:1599`, `:1600`, `:1608`'s
      fragment clause and `:1609`'s span variant by this slice's); the **three
      questions** of design §9 by name — the criteria met, the five obligations
      of §4.11 each disposed (1 and 2 by finding, 3 and 4 by Slice ⓪, 5 deferred
      to Milestone 7 with both ends), and what was approved that the tree lacks
      (nothing: §4.12's two items shipped in ⓪); what the milestone leaves open
      (`§16.2:911`, still an orphan; the reachability narrowing, handed on). No
      exit criterion is reworded to match what shipped.
- [ ] **Step 2: The deferral's two ends (F8).** `verify.sls`'s `pass-reachability`
      note: "Owed by whoever next narrows reachability, and failing that by
      Milestone 6's close-out" becomes "… and failing that by **Milestone 7**
      (`§25:1615`); handed on 2026-09-06 and adjudicated at the parent plan's
      `§25:1611` disposition, which carries Milestone 6's design §8 pricing" — a
      comment hunk, the only one under `src/`, naming the adjudication so the
      two cannot drift apart. The parent plan
      gains `### §25:1611 — Milestone 6 hands the reachability narrowing to
      Milestone 7`, appended, stating the pricing (the narrowed relation, the
      verdict change on decision 0027's family, the shipped fixture that flips,
      the matrix's pruning count) and that Milestone 7's scope is unchanged.
- [ ] **Step 3: The design.** §7 gets its landing, and its oracle 4 is corrected
      in place (F3): not "every hunk in those two files is a comment" but "the
      five-library diff is empty; the receiver notes it expected the close-out to
      rewrite were rewritten by ⓪ and ①"; the Exit table's `:1608`
      fragment clause and `:1609` span variant get dated dispositions (F9);
      §4.11 item 5 records the hand-off; §8's reachability bullet says "deferred
      2026-09-06"; the Amendments block indexes the corrections; the Status
      header reads **closed**, with the milestone's measured totals.
- [ ] **Step 4: The four surfaces.** `README.org`: Milestone 6 closed, what it
      built, Milestone 7 next; `CHANGELOG.md`'s `[Unreleased]`: the same in its
      voice; the parent plan's `Status:` line gains the close (one physical line,
      checked); the fifth surface is empty (F7) and the close note says so. Then:

      ```bash
      rg -n "Milestone 6's close-out" src/
      ```
      Expected: **no output** (it prints one line at `8ec814f`).

      ```bash
      git diff -U0 8ec814f..HEAD -- docs/plans/byte-machine-implementation-plan.md | rg '^@@'
      ```
      Expected: exactly **two** hunks — line 3, and one at the foot: two
      dispositions appended together are one contiguous addition. A third hunk
      would mean an insertion, which the file forbids.
- [ ] **Step 5: Commit B** — `docs: Milestone 6 closes — the disposition, the
      reachability hand-off, and four status surfaces`.

Then the whole-branch review, its fixes, the PR, and — on the owner's go-ahead —
the merge and the closing ritual, whose last step reflects the milestone's
lessons into memory.

---

## Verification

`release` green in both lanes at each commit (114 lanes), the mutation suite at
58 passes / 522 mutations, and seven things checkable rather than asserted:

1. **No mechanism**: the five-library diff against `8ec814f` prints nothing.
2. **Same-schedule exactness** (`§22.5:1285`): identical traces in both lanes for
   all forty-five schedules, and the count reached zero in the same feed in both.
3. **Cross-schedule invariance** (`§22.5:1287`): coalesced traces identical; the
   raw set has more than one member.
4. **The placement value** (`§10.6:603`): per feed, per schedule, against the
   index derived from the schedule before the run — the one assertion lane
   agreement cannot stand in for — and the two placement pins are caught on that
   record, not on disagreement.
5. **The retention arm** reads gone on the counted machine in both lanes under
   both probes, and its negative control reads retained.
6. **Both ends of the deferral exist**: the `verify.sls` note names Milestone 7,
   and the `§25:1611` disposition exists; `rg "Milestone 6's close-out" src/`
   prints nothing.
7. **The close note answers three questions**, and every exit criterion it marks
   DISCHARGED names a case that exists: `rg -n -F '<label>' test/common/` prints
   exactly one line per label named.

## Exit

Milestone 6 is closed: seven scope bullets and three exit criteria dispositioned
against the tree, five obligations disposed with both ends, nothing approved left
unshipped, one deferral handed to Milestone 7 where its designer will read it, and
a fragment oracle that asserts the one value lane agreement cannot see.
