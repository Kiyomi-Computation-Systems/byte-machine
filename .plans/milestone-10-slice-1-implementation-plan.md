# Milestone 10 Slice ① — The empty-span mechanism

Design: [milestone-10-design.md](./milestone-10-design.md) §5. Gate 0: decision
[0042](../.decisions/0042-empty-span-delivers-one-fragment-on-the-feed-side.md).
Base: `main` at write time (`e9f8d9c` when this was drafted; re-resolve every
`file:line` below against the base the executor actually branches from).

**One atomic commit.** Flipping the by-value suppression assertions and the
runtime that satisfies them cannot be split without a red intermediate commit
(AGENTS.md). Intermediate *working-tree* states are red during TDD; only the
commit is green.

**The §4.7 gate this slice asserts.** `git diff --stat <base>..HEAD -- src/`
names `runtime.sls` and nothing else. The six determinism goldens and
`reserved-member-3` do **not** move; a moved golden is a bug, not a re-baseline.

---

## The runtime shape (the exact target)

Three procedures replace the one at `runtime.sls:585-593`. Factor the delivery,
give the two span-END sites deliver-if-never, keep the flush and EOF sites on an
unconditional-suppress entry point. Names below are proposals; the slice owns
the final spelling but must keep `byte-machine-span-fragment-step/v1`'s name and
seven-argument signature exact (emitted code calls it).

```scheme
;; Sets the "delivered" flag, commits, invokes, classifies. Shared by both
;; entry points. The flag is set BEFORE f runs: a delivery is committed the
;; moment it is initiated, so a pause cannot un-count it and resume cannot
;; re-fire it (resume parks on the substep past the delivery).
(define (span-fragment-deliver! parser state offset f bv from to continue)
  (parser-set-span-delivered?! parser #t)
  (callback-commit! parser state offset)
  (classify-callback-result
   (f parser (parser-user-context parser) bv from to)
   '() continue))

;; EVERY span end: the feed-loop span-end (runtime.sls:861), the emitted arm
;; (compile.sls:423), AND the EOF-side span end (runtime.sls:1172, routed here so
;; both lanes match -- parser-finish-v2! reaches the emitted arm for EOF). Deliver
;; real bytes; deliver an empty [from,to) exactly once (from == to, flag clear) so
;; an empty span is observable; suppress otherwise -- from == to with the flag SET
;; (a split span's empty FINAL fragment) or from > to (the incoherent EOF carried
;; case, decision 0042 item 4). The `= from to` guard is what keeps the shared
;; step safe at the EOF site.
(define (byte-machine-span-fragment-step/v1 parser state offset f bv to continue)
  (let ((from (parser-span-mark parser)))
    (cond ((unbound-callback? f) (list 'goto continue))
          ((< from to)
           (span-fragment-deliver! parser state offset f bv from to continue))
          ((and (= from to) (not (parser-span-delivered? parser)))
           (span-fragment-deliver! parser state offset f bv from to continue))
          (else (list 'goto continue)))))

;; The FLUSH (runtime.sls:617) -- and only it. Never delivers an empty fragment: a
;; mid-span read boundary that accumulated nothing has nothing to say, and the
;; span stays open. Delivers real bytes exactly as before. Not emitted.
(define (span-fragment-suppress-empty parser state offset f bv to continue)
  (let ((from (parser-span-mark parser)))
    (if (or (>= from to) (unbound-callback? f))
        (list 'goto continue)
        (span-fragment-deliver! parser state offset f bv from to continue))))
```

Slot 16 and its accessor, beside slots 14/15 (`runtime.sls:423-427`):

```scheme
(define (parser-span-delivered? p) (vector-ref p 16))
(define (parser-set-span-delivered?! p v) (vector-set! p 16 v))
```

Append `#f` to both `make-parser` vector literals (`runtime.sls:364-367`,
`:372-377`), and reset the flag in `byte-machine-span-close/v1` **only** —
`make-parser` inits it `#f` and close resets it `#f`, so it is `#f` at every span
start without `span-open` touching it; keeping the reset in one place makes it a
single load-bearing line (transitively covers `parser-reset!` at `:1314` and both
completion arms, exactly as slots 12/14/15 are):

```scheme
(define (byte-machine-span-open/v1 parser name mark data-slot)
  (parser-set-active-span! parser name)
  (parser-set-span-mark! parser mark)
  (parser-set-span-data-slot! parser data-slot))   ; no flag touch: init/close leave it #f

(define (byte-machine-span-close/v1 parser)
  (parser-set-active-span! parser #f)
  (parser-set-span-mark! parser 0)
  (parser-set-span-data-slot! parser #f)
  (parser-set-span-delivered?! parser #f))          ; the flag's ONLY reset
```

