# Milestone 8 Design — The private HTTP fixture

**Status: Milestone 8 CLOSED (2026-09-12).** Gate 0 discharged, all six slices (⓪–⑤) executed and
merged; the four `§25:1646-1649` exit criteria are dispositioned in
`milestone-8-slice-5-implementation-plan.md`. Written against **`741e0ca`** (`feat/m7-slice-4`,
Milestone 7's close plus its mutation-runner follow-up) on branch `docs/milestone-8-design`, tree
clean. Milestone 7 was closing in a parallel session as this was written, so **the base is
re-taken when `main` carries the squash of Milestone 7** and every count below is re-measured then
(§11); if that merge is a squash, this branch rebases with
`git rebase --onto main 741e0ca`, never a plain `git rebase main`.

> **Gate 0 discharge (2026-09-12), against `main` at `bf6e56d`.** Milestone 7 squash-merged
> (`3391eca`, PR #99); this branch rebased `--onto main 741e0ca` as the paragraph above requires.
> **`src/` and `test/` are byte-identical between `741e0ca` and `main`** (`git diff --stat 741e0ca..main
> -- src/ test/` prints nothing; #98/#100 were docs-only), so every count below carries over
> unchanged and the five prototypes reproduce by construction — the load-bearing negative (P3, the
> §12.7:770 machine-action defect) is confirmed **in the tree** by `compile.sls`'s OWED note.
> Re-confirmed at `bf6e56d`: `EXPECTED_PASSES 61` / `EXPECTED_MUTATIONS 590`, 102 scheme lanes, the
> **18** `§21.4` codes, the 9 fixture machines. **The four records are written**:
> [0034](../.decisions/0034-http-error-table-is-first-and-fixture-owned.md) (§4.1),
> [0035](../.decisions/0035-case-insensitive-recognition-is-a-byte-set-chain.md) (§4.2),
> [0036](../.decisions/0036-error-node-is-per-span-state.md) (§4.3),
> [0037](../.decisions/0037-idle-node-message-begin-and-clean-eof.md) (§4.4). **§4.9 owner
> dispositions**: items 1 (shared event-order oracle, receiver Slice ①) and 2 (fixture-region →
> node-name map, receiver Slice ⓪, grows per slice) **approved**; item 3 (pipelining at every split
> point) **deferred to Slice ⑤'s wall-clock measurement**, seeded-subset fallback — recorded in §4.9
> below.

Measured at `741e0ca` by reading the suite's own declared totals and by running five throwaway
prototypes (§3.3): full `release` **120/120** in both Chez modes; Scheme mutation suite
**61 passes / 590 mutations** (`EXPECTED_PASSES` / `EXPECTED_MUTATIONS` at
`test/support/cmake/SchemeMutationSuite.cmake:1382-1383`, asserted by the lane against what
actually ran); the diagnostic census **30 codes over 56 sites**; **102** registered Scheme lanes
(`rg -c 'byte_machine_add_scheme_lane' test/CMakeLists.txt`).

---

## 1. Summary

Milestone 8 builds the thing every milestone so far has been building *for*: `§21`'s private HTTP
request fixture, the first real grammar the machine parses. `§25:1633-1642` names ten increments;
`§25:1646-1649` names four exit criteria. Nothing in `src/` changes — **this milestone spends
mechanism, it does not ship any** — and the fixture never becomes a public API.

The milestone's centre of gravity is not the grammar. It is the claim that a machine written
*only* in declared graph nodes, with callbacks that record and never decide (`§21.5:1181-1189`),
can express HTTP's case-insensitive framing recognition, its checked counters, its two body
framings, its message loop and its error positions — and that the interpreter and the generated
executor produce the same event trace for every one of them, at every split point.

Three of those claims were open questions until this document measured them, and all three are
answered by prototype rather than by argument (§3.3):

1. **Case-insensitive recognition is a byte-set chain with reexecuting fallbacks** (§4.2). Thirty
   one dispatch nodes recognize `Content-Length` and `Transfer-Encoding` in any case mixture while
   the opaque header-name span stays open across *both* the recognized and the unrecognized path —
   so `Conx` and `Content-Lengthy` still deliver every byte they consumed. Measured, in both
   lanes, on eight inputs.
2. **An error node is per span state, not per error code** (§4.3). Pass 7's flat lattice
   (decision 0029) rejects a sink joined from `none` and `(active name)` — measured as
   `inconsistent-span-state` on the first draft of the prototype. `unexpected-eof` therefore
   needs one error node per region, all naming one error declaration.
3. **The fixture does not inherit `§12.7:770`'s zero-width-machine-action defect** (§4.6). The two
   shapes `§21.4` actually needs — the framing conflict decided by a zero-width branch after the
   LF advance, and checked accumulator overflow — both answer what the spec asks for, in both
   lanes. The defect is reproducible at this base, and it is specific to a *fallible* zero-width
   action reached over a **reexecute** edge, a shape `§21`'s grammar has no producer for.

The `§21.4:1177` precondition — *before Milestone 8 implementation begins, tests must expand this
catalog into a table mapping every fixture state family to its expected byte, boundary, or EOF
error* — is the milestone's **first deliverable**, not a footnote: Slice ⓪ builds the table, and
every later slice is measured against its rows.

---

## 2. Why this shape

**The parent plan's ten increments are the slice boundaries, grouped by what shares an oracle.**
`§25:1633-1642` is already an incremental order and it is a good one: each item adds a grammar
region whose events, errors and split points can be asserted before the next exists. Grouping ten
items into five slices plus a table slice keeps each slice to one new oracle rather than one new
node kind — there are no new node kinds in this milestone at all.

**The error table comes first because it is a precondition, not a deliverable.** `§21.4:1177` says
"before Milestone 8 implementation begins". A table written *after* the fixture is a transcription
of what the fixture does; written first, it is the thing the fixture is measured against, and the
difference is the whole value. It is also the only artefact in this milestone that can be complete
before any grammar exists.

**Nothing in `src/` changes, and the milestone asserts it the way Milestone 7 did.** Milestone 7's
§4.9 gate (`git diff --stat <base>..HEAD -- src/` prints nothing) is carried forward verbatim as
§4.7. If the fixture cannot be expressed in the shipped mechanism, that is a *finding* about a
prior milestone, reported and scheduled — never a quiet `src/` edit inside a fixture slice.

**The fixture is a test artefact and stays one.** `§21.7:1209`: fixture files are never
re-exported by a public byte-machine library. §3.2 item 1 measures where the tree actually puts
such files, which is not where `§21.7` says, and §4.8 disposes the difference.

---

## 3. What the parent plan already settles

`§21` is unusually complete for a spec section: it fixes the grammar byte for byte (`§21.2`), the
event order (`§21.3`), the error codes and their positions (`§21.4`), the implementation
constraint (`§21.5`), and the exclusions (`§21.7`). This milestone therefore has far fewer open
design calls than Milestone 5 or 7 — and the ones it has are about *expression in the shipped
mechanism*, not about what the fixture should do.

What `§21` does **not** settle, and §4 resolves:

- how case-insensitive recognition is expressed without a callback parsing the name (§4.2);
- how many error nodes the fixture needs, given pass 7's lattice (§4.3);
- whether the fixed body and the chunk body share one span declaration (§4.5);
- whether trailers reuse the header nodes behind a flag or duplicate them (§4.5);
- what the message loop's idle state is, and how `message-begin` fires only when a byte is
  available (§4.4);
- which lanes the milestone registers, and what each compares (§4.6).

### 3.1 The fixture surface, measured

**What exists today that this milestone builds on**, all under
`test/support/harness/byte-machine/test/`:

| Asset | What it proves for `§21` |
|---|---|
| `http-version-machine.sls` | `§21.2:1065`'s `version = "HTTP/1.0" / "HTTP/1.1"` production, already built and driven by an absolute interpreter lane, an interpreter≡generated differential and a determinism golden. Its header names the rest as "Milestone 8, not here: case-insensitive recognition and the grammar's byte classes" |
| `counted-machine.sls` | a length-prefixed message **loop** built "in the shape §21 needs (§21.3:1149-1150: completion resets the message field and loops to request start)", with `idle`'s eof-target the finish so EOF between messages is clean and mid-message EOF is a truncation — the exact `§21` idle/partial distinction |
| `counted-machine.sls`'s span variant | a counted body **inside a span**, Milestone 6 Slice ②'s fragment trace over forty-five schedules in both lanes |
| `class-machine.sls`, `sequence-machine.sls`, `sequence-node-machine.sls` | byte classes and sequence dispatch — `§21.2`'s `tchar`, `target-byte`, `field-value-byte`, `OWS` are byte classes, and the version production is a sequence |
| `accumulate-machine.sls` | checked accumulation, the mechanism `Content-Length` and chunk size spend |
| `pause-machine.sls` | the pause/resume lifecycle `§21.5:1187` asks the fixture's callbacks to exercise |
| `error-projection.sls` | the shared error projection every differential compares through |
| `machine-print.sls`, `machine-gen.sls`, `property-driver.sls` | Milestone 7's generative surface, which a property lane over the fixture would reuse (§10 — **not** this milestone) |

**What the fixture needs from `§9.1` that is already shipped**: all thirteen node kinds, all four
matcher kinds, `u64` fields (`ir.sls:727` admits widths 8/16/32/64), accumulation in **base 10 and
base 16** (`ir.sls:412`, `accumulate-bases '(10 16)` — both of the bases `§21` needs), spans with
data and optional completion callbacks, event and decision callbacks, and counted consume for the
fixed body and chunk data. **No new mechanism is required**, which is what §4.7's gate asserts.

**The event contract, counted.** `§21.3:1116-1135` names eight spans that carry both data and
completion (`method`, `target`, `header-name`, `header-value`, `chunk-extension-name`,
`chunk-extension-value`, `trailer-name`, `trailer-value`), body data with **no** completion
callback (`§21.3:1145`), and six events (`message-begin`, `version-complete`, `headers-complete`,
`chunk-header`, `chunk-complete`, `message-complete`). That is **nine span declarations at most**
and **six event callbacks**, plus at least one decision callback for `§21.5:1187`'s lifecycle
injection — the counts §4.5 fixes.

### 3.2 Where the spec and the tree already disagree

1. **`§21.7:1209` puts fixture files under `test/fixtures`; the tree puts fixture machines under
   `test/support/harness/byte-machine/test/`.** Measured: `test/fixtures/` holds five generated
   goldens, one binary sample and a `stale-root/` guard, and **no machine**; every fixture machine
   from Milestone 1 onward is a library under the harness root, because a machine a lane imports
   must be on the library path. The *intent* of `§21.7:1209` — never re-exported by a public
   byte-machine library — is satisfied by the harness root, which no `src/` library imports.
   §4.8 disposes this as a location the spec names and the tree contradicts for a mechanical
   reason, annotating rather than moving the **nine** shipped fixture machines
   (`accumulate`, `class`, `counted`, `eof`, `http-version`, `one-byte`, `pause`, `sequence`,
   `sequence-node`; the three `machine-*.sls` beside them are Milestone 7 tooling, not fixtures).

2. **`§12.7:770`'s zero-width-machine-action half is still wrong, and this milestone is not its
   receiver.** Measured at this base by prototype (§3.3 item 3): a *fallible* zero-width action
   reached over a **reexecute** edge answers `byte` where the row says `boundary`, in **both**
   lanes, which is why no cross-lane differential sees it. The same action reached over an
   **advance** edge answers `boundary` and is correct. `§21`'s grammar has no producer of the
   broken shape (§4.6), so the receivers stay where Milestone 5's close-out put them —
   `compile.sls`'s `field-action` arm and `interpret.sls`'s `field-step`.

3. **`§21.3:1145` says "a separate body span" for each chunk and "one span" for the fixed body,
   without saying whether they are one declaration or two.** Both readings satisfy the event list,
   because both emit `body-data` and neither has a completion callback. §4.5 decides.

4. **`§21.3:1139`'s `message-begin` rule is a statement about *availability*, not about reaching a
   node.** "occurs only when the first method byte is available, before that byte is consumed" —
   a callback node fires when control reaches it, and control reaches it whether or not a byte is
   available. The idle state must therefore be an **input-reading** node whose match reexecutes
   into the callback (§4.4). `counted-machine.sls` already has exactly this shape and says so.

### 3.3 Five prototypes, run against this exact tree

All five are throwaways in the session scratchpad; none touches the repository. Each states what
it proves and nothing more.

| # | What it built | What it measured |
|---|---|---|
| **P1** | the two framing-header recognizer chains plus an opaque-name loop, with the header-name span open across both, emitted and loaded | **verifies**; **28 925** emitted bytes; interpreter ≡ generated on all eight inputs; `Content-Length:` / `content-length:` / `CoNtEnT-lEnGtH:` / `Transfer-Encoding:` → recognized, `Conx:` / `Content-Lengthy:` / `X:` → opaque, **each delivering every byte it consumed** |
| **P1a** | P1's first draft, before the fix | the two verifier refusals §4.3 and §4.4 are built on: `inconsistent-span-state` at a sink joined from `none` and `(active name)`, and `non-eof-into-finish` at a finish reached over a byte edge |
| **P2** | a framing-conflict shape: a zero-width field branch after the LF advance routing to an error node | `boundary` at the offset after the LF, **both lanes**, which is exactly `§21.4:1175`'s "between-byte boundary after the later header line's LF" |
| **P2a** | the same machine driven to overflow a `u8` counter reached over an **advance** edge | `boundary`, both lanes — the correct half of `§12.7:770` |
| **P3** | a fallible zero-width action whose **only** route in is a reexecute edge | `byte` where `§12.7:770` says `boundary`, **both lanes agreeing** — `compile.sls:351`'s OWED note reproduced at this base, and narrowed to the reexecute route |

**What the prototypes do not prove.** Nothing about wall clock, nothing about the assembled
fixture's size, and nothing about the emitted library beyond the 28 925 bytes P1 measured for the
recognizer alone. Every one of those numbers is re-measured through a registered lane before it is
written into a comment or a literal.

---

## 4. Gate 0 — design-call resolutions

Each subsection states the call, the resolution, and whether it earns a **decision record**. The
rule is Milestone 5's and 7's: a resolution is a record when it is externally observable or when a
later slice will be measured against it; otherwise it lives here and is cited from the code.

### 4.1 The error table is the milestone's first artefact, and it is fixture-owned

**Record.** `§21.4:1177` is a precondition addressed to *tests*: "before Milestone 8
implementation begins, tests must expand this catalog into a table mapping every fixture state
family to its expected byte, boundary, or EOF error. The table is fixture-owned and does not
become a generic byte-machine error catalog."

**Resolved.** Slice ⓪ ships `test/common/http-error-table-tests.sps` and a hand-written, exported
table in a fixture-owned library. A row is
`(state-family trigger expected-code position-kind offset-rule)`:

- **`state-family`** is a named region of `§21.2`'s grammar, not a node name — `request-line`,
  `method`, `target`, `version`, `header-name`, `header-value`, `content-length-value`,
  `fixed-body`, `chunk-size`, `chunk-ext-name`, `chunk-ext-value`, `chunk-data`, `chunk-ending`,
  `trailer-name`, `trailer-value`, `idle`. Node names change as slices land; a region does not.
- **`trigger`** is `byte`, `boundary` or `eof`, matching `§21.4:1175`'s three sentences.
- **`expected-code`** is one of `§21.4:1156-1173`'s **eighteen** stable codes —
  `invalid-method`, `invalid-target`, `invalid-version`, `invalid-line-ending`,
  `invalid-header-name`, `invalid-header-value`, `duplicate-content-length`,
  `invalid-content-length`, `content-length-overflow`, `duplicate-transfer-encoding`,
  `unsupported-transfer-encoding`, `framing-conflict`, `invalid-chunk-size`,
  `chunk-size-overflow`, `invalid-chunk-extension`, `invalid-chunk-ending`, `forbidden-trailer`,
  `unexpected-eof` — counted from the list, not transcribed from memory.
- **`position-kind`** and **`offset-rule`** restate `§21.4:1175` per row: a lexical error at the
  first offending **unconsumed** byte; numeric overflow at the digit that would overflow, left
  unconsumed; a duplicate/conflicting framing error at the **boundary** after the later header
  line's LF; a forbidden trailer at the **colon** following the completed forbidden name; EOF in
  any non-idle state as `unexpected-eof` at the final stream boundary.

**Two totality rows**, on Milestone 7's ratchet technique and for its reason:

1. the union of the table's `expected-code` column **set-equals** the codes the fixture's own
   error declarations name, read from the machine rather than transcribed — so a nineteenth code
   cannot ship without a row — **and contains all eighteen** `§21.4` names. Both halves are
   needed: `§21.4:1154` says the list "include"s those codes, so it is a floor and not a ceiling,
   and a table checked only against the spec would miss a code the fixture invented;
2. every `state-family` the fixture declares has **at least one** row of each trigger kind it can
   produce, with the families that cannot produce one naming their reason.

**And the thing the table must not become.** `§21.4:1177`'s second sentence is a constraint on
*scope*: this table is the HTTP fixture's, it lives beside the fixture, and it never grows into a
byte-machine error catalog. `§27:1696`'s diagnostic catalog is a different, unscheduled document
(Milestone 7's §10 says so); this table is not its first instalment and says so in its header.

**Why a record.** Every slice from ① onward is measured against these rows, and the rows are
written before the nodes they describe exist — which is the entire point of a precondition.

### 4.2 Case-insensitive recognition is a byte-set chain with reexecuting fallbacks

**Record.** `§25:1637` item 5 is "case-insensitive fixture recognition of framing headers", and
`§21.5:1181` puts *all* recognition in declared graph nodes: a callback may not parse header
contents. `§21.2:1101` adds that "ordinary header names remain opaque spans" — so recognition must
not cost the opaque path its bytes.

**Resolved, and measured (P1).** One dispatch node per grammar character. Each node carries **one
case** whose matcher is the `byte-set` of that character's two cases (one byte where the character
has no case, such as the hyphen), advancing to the next node; its **fallback reexecutes into the
generic opaque-name loop**. The header-name span is opened *before* the chain and closed at the
colon, so it accumulates every consumed byte on both paths.

Three properties, each measured rather than argued:

- **No case-set arithmetic.** Because the fallback reexecutes, no node needs `tchar` minus the
  accepted bytes; a node has exactly one case, so `§16.2:893`'s overlap rule is satisfied by
  construction. The first draft that computed set differences is not needed and is not built.
- **The opaque path keeps its bytes.** `Conx:` delivers `Conx`, `Content-Lengthy:` delivers
  `Content-Lengthy` — measured, both lanes. This is the property a recognizer built out of a
  sequence node would lose, because a sequence mismatch has no way to hand the consumed prefix to
  a span.
- **Cost.** `Content-Length` is thirteen nodes after the shared first-byte dispatch,
  `Transfer-Encoding` sixteen; with the branch node and the opaque loop that is **31** nodes, and
  the probe emitted **28 925** bytes. Milestone 7 Slice ④'s `§16.2:911` witness already compiled a
  larger generated library with `compile-file` and ran it, so emission size is a measurement to
  take, not a risk to mitigate.

**Rejected: a sequence node per framing header.** `§21.2:1101`'s case-insensitivity would need
2^13 and 2^16 alternatives, and a mismatch would still have to hand back the consumed prefix.

**Rejected: recognition in a callback.** `§21.5:1189` forbids it in those words.

**Why a record.** It is the milestone's central expression choice, every framing slice is built on
it, and a later reader who sees thirty-one near-identical dispatch nodes needs the reason at hand.

### 4.3 An error node is per span state, not per error code

**Record.** Measured (P1a): a single `reject` error node reached both from inside the header-name
span and from after it was closed is refused by `pass-spans` as **`inconsistent-span-state`**.
Decision 0029 item 1 fixes the abstract domain as a **flat lattice of height two** over
`{none, (active s), …}`, so a join of any two distinct elements is `⊤` — joining `(active a)` with
`(active b)` is refused exactly as joining `(active a)` with `none` is.

**Resolved.** The fixture declares **one error node per (code × span state it is reachable in)**,
all naming one error **declaration** per code — so the reported `parser-error-code` and reason are
per code, as `§21.4` requires, while the graph satisfies pass 7. Two consequences the slices must
budget for:

- `unexpected-eof` is reachable from every non-idle region, so it needs one error node per region
  whose EOF route it serves — on the order of **ten**, all naming one declaration.
- The lexical rejections (`invalid-method`, `invalid-target`, …) are each raised from inside their
  own region and therefore mostly need one node each.

**This is not a workaround and is not recorded as one.** Pass 7 is refusing a real ambiguity: a
sink reached with different spans open has no single answer to "which span was active when the
error was reported", and `§14`'s retention rules are stated per span.

**Why a record.** It fixes the fixture's error-node count and shape, it will look like duplication
to anyone reading the machine, and the first slice that tries to share a sink will otherwise
rediscover it as a verifier failure mid-task.

### 4.4 The idle state, `message-begin`, and clean EOF only while idle

**Record.** Three `§21` sentences meet at one node: `§21.3:1139` (`message-begin` fires only when
the first method byte is **available**, before it is consumed; empty feeds and clean idle EOF do
not start a message), `§21.3:1150` (completion resets the explicit message fields and returns to
request start without resetting the absolute stream offset) and `§25:1642` (pipelined requests and
clean idle EOF).

**Resolved**, on `counted-machine.sls`'s shipped shape:

- **`idle` is a byte dispatch**, not a callback node. Its single case matches `tchar` and
  **reexecutes** into the `message-begin` callback node, so the byte is available but unconsumed
  when the event fires; its **eof-target is the finish terminal**, so EOF while idle is `finished`;
  its fallback rejects with `invalid-method`.
- **Every other input-reading node routes EOF to an `unexpected-eof` error node** for its region
  (§4.3), which the machine default-eof declaration names — so `§21.4:1175`'s "EOF in any non-idle
  state" is the machine's default and idle is the one override.
- **The finish terminal is reachable only over an EOF route.** Measured (P1a): a finish reached
  over a byte edge is refused as `non-eof-into-finish` (`§16.2:908`). This is not a constraint the
  fixture works around — it *is* "clean EOF only while idle", enforced by the verifier.
- **Completion loops to `idle` through a chain of `clear` field actions.** `clear` is infallible
  (`ir.sls`'s `infallible-field-operations`), so the chain takes no error edge and cannot produce
  `§12.7:770`'s broken shape (§4.6). The absolute stream offset is the runtime's and is not reset.

**Why a record.** Pipelining, the empty-feed rule and the clean-EOF rule are all consequences of
this one node's shape, and a slice that makes `idle` a callback node would pass its own tests and
fire `message-begin` on an empty feed.

### 4.5 The declaration tables: nine spans, six events, one decision, and the trailer question

**Design-internal; no record.** `§21.3`'s event list fixes most of this; two readings are open.

**The spans (nine).** `method`, `target`, `header-name`, `header-value`, `chunk-ext-name`,
`chunk-ext-value`, `trailer-name`, `trailer-value` each with a data callback **and** a completion
callback; `body` with a data callback and **no** completion callback (`§21.3:1145`).

**The fixed body and the chunk body share the `body` declaration.** `§21.3:1145`'s "one span" and
"a separate body span" describe span *instances* — one per fixed body, one per nonempty chunk
payload — not two declarations: both emit `body-data`, neither has a completion callback, and a
second declaration would put a second name into the trace for an event the contract spells one
way. Pass 7's lattice is indifferent, since the two are never simultaneously active.

**Trailers get their own two span declarations and reuse the header *nodes* only if a slice
measures that it can.** `§21.3:1132` names `trailer-name-data` and `trailer-value-data` as
distinct events, so the declarations are distinct. Whether the *nodes* are shared behind a
"we are in the trailer section" flag, or duplicated, is a Slice ④ measurement: sharing costs a
field and a branch per region exit and makes every trailer error node reachable from the header
region too (§4.3), which may cost more nodes than duplication saves. **The design does not decide
it from reading**; §11 hands it to the slice with the measurement to take.

**The events (six).** `message-begin`, `version-complete`, `headers-complete`, `chunk-header`,
`chunk-complete`, `message-complete` — all `event` kind.

**One decision callback, for `§21.5:1187`.** The lifecycle tests need a callback that can answer
`pause` and explicit failure. It is declared `decision` with a default branch, and it is invoked at
one node — the design's preference is `headers-complete`, because it sits at a boundary both body
framings pass through, but the slice that builds the lifecycle lane picks the site and records why.

### 4.6 What the fixture does *not* inherit, measured

**Design-internal; no record beyond the disposition §4.8 item 3 writes.**

`§12.7:770`'s zero-width-machine-action half is wrong at this base and this milestone is **not**
its receiver. The argument is three measurements, not a reading:

- **The framing conflict is correct.** `§21.4:1175` wants a duplicate/conflicting framing error at
  "the between-byte boundary after the later header line's LF". P2 built exactly that — a
  zero-width field branch reached after the LF advance, routing to an error node — and both lanes
  answered **`boundary`** at the offset after the LF.
- **Checked accumulator overflow is correct, and `§12.7:773` governs it**, not `:770`:
  "integer-overflow nodes reject and do not consume the overflowing digit, so their position is the
  offending byte" — which is what `§21.4:1175` asks for in the same words. `Content-Length` and
  chunk size are `integer-accumulate` nodes, so `content-length-overflow` and `chunk-size-overflow`
  are `byte` at the offending digit by the shipped rule.
- **The broken shape has no producer in `§21`.** P3 isolated it: a *fallible* zero-width action
  whose only route in is a **reexecute** edge answers `byte` where the row says `boundary`, in both
  lanes. `§21`'s field actions are the framing flags (`store`) and the completion reset (`clear`),
  both in `ir.sls`'s `infallible-field-operations` and therefore unable to take an error edge at
  all; the counters are accumulate nodes. The fixture has no fallible zero-width action.

Milestone 6 made the same determination for counted consume and recorded it as a finding in its
Slice ①; this milestone records it the same way, and the receivers stay where Milestone 5's
close-out put them. **If a slice finds itself reaching for `increment` or `add` with an error
edge, that slice becomes the receiver** and says so rather than encoding the wrong position in the
error table.

### 4.7 What does not change — the gate every slice asserts

No `src/` change of any kind: `git diff --stat <milestone base>..HEAD -- src/` prints nothing
across the whole milestone, and every committed golden and every pinned fingerprint literal that
predates the milestone is byte-identical. `test/` and `docs/` change everywhere. One line of
output from that command means this document is wrong and is amended before the code lands —
Milestone 7's §4.9 verbatim, minus its one `verify.sls` exception, which this milestone does not
need.

### 4.8 Obligations addressed to this milestone, each disposed

Measured: `rg -n -i 'milestone 8' src/ test/ .decisions/ .reference/` returns **two** test
sites and **no** `src/` or decision site; the same search over `.plans/` adds the design and
slice-plan deferrals item 2 to item 7 name, plus the parent plan's `§21.4:1177` and `§25:1629`.

1. **`§21.4:1177`'s precondition** — the error table. Closed by **Slice ⓪** (§4.1), which is the
   milestone's first slice for that reason.
2. **Case-insensitive recognition and the fixture's byte classes**, deferred here by Milestone 3's
   design §8 (*Explicitly out of Milestone 3*: "M3 ships the *mechanism*; M8 spends it") and by
   `http-version-machine.sls`'s header ("Milestone 8, not here: case-insensitive recognition and
   the grammar's byte classes"). Closed by **Slices ① and ③**; the fixture-machine header gets its
   closing note, which is the receiver end.
3. **Everything the fixture does with fields** — `Content-Length`, chunk sizes, chunk extensions,
   framing conflicts — deferred here by Milestone 4's design §9 (*Explicitly out of Milestone 4*) in those words. Closed by
   **Slices ③ and ④**.
4. **`§25:1648`'s "interpreter and generated traces match"**, which Milestone 4's design §4.6
   identified as *this* milestone's criterion, sitting beside `§21.3:1114`'s fixture event trace.
   Closed by **every slice's differential lane** and dispositioned at the close.
5. **`§21.7:1209`'s file location** (§3.2 item 1). Disposed as an annotation: the fixture machines
   live under the harness library root because a lane must import them, and the *intent* — never
   re-exported by a public library — is asserted by **Slice ⑤**'s leak check (§4.9's exit criterion
   four). The parent plan gets a dated disposition saying the tree satisfies the sentence's purpose
   at a different path, and `§21.7:1209` is **not** reworded.
6. **`§12.7:770`'s zero-width-machine-action half** — not this milestone's (§4.6), receivers
   unchanged. The close note says so with P2's and P3's measurements, so the next milestone does
   not have to re-derive them.
7. **A property lane over the HTTP fixture** — Milestone 7's §10 hands it here by name
   (`§25:1629-1649`). §10 **declines** it for this milestone and says why, naming Milestone 9 or a
   hardening slice as the receiver: the generative surface exists, but a generator that draws
   *HTTP-shaped* inputs is a different instrument from one that draws machines, and this milestone's
   ten increments already carry a lane pair per slice.

### 4.9 Scope additions, for the owner

Each is priced, with a recommendation, and names its slice. Nothing here is started before the
owner settles it (`AGENTS.md`: an approval with no receiver is invisible to every completeness
sweep).

> **Owner disposition (2026-09-12).** Item 1 **approved** — receiver **Slice ①** (built there,
> extended by each later slice). Item 2 **approved** — receiver **Slice ⓪** (the exported
> fixture-region → node-name map starts empty and grows a row per slice, with its totality row).
> Item 3 **deferred to Slice ⑤'s wall-clock measurement**, seeded multi-split subset as the stated
> fallback — no standing commitment either way until ⑤ measures.

1. **An `§21.3` event-order oracle shared by every lane, rather than per-lane expected traces.**
   The event contract is a *grammar over events*; a shared checker that validates any trace against
   `§21.3:1116-1135` catches an ordering defect no single expected-trace case was written for.
   Price: one test-support library, roughly the size of `error-projection.sls`, built in Slice ①
   and extended by each later slice. **Recommended: approve.** Declining leaves ordering asserted
   only where someone thought to write it down.
2. **A fixture-state → node-name map exported for the error table's rows.** §4.1 keys rows on
   grammar regions so they survive node renames; a map from region to the node names currently in
   that region makes a failure name the node without coupling the table to it. Price: one exported
   alist per slice, and one totality row asserting every declared node is in exactly one region.
   **Recommended: approve** — it is also the thing that makes "every state family has a row"
   checkable rather than asserted.
3. **Pipelined-request coverage at every split point, not only at representative ones.**
   `§25:1647` asks for "representative messages" at every split point; pipelining multiplies the
   schedule count. Price: measured, not guessed — Slice ⑤ takes the wall clock for the full
   product before choosing, and the fallback is a seeded random multi-split subset
   (`§22.5:1283`'s shape, which three shipped differentials already use). **Recommended: decide
   from the measurement**, with the seeded subset as the stated fallback.

---

## 5. Slice ⓪ — The fixture-state → expected-error table

**Scope, as an allocation.** Discharges `§21.4:1177`'s precondition. Depends on Gate 0 only. Ships
**no machine**: it is the one artefact that can be complete before any grammar exists, and writing
it after the fixture would make it a transcription of what the fixture does.

**The work.**

- `test/support/harness/byte-machine/test/http-error-table.sls` — the hand-written, exported table
  of §4.1's rows, keyed by grammar region, with `§21.4:1175`'s five position sentences restated per
  row and each row citing the `§21.2` production it guards.
- `test/common/http-error-table-tests.sps`, one lane pair (`byte-machine.unit.http-error-table`):
  the two totality rows of §4.1, the shape guards (every trigger is one of three symbols, every
  code a symbol, every region distinct), and the **eighteen**-code floor asserted against
  `§21.4`'s list spelled out in the test.
- The header states, in the file, that this table is the fixture's and never becomes a
  byte-machine error catalog (`§21.4:1177`, second sentence) — and that `§27:1696`'s catalog is a
  different, unscheduled document.

**Oracle.** *Total over the codes:* the union of the rows' codes contains all eighteen `§21.4`
names. *Total over the regions:* every region named in the table has a row for each trigger kind
it can produce, and a region that cannot produce one carries its reason as data, not as a comment.
*Fixture-owned:* the table's library is imported by no `src/` library — the §4.7 gate plus the
leak check Slice ⑤ generalizes.

**What it cannot assert yet**, and says so: that the regions match the fixture's nodes. That is
scope addition 2 (§4.9), and if approved the map lands here and grows a row per slice.

---

## 6. Slice ① — The request line

**Scope, as an allocation.** `§25:1633-1634` items 1 and 2: request method and target spans; HTTP
version and strict request-line CRLF. Depends on ⓪.

**The work.**

- `test/support/harness/byte-machine/test/http-machine.sls`, the fixture machine, built through
  `(byte-machine graph)` only (`§21.5:1181`): the `idle` dispatch of §4.4 with its finish
  eof-target and its reexecuting `message-begin`; the `method` and `target` spans over `tchar` and
  `target-byte` classes, each ending **before** its delimiter SP is consumed (`§21.3:1140`); the
  version production, which is `http-version-machine.sls`'s two-alternative sequence lifted into
  the fixture; strict CRLF with `invalid-line-ending` for a bare CR or a bare LF.
- Three lanes: `byte-machine.unit.http-request-line` (absolute event and position assertions),
  `byte-machine.differential.http` (interpreter ≡ generated, `§25:1648`'s criterion, extended by
  every later slice), and the split-point coverage folded into the differential as the shipped
  differentials fold `§22.5`'s schedules.
- Scope addition 1's event-order oracle, if approved, lands here and is extended by each later
  slice.

**Oracle.** *Events:* the `§21.3` prefix `message-begin method-data* method-complete target-data*
target-complete version-complete` in order, per schedule. *Positions:* the request-line rows of
Slice ⓪'s table, byte for byte. *Split points:* every split of a representative request line, with
the event sequence invariant across all of them and the raw fragment trace **not** invariant — the
negative sentinel Milestone 5's span differential established.

---

## 7. Slice ② — Headers, the empty line, and the no-body loop

**Scope.** `§25:1635-1636` items 3 and 4: general header name/value spans; headers-complete and
the no-body message loop. Depends on ①.

**The work.**

- The generic header loop: `header-name` over `tchar` ending before the colon; OWS consumed after
  the colon **before** the value span opens, with the trailing OWS inside the span
  (`§21.2:1097`, which also says why: v0.1 has no trailing-marker primitive); `header-value` over
  `field-value-byte` ending before CR; the empty-line CRLF producing `headers-complete` **after**
  it is consumed (`§21.3:1144`).
- The message loop of §4.4: `message-complete` after the empty-body terminator, the `clear` chain,
  and the return to `idle` with the absolute offset untouched.
- The all-OWS value case `§21.2:1097` calls out by name: an empty value span followed by
  completion.

**Oracle.** *Events:* the header block's `(header-name-data* header-name-complete
header-value-data* header-value-complete)*` repetition, then `headers-complete`, then
`message-complete`. *The loop:* two requests in one feed produce two complete event sequences with
one `message-begin` each and no reset of the stream offset — the property `counted-machine.sls`
already demonstrates for a length-prefixed loop. *Positions:* the header rows of the table.

---

## 8. Slice ③ — Framing recognition and the fixed body

**Scope.** `§25:1637-1638` items 5 and 6: case-insensitive recognition of the framing headers;
checked `Content-Length` and the fixed body. Depends on ②. **This is the slice §4.2 exists for.**

**The work.**

- The recognizer chains of §4.2, measured by P1 and re-measured through the lane: thirty-one
  dispatch nodes, the opaque path keeping its bytes, no case-set arithmetic.
- `Content-Length`'s value: base-10 checked accumulation into a `u64` field, `*OWS` after the
  digits (`§21.2:1073`), `invalid-content-length` for anything else and `content-length-overflow`
  at the offending digit (`§12.7:773`, and `§21.4:1175` in the same words).
- The framing flags and the three refusals `§21.2:1102-1106` states: any second `Content-Length`
  (`duplicate-content-length`), any second `Transfer-Encoding` (`duplicate-transfer-encoding`), and
  any request carrying both (`framing-conflict`) **rejected when the later header line completes** —
  the zero-width branch after the LF advance that P2 measured at `boundary`.
- `Transfer-Encoding`'s value: case-insensitive `chunked` plus optional trailing OWS, anything else
  `unsupported-transfer-encoding` — a second, shorter application of §4.2's chain.
- The fixed body: a counted consume of exactly `Content-Length` octets inside the `body` span, with
  no completion callback (`§21.3:1145`), then `message-complete`.

**Oracle.** *Recognition:* a table of names — canonical, lowercase, mixed case, a prefix
(`Content-Leng`), an extension (`Content-Lengthy`), a near miss (`Content_Length`) — each asserted
to hit or miss **and** to deliver its whole name as span data. *Framing:* the three refusals, each
at the boundary the table names. *The body:* `§22.5`'s schedules across the body boundary, with the
body fragments coalescing identically at every split.

---

## 9. Slice ④ — The chunked body, extensions, the zero chunk, and trailers

**Scope.** `§25:1639-1640` items 7 and 8. Depends on ③.

**The work.**

- Chunk size: base-16 checked accumulation with leading zeroes permitted (`§21.2:1108`),
  `invalid-chunk-size` and `chunk-size-overflow` at the offending digit.
- `chunk-header` after **every** chunk-size line CRLF including the zero chunk, exposing the
  checked size field (`§21.3:1146`).
- Chunk data: a counted consume inside a fresh `body` span instance per nonempty chunk, framing
  octets never body data (`§21.3:1145`), `chunk-complete` after the data-terminating CRLF
  (`§21.3:1148`), `invalid-chunk-ending` when that CRLF is not there.
- Chunk extensions: `*(";" token ["=" token])`, names and values as spans excluding their
  delimiters (`§21.3:1147`), `invalid-chunk-extension` otherwise. Quoted values and escapes are
  **excluded** (`§21.2:1109`) and the rejection is a row in the table, not an omission.
- The zero chunk proceeding directly to trailers, the trailer section reusing the header grammar,
  and `forbidden-trailer` at the colon following a completed `Content-Length` or
  `Transfer-Encoding` trailer name (`§21.2:1110`, `§21.4:1175`).
- **The trailer-sharing measurement** §4.5 hands to this slice: share the header nodes behind a
  flag, or duplicate them, decided by node count and by how many error nodes §4.3 forces either
  way — measured in a scratch worktree before the shape is committed.

**Oracle.** *Events:* `§21.3:1124-1133`'s chunk and trailer sub-grammars in order, including the
zero chunk's extension block. *Sizes:* a chunk size with leading zeroes, a maximal `u64` size, and
the size one digit past it. *Trailers:* a permitted trailer, a forbidden one, and the empty trailer
section.

---

## 10. Slice ⑤ — Framing conflicts, malformed input, pipelining, clean EOF, and the close

**Scope.** `§25:1641-1642` items 9 and 10, plus the milestone close. Depends on ④.

**The work.**

- Every remaining row of Slice ⓪'s table driven as a negative case: each of the eighteen codes
  produced at the position the table states, in both lanes, with the region and the trigger named
  in the check label.
- Pipelined requests: several complete requests in one feed, in every framing combination
  (no body / fixed / chunked), and the split-point coverage §4.9 item 3 prices.
- Clean idle EOF, and `unexpected-eof` from **every** non-idle region — the per-region error nodes
  of §4.3, each witnessed.
- **The leak check** (`§25:1649`, and §4.8 item 5's receiver): a structural test that no library
  under `src/` imports the fixture, that no public library re-exports an HTTP name, and that the
  fixture's own library names carry no HTTP vocabulary into `(byte-machine …)` — read as data from
  the tree, on the census technique, not asserted in prose.
- The determinism golden, `byte-machine.determinism.http`, on the five shipped goldens' shape.
- **The close-out**: `§25:1633-1649` dispositioned against the tree, §4.8's seven obligations at
  both ends, §4.9's approved items recorded as shipped or declined, the Exit table dispositioned in
  place, all four status surfaces, and the close note.

**Oracle.** *Errors:* the table, row by row, is the oracle — that is what it was written first for.
*Pipelining:* N requests in one feed produce N complete event sequences and one final `finished`.
*The leak check:* measured from the tree, and it fails if a future slice re-exports the fixture.

---

## Exit (full Milestone 8)

`§25:1646-1649`'s four criteria, allocated to the slices that will discharge them. At close, each
entry gets a **dated disposition** naming the slice, the file and the case in the tree that meets
it — never reworded to match what shipped.

| Criterion | Allocated to | What will meet it |
| --- | --- | --- |
| **:1646** — "the complete fixture behavior in Section 21 passes" | **①-⑤** | Every `§21.2` production built, every `§21.3` event asserted in order, every `§21.4` code produced at its stated position; the close note walks `§21.2`, `§21.3` and `§21.4` clause by clause against the tree |
| **:1647** — "representative messages pass every split point" | **①-⑤**, priced in **⑤** | `§22.5`'s schedules over a representative message per framing, with the event sequence invariant across all splits and the raw fragment trace not — the negative sentinel that makes the positive mean something. §4.9 item 3 decides the pipelined product by measurement |
| **:1648** — "interpreter and generated traces match" | **①-⑤** (`byte-machine.differential.http`) | The event trace, the per-schedule result tuple and the projected error compared across lanes for every fixture case — the criterion Milestone 4's design §4.6 identified as this milestone's |
| **:1649** — "the fixture remains private and no HTTP API leaks into public libraries" | **⑤** | The structural leak check, read from the tree; plus §4.7's gate, which proves no `src/` file changed at all |

---

## 11. Explicitly out of Milestone 8

- **Everything `§21.7:1197-1207` excludes**: responses and status lines, upgrades and CONNECT,
  lenient modes, obsolete line folding, complete RFC request-target validation, all transfer-coding
  combinations, production-grade duplicate `Content-Length` normalization, keep-alive policy,
  configurable limits, request-object construction, and public HTTP names or packages.
- **Any `src/` change** — §4.7's gate. A fixture that cannot be expressed in the shipped mechanism
  is a finding about a prior milestone, reported and scheduled, never a quiet edit.
- **A property lane over the HTTP fixture** (§4.8 item 7). Milestone 7's §10 hands it here by name;
  this milestone declines it with a reason: a generator that draws HTTP-shaped *inputs* is a
  different instrument from Milestone 7's generator over *machines*, the ten increments already
  carry a lane pair per slice, and the fixture must exist before anything can fuzz it. Receiver:
  Milestone 9, or a hardening slice, named in the close note.
- **`§12.7:770`'s zero-width-machine-action half** (§4.6) — receivers unchanged, with P2's and
  P3's measurements written into the close note so the next milestone does not re-derive them.
- **A generic byte-machine error catalog** — `§21.4:1177`'s second sentence forbids this table from
  becoming one, and `§27:1696`'s catalog names no milestone.
- **Moving the shipped fixture machines to `test/fixtures`** (§4.8 item 5) — the intent is asserted
  by the leak check; the path is annotated, and `§21.7:1209` is not reworded.

---

## 12. Handed to writing-plans

- **Gate 0 writes four records**: §4.1 (the error table is the first artefact and is
  fixture-owned), §4.2 (case-insensitive recognition is a byte-set chain with reexecuting
  fallbacks), §4.3 (an error node is per span state), §4.4 (the idle node, `message-begin`, and
  clean EOF only while idle). §4.5 and §4.6 stay in this document and are cited from the code.
- **Re-measure every `file:line`, every count and all five prototypes at plan-writing time.** They
  were measured at `741e0ca`, before Milestone 7's squash reached `main`. Slice ⓪'s plan re-takes
  the whole baseline at its own base first, and this branch rebases with
  `git rebase --onto main 741e0ca`, never a plain `git rebase main`.
- **§4.9 is unsettled**: items 1-3 go to the owner before Slice ⓪ starts, and each lands in the
  slice it names or is recorded as declined. An approval with no receiver is invisible to every
  completeness sweep.
- **Two measurements are handed to slices, not decided here**: the trailer node-sharing question
  (Slice ④, §4.5) and the pipelined split-point product (Slice ⑤, §4.9 item 3). Each is taken in a
  scratch worktree before the shape is committed, and each is priced with a stated fallback.
- **Each slice is one source commit plus one documentation commit, one PR**, with its pins and its
  `EXPECTED_MUTATIONS` arithmetic in the source commit — Milestone 6 §9's partition rule.
- **Every slice's plan states which rows of Slice ⓪'s table it makes true**, by region and trigger.
  That is how the table stops being a document and becomes the milestone's spine.
- **The mutation surface grows with the fixture, not after it.** Each slice pins the decisions its
  own nodes encode — a recognizer node's byte set, a span's end position, a counted body's bound,
  the framing flags' order of test — and the pin's failure signature is asserted, never a bare
  nonzero exit.

---

## Appendix — the fixture-state → expected-error table, as an instruction

**This skeleton is an instruction**: Slice ⓪ works it row by row, and a row it cannot follow is
corrected in place with the reason. Regions are `§21.2` productions; the codes are `§21.4`'s
eighteen. Cells marked *—* are the claim that the region cannot produce that trigger, and each one
must carry its reason as data in the shipped table.

| Region | `byte` trigger | `boundary` trigger | `eof` trigger |
|---|---|---|---|
| `idle` | `invalid-method` (not a `tchar`) | — | *clean finish*, not an error |
| `method` | `invalid-method` | — | `unexpected-eof` |
| `target` | `invalid-target` | — | `unexpected-eof` |
| `version` | `invalid-version` | — | `unexpected-eof` |
| `request-line-crlf` | `invalid-line-ending` | — | `unexpected-eof` |
| `header-name` | `invalid-header-name` | — | `unexpected-eof` |
| `header-value` | `invalid-header-value` | — | `unexpected-eof` |
| `header-crlf` | `invalid-line-ending` | `duplicate-content-length`, `duplicate-transfer-encoding`, `framing-conflict` (after the later line's LF) | `unexpected-eof` |
| `content-length-value` | `invalid-content-length`, `content-length-overflow` (at the offending digit) | — | `unexpected-eof` |
| `transfer-encoding-value` | `unsupported-transfer-encoding` | — | `unexpected-eof` |
| `fixed-body` | — | — | `unexpected-eof` |
| `chunk-size` | `invalid-chunk-size`, `chunk-size-overflow` | — | `unexpected-eof` |
| `chunk-ext-name` / `chunk-ext-value` | `invalid-chunk-extension` | — | `unexpected-eof` |
| `chunk-data` | — | — | `unexpected-eof` |
| `chunk-ending` | `invalid-chunk-ending` | — | `unexpected-eof` |
| `trailer-name` | `invalid-header-name` | `forbidden-trailer` (at the colon after the completed name) | `unexpected-eof` |
| `trailer-value` | `invalid-header-value` | — | `unexpected-eof` |

**The two rows this table cannot fill from reading**, and Slice ⓪ must decide with the grammar in
front of it: whether `forbidden-trailer`'s position is a `byte` at the colon or a `boundary` after
the name completes (`§21.4:1175` says "at the colon following the completed forbidden name", which
reads as the colon **unconsumed** and therefore `byte`), and whether `fixed-body` and `chunk-data`
can produce any non-EOF error at all once the count is fixed (they consume exactly N octets and
reject nothing, so the *—* is expected to survive — but it is a claim, and Slice ⓪ states it as
one).

---

## References

- Parent plan: `.plans/byte-machine-implementation-plan.md` — `§21` in full (`:1050-1209`),
  `§25:1629-1649` (scope and exit), `§22.4`, `§22.5`, `§22.8`, `§22.9`, `§12.7:760-777`,
  `§9.1`, `§10.6`, `§13`, `§14`, and the appended `## Dated dispositions` section.
- `.plans/milestone-7-design.md` — the structural template, its §4.9 gate, and its §10, which
  hands the property lane over the fixture here.
- `.plans/milestone-6-design.md` §8 and `milestone-6-slice-2-implementation-plan.md` — the
  counted body inside a span, and the `§21`-shaped message loop `counted-machine.sls` ships.
- `.plans/milestone-3-design.md` §8 and `milestone-4-design.md` §9 — the two deferrals that
  name this milestone for case-insensitive recognition and for the fixture's field work.
- Decisions 0015 (independent interpreter representation), 0023 and 0027 (the reachability
  relations), 0029 (the span lattice — §4.3's warrant), 0030 (counted consume), 0033 (the property
  suite's contract).
- `AGENTS.md` — testing and mutation discipline, documentation and record discipline.