Repoint only the flush (`span-boundary-flush!`, `runtime.sls:617`) to
`span-fragment-suppress-empty`. Leave the feed-loop span-end (`:861`), the EOF
span-end (`:1172`), and the emitted arm (`compile.sls:423`, **unedited**) on the
public step — routing the EOF span-end to the public step is what keeps it in step
with the generated lane while leaving the emitted text unchanged. The re-anchor at
`runtime.sls:708-709` is unchanged and must **not** clear the flag; `parser-finish!`
deliberately does **not** re-anchor (leaving a carried span at `from > to`).

Rewrite the comments the change makes false: the fragment-step's suppression
paragraph (`runtime.sls:564-583`) and the EOF path's "`from >= to` holds for
every mark and the empty-fragment suppression fires" trap notes
(`runtime.sls:1073-1081`, `:1155-1164`) to describe the split and the symmetric
EOF delivery. The new invariant: a span end delivers its final
fragment, empty-once-if-never-delivered; the flush and EOF path suppress empty
fragments unconditionally, the EOF path because its cursor-0/uncoordinated-mark
range is not a coherent empty delivery (decision 0042 item 4).

## Tasks

### Task 1 — Tests first (the delivering cases go red)

Re-baseline the by-value suppression assertions to the delivering shape, and add
the new fixtures. Drive every feed/resume with `for-each`/named `let`, never
`map`.

- `differential-span-tests.sps:250-254` (the AZ empty span, feed loop): `'(complete)`
  → `(list (bytes) 'complete)`. Rename the group away from "suppressed". Keep the
  `(caddr r)` cross-lane check and the by-value generated-lane check.
- `differential-counted-span-tests.sps:142-156` (the `0:,` empty counted body):
  the one-feed case `'(complete)` → the delivering shape (`(data 0)` before
  `complete`); update the byte-at-a-time case so the `:`-feed records the
  delivery. Read the file's `obs`/`recorder` shape and match it exactly.
- `http-message-tests.sps:98-105` (all-OWS empty header value): `count-of
  'header-value-data` `0` → `1`; `header-value-complete` still fires once. This is
  the consumer's shape — comment it as such.
- `differential-span-tests.sps:486-499` (the EOF-chain `eopen`/`eclose` span,
  mark 0): `'(complete)` → `(list (bytes) 'complete)`. The EOF span end is routed
  to the public step, and `[0,0)` is coherent, so it delivers like the feed side.
  The `eof-close-machine` carried-span cases nearby (`from > to`) STAY green.
- `differential-counted-span-tests.sps` `§25:1609` two-message case: the second
  message's empty body now delivers `(data 0)` before its completion.
- **New** `differential-span-tests.sps`, criterion 2 (split span, empty final
  fragment suppressed): feed the delimiter alone last, e.g.
  `(feed (bytes 65 98 99))` then `(feed (bytes 90))`; assert the trace is
  `(list (bytes 98 99) 'complete)` — `bc` flushed, the empty final fragment
  suppressed, only the completion. **This must stay green through the change** (it
  is the guard against the naive fix), so it passes both before and after; add it
  here so it is in the commit.
- **New** `differential-span-tests.sps`, criterion 3 (flush finds nothing): feed
  the opener alone, `(feed (bytes 65))` then `(feed (bytes 98 99 90))`; assert the
  mid-trace after feed 1 is `'()` (drive feed 1 alone, as the file already does)
  and the final trace is `(list (bytes 98 99) 'complete)`. Also stays green
  through the change (guards that an empty flush does not set the flag or
  deliver).
- **New** `differential-span-tests.sps`, criterion 5 (pause on the empty
  delivery): the empty-span data callback returns `callback-pause`; after
  `resume`, the completion fires exactly once and the empty fragment is not
  re-delivered. Assert the full `paused → …` status sequence and a once-only
  trace, mirroring the existing pause groups.
- **Property driver** (`property-driver.sls:411-418`): an empty span now always
  delivers a zero-length fragment, so `span-suppressed-empty` (a completion with no
  fragment) loses its witness; reframe it to `span-empty-fragment` / member
  `empty-fragment` (derived from a delivered fragment of length 0, which the
  coverage machine's `covy` produces). Move it, its counter-spec entry (`:341-343`),
  `family-members 'span-event`, and the declared-literal totality row +count
  (`property-differential-tests.sps:369`, `:367-368`) **together**. Reconcile
  Layer-3 row 6's `frags?` applicability comment (`property-driver.sls:1016-1019`):
  an empty span now records a fragment, so the row becomes applicable to it —
  verify the 0-length fragment's abs-from==abs-to==open-offset and completion
  offset satisfy content/contiguity/end-anchor, do not assume it.

Run `make test` (source mode): the re-baselined delivering cases FAIL against the
current runtime; the new guard cases (criterion 2, 3) PASS. Record the failures.

### Task 2 — The runtime

Apply the runtime shape above. Run `make test` in **both** Chez modes
(`chez.source` and `chez.aot`): all green. Then assert the gate:
`git diff --stat -- src/` names only `runtime.sls`; the HTTP determinism golden
is byte-identical (`git diff -- test/fixtures/generated-http.golden.sls` empty)
and `member3-drift` / `reserved-drift` green. Provenance reconfigure before the
property lanes (`touch test/CMakeLists.txt && cmake --preset dev && cmake --build
--preset dev`).

### Task 3 — Mutations

- **Re-author** the suppression pin (`SchemeMutationSuite.cmake`, "an empty span
  fragment is delivered instead of suppressed"). Its `FIND` `(if (or (>= from to)
  (unbound-callback? f))` now lives in `span-fragment-suppress-empty` — the FLUSH
  helper only (the EOF span-end moved to the public step). Inverting `>=`→`>`
  makes the FLUSH deliver an empty fragment, so its witness moves from the AZ case
  to the **criterion-3 flush case** (the flush that finds nothing accumulated,
  where the mutant would now deliver an empty fragment). Re-measure the mutant's
  output with the staged mutant in a scratch tree; set `EXPECT_OUTPUT_MATCHES` to
  the measured `got`, pinned on a case-name tail + check label (never a substring
  of the FAIL-context or summary line, never a `.*` bridge, `.` for each literal
  paren).
- **New** mutations, each witnessed in `differential-span-tests.sps` (the only
  program that observes a span fragment), each caught by a failed comparison, not
  a raise:
  1. the public step's `from == to` empty-delivery guard (e.g. `(= from to)` →
     `(< from to)`, so an empty span never delivers): witnessed by the AZ case
     (`(list (bytes) 'complete)` vs `'(complete)`).
  2. `parser-set-span-delivered?!` set in `span-fragment-deliver!` deleted:
     witnessed by the criterion-2 split fixture (its empty final fragment would
     deliver spuriously because the flag stays clear).
  3. `parser-set-span-delivered?!` reset in `byte-machine-span-close/v1` deleted:
     witnessed by the **property** lane's coverage machine, which runs a nonempty
     span (covx) then an empty span (covy) on one parser — without the reset,
     covy's flag is stale `#t`, covy is suppressed, and the `empty-fragment`
     counter reads 0. SPEC `byte-machine.property.differential.chez.source`.
- Recount `EXPECTED_MUTATIONS`/`EXPECTED_PASSES` from the rewritten manifest
  (currently 602/65) — never predicted. Run the whole scheme mutation lane
  (`make test-mutation`, streamed): filter for `CMake Error`, `wrong reason`,
  `UNCAUGHT`, the `tests passed` line, and the exit status — never the "suite
  complete" line. Confirm each new/changed pin is caught for the reason it names
  and fails the number of cases its decision reaches (a uniform failure is a
  crash, not a discrimination).

### Task 4 — Spec and comment sweep

- Append the `§14` dated disposition at the parent plan's `§1802` foot: items 2
  and 5 are amended — a span end (feed-side or EOF-side; `parser-finish!`
  re-anchors the mark to 0 so every empty span reaches `from == to`) emits
  `[mark,cursor)` even when empty, once, when the span delivered nothing; item 4
  (the flush) is UNCHANGED (an empty flush still suppresses); item 5's blanket rule
  is narrowed accordingly; `§14:835` (item 6, "zero or more") stays literally true
  but the zero-with-completion case is no longer reachable (every completed span
  delivers ≥1 fragment). Do **not** edit `§14` inline. Cite decision 0042.
- Sweep the files this slice edits for comments/group-names asserting "an empty
  fragment is suppressed (§14:834)" that now describe a delivered case, and
  correct their *semantics* (the `§14:834` line citation stays valid — the append
  rule does not renumber §14): `differential-span-tests.sps`,
  `differential-counted-span-tests.sps`, `machine-gen.sls`'s
  "`[mark,mark)` … suppresses the empty" comment, and any others in touched files.

### Task 5 — Verify and commit

`make test` green in both Chez modes; the scheme mutation lane green with
recounted totals; the six determinism goldens and `reserved-member-3` unmoved;
`git diff --stat -- src/` names only `runtime.sls`; brief acceptance criteria
1–8 re-checked against the shipped lanes. One commit,
`feat(runtime): deliver an empty span's data callback once (§14, decision 0042)`,
with the trailer. Then re-resolve every `file:line` in this plan and decision
0042's Slice ① consequences against HEAD before opening the PR.

## Not in this slice

- The version bump, `CHANGELOG.md`, the release ledger, the tag, and the
  milestone-status surfaces — Slice ② (design §6).
- Announcing a span that OPENS in a feed and CLOSES empty at EOF (`from > to`),
  any verifier change, any callback-signature change (decision 0042 item 4, and
  design §"Explicitly out"). (Under decision 0042 EVERY empty span DOES deliver in
  this slice — feed-side, EOF-chain-opened, or carried into finish — uniformly.)

## Findings recorded this slice

- **The EOF decision took two turns, both to the owner.** First, keeping EOF
  suppressing would need a `finish?` branch in the emitted arm (`parser-finish-v2!`
  runs the emitted `exec` for EOF), moving the HTTP determinism golden — so EOF
  delivers symmetrically. Then the whole-branch review measured that "deliver only
  the coherent `from == to` cases" was **slicing-dependent**: a span carried from a
  feed and closed empty at EOF fired only when its last feed started at 0 (the
  per-feed re-anchor had set the mark to 0). Fix: `parser-finish!` re-anchors an
  active span's mark to 0 before the EOF chain, so every empty span reaches
  `from == to` and is announced once, uniformly; `from > to` is then unreachable.
  Owner approved. Decision 0042 item 4 records both turns.
- **Mutation totals 602 → 606** (recounted from the run, `65 passes, 606
  mutations`, all caught). The pre-existing suppression pin was **re-authored in
  place** (net 0): its `>= from to` FIND now sits in the flush helper, witness
  moved to the flush's own empty case (criterion 3). New in the span lane: the
  `from == to` empty-delivery guard (witness AZ, pinned on the case name so it does
  not resolve to the EOF-chain record too), the deliver! flag-set (witness the
  criterion-2 split), and the `parser-finish!` mark re-anchor (witness the
  nonzero-start carried-empty-at-EOF case). New in the property lane: the
  span-close flag reset (witness covx→covy). All caught for the reason each names.
- **The whole-branch review (read-only, 4 dimensions → verify) found the runtime
  internally sound but caught the slicing-dependence above (HIGH) and ~10 doc/
  comment residuals from the two reversals** — a `clear-at-open` instruction in the
  design that would have defeated a pin, a mutation-suite narrative asserting the
  finish re-anchor "was inert", stale "suppressed / from >= to for every mark"
  comments, an off-by-one `§14:836`→`§14:835`, and the `suppressed-empty` literal
  in the design. All corrected in this pass; the AZ pin's two-record smell fixed by
  anchoring on the case name.
- **A pre-existing pin went stale on my `make-parser` edit.** "the interpreted
  parser drops the user context" FINDs the `'op` arm's vector literal
  (`user-context #f #f 0 #f)))`); appending slot 16's `#f` made it occur 0 times
  (a SITES=1 refusal, caught by the full mutation run — not by any lane's green).
  Re-anchored FIND **and** REPLACE in lockstep to `… #f #f)))`; the mutant's
  measured `got` is unchanged, so its `EXPECT_OUTPUT_MATCHES` stood.
- **The property `span-event` family member `suppressed-empty` → `empty-fragment`.**
  Post-0042 a completion with zero fragments (the old derivation) only happens for
  the exotic carried-EOF case; the observable that the coverage machine's `covy`
  now produces is a zero-LENGTH delivered fragment, so the member and its
  derivation were reframed (property-driver + the totality literal, kept at 5).
- **The flag is reset in span-close only.** `make-parser` inits slot 16 `#f` and
  span-close resets it, so `span-open` needs no clear; a clear at both would make
  neither individually catchable (redundant by construction). One reset line,
  witnessed by the two-span coverage machine.
- **Re-baselined by-value literals** (deliberate, decision 0042): AZ and the
  EOF-chain span in `differential-span-tests.sps`; the `0:,` and `§25:1609` cases
  in `differential-counted-span-tests.sps`; the all-OWS empty header value (0→1)
  in `http-message-tests.sps`. New guard fixtures: criterion 2 (split, empty final
  suppressed), criterion 3 (flush finds nothing / genuinely empty split), and a
  pause on the empty delivery (criterion 5).
