# Milestone 12 — Slice ① (a pause carries a reason, end to end) Implementation Plan

Authority: [decision 0046](../.decisions/0046-a-pause-carries-a-reason.md) (the
optional-reason primitive, the distinct result slot, the ABI bump, the
normalizer/errs seam), then [milestone-12-design.md](./milestone-12-design.md)
§5 (the slice), §3.1–§3.7 (the seams §5 builds on), then the upstream brief
`chez-httparse/.plans/2026-09-14-upstream-pause-reason-brief.md` §4 (the six
acceptance criteria), §5 (the two traps), §6 (what not to do).

This slice gives a **pause** the same `(code, reason)` identity an error has,
**without making it an error**: an **optional** reason declaration on the two
author-facing pause node kinds (`pause`, `callback`), carried to a **distinct**
`parser-result-pause` slot (the error slot stays `#f`), through the interpreter,
the normalizer, the fingerprint, and the emitter, with the generated ABI bumped
**6 → 7**. It is **one census-shaped change in one commit**, because a plan that
split the ABI bump, the result-shape growth, and the emitted pause arms would
schedule a red intermediate (AGENTS.md, "A plan that schedules a red intermediate
commit is the thing that is wrong").

**Measured base (v0.3.0, `9c027fd`; re-measure at the branch base as Task 0's
first act — AGENTS.md, a green run with stale declared totals is the false
comfort the totals gates exist to break):** `pr` **153/153**, Scheme mutation
**69 passes / 622 mutations**, diagnostic census **32 codes / 58 sites**, fourteen
node kinds, generated **ABI 6**, **seven** determinism goldens. Nothing has merged
to `main` since; this slice merges onto `9c027fd`.

At the end of the slice (targets, re-measured not predicted): `pr` green in both
Chez modes with the pause lanes extended (no new lane expected — the reason rides
the existing `differential.pause` / `unit.pause` / `determinism.pause` lanes);
mutation totals up by the new pins; diagnostic census up by the one new resolution
site (32/58 → **32/59** if the code is reused, or **33/59** + a fixture + a catalog
row if a new `missing-pause-declaration` code is chosen); ABI **7**; all seven
goldens regenerated to ABI 7 (the pause golden additionally re-baselined for its
reason arm).

---

## 1. What the change is

A pause today yields `status = 'paused` with the result's error slot `#f`
(measured: a one-pause probe reports `(status paused error #f stream-offset 1)`).
This slice adds:

- an **optional** reason to `make-pause-node` and `make-callback-node` — a
  declared error-declaration NAME, or `#f` (today's behaviour); no existing
  machine changes (brief criterion 1);
- a **distinct** `parser-result-pause` slot carrying a `parser-error`-shaped value
  built from the resolved declaration, with `parser-result-error` staying `#f` for
  a pause (brief §6; so a consumer that checks only the error slot still reads
  "not failed"); `status` stays `'paused` and the lifecycle rows do not move
  (brief criterion 3);
- coverage of **both** author-facing pause paths — the `pause` node and the
  `callback` node — via one `pause-reason-of` helper (brief §5 trap 2). The
  span-data/span-complete callback pauses and the flush pause stay `#f`
  (design §3.4);
- the generated **ABI 6 → 7**, because the emitted paused-outcome's payload
  contract moves (its error slot goes from always-`#f` to `#f | ParserError`);
  the ABI lane reads 7 out of the emitted text (brief criterion 5).

The reason DATA reuses the existing `error-declaration` family — a pause reason is
the same `(code, reason)` the consumer renames through its one table
(`paused-upgrade . 22` beside `paused-h2-upgrade . 23`, brief §7). "It is not an
error" is enforced at the result (the distinct slot + `'paused`), not the
declaration.

## 2. Task 0 — the prototype (decision 0046 item 8), in an isolated worktree

Before any fixture, prototype the load-bearing shape in a scratch worktree
(`isolation: worktree` for any agent; or a throwaway `git worktree` — never the
live checkout, AGENTS.md "Run review and audit fan-outs in an isolated worktree").
Confirm in **both** lanes:

1. a pause node with a declared reason reports the reason in the pause slot, the
   error slot `#f`, status `'paused`;
2. a **resume then a re-pause at a second node** reports the SECOND reason, not
   the first (brief criterion 4) — there is no stored pause state (verified:
   `parser-set-stored-error!` is error-only, `runtime.sls:856`/`:1201`; a pause
   result is computed fresh from `current`), so this should hold, but prove it;
3. reusing `error-declaration` (named by a pause node) trips **no** verifier pass
   — if it does, fall back to a minimal `pause-declaration` family of the same
   shape (brief §4.1 sanctions either);
4. a generated reason-bearing pause **emits and runs end-to-end** (not merely
   grepping the ABI literal): the errs-table reached-walk arm and the normalizer
   threading (§3.7) are exercised, so the emit-time `no error declaration for
   code` assertion (`compile.sls:651-660`) cannot hide until fixtures; and the
   emitted ABI literal reads 7.

The prototype is discarded; its findings settle any open shape question before the
committed work begins. It is also where the size measurement (brief criterion 6)
is first taken and then re-taken through the committed fixture.

## 3. The work, by surface

Anchors measured at `9c027fd`; the implementer re-resolves every `file:line` as
the last step before commit (AGENTS.md).

- **IR (`src/byte-machine/private/ir.sls`).** `make-pause-node` (`:357`, arity 3)
  and `make-callback-node` (`:703`, arity 6) gain an optional trailing reason via
  `case-lambda` — the base arity is unchanged, so every existing call site
  (including `machine-corrupt.sls`'s positional edits and `property-driver.sls`'s
  rebuilds) is untouched (brief criterion 1). Add `pause-node-reason` and
  `callback-node-reason`, each length-guarded to return `#f` on the short arity.
  The reason is a symbol or `#f` (local shape only); declaredness is the
  verifier's. Export the two accessors from `ir.sls`; they are private (a test
  needing them imports from `(byte-machine private ir)`, AGENTS.md) — the public
  `graph.sls` façade re-exports only the constructors.
- **Verifier (`src/byte-machine/verify.sls`).** In `pass-names` (`:322`), add an
  arm resolving a pause/callback node's reason name against `(error-names m)`,
  mirroring the error-node arm at `:351-354` — `missing-error-declaration`, or a
  new `missing-pause-declaration` code **only if** the prototype shows the shared
  code muddies the diagnostic (the census cost of a new code is higher, §3).
  Confirm the reason stays out of `node-out-targets` (`:265`); the pause node's
  `zero-width-edges` arm (`:171`) returns only its `continuation`.
- **Normalizer + fingerprint (`src/byte-machine/private/normal-ir.sls`) — the seam
  the emitter reads through (§3.7).** `lower-machine` resolves the reason into the
  normalized pause state (`:552-555`) and callback state (`:627-635`) code/reason
  slots via `errcode`/`errreason` (`:310-317`), mirroring the error-node arm
  (`:547-550`). `encode-normal`'s pause arm (`:765`) and callback arm (`:823-840`)
  fold the reason into the fingerprint **under a presence guard** — reason bytes
  only when a reason is declared, so a reason-less machine's fingerprint does not
  move (criterion 1). Without this, two machines differing only in reason share a
  fingerprint but emit different bytes — the invariant `normal-ir-tests.sps:111`
  guards for error reasons and Pass 35/36 pins (`SchemeMutationSuite.cmake:476-483`).
- **Compiler (`src/byte-machine/compile.sls`).** Extend the errs-table reached-walk
  (`:575-606`) with a pause/callback arm, so a pause-only `(code . reason)` survives
  into `errs` (else the arm's `(vector-ref errs (index-of …))` raises at emit time,
  `:651-660`). The pause-node arm (`:285-287`) and callback pause arm (`:411-412`)
  emit the reason record (read from the normalized slots + `errs`, the same
  `byte-machine-make-parser-error/v1` shape the error arm builds at `:158`) into
  the outcome's error slot when the site declares one, else `#f`; the two span
  pause arms (`:447`, `:474`) stay `#f`. Bump the emitted ABI literal 6→7 (`:763`).
  Add `parser-result-pause` to `reserved-member-2` (`:53-73`), beside
  `parser-result-error`, or the reserved-drift lane fails (brief §5 trap 4).
- **Runtime (`src/byte-machine/runtime.sls`).** Add the `pause` element to
  `make-parser-result` (`:180`) via `case-lambda` (5-arg → `pause` `#f`; 6-arg →
  `pause` given — the tag is a constant); export and define `parser-result-pause`
  (length-guarded). Add a `pause-reason-of` helper (reads a pause/callback node's
  declared reason, builds the `parser-error`-shaped value from the resolved
  declaration, or `#f`). Fill it at the four reason-bearing interpreter pause arms
  (`:920` pause-node feed, `:965` callback feed, `:1246` pause-node finish, `:1283`
  callback finish). The span-callback pause arms (`:1003`, `:1033`, `:1327`,
  `:1353`) and the flush pause (`:762`) pass `#f` (design §3.4). Route feed-outcome
  slot 3 to the error/pause result slot by status at the two v2 boundaries —
  `parser-feed-v2!` (`:1101-1103`) and `parser-finish-v2!` (`:1204-1205`): error
  slot ← slot 3 when status `'error`, pause slot ← slot 3 when `'paused`, `#f`
  otherwise. Bump `current-abi-version` 6→7 (`:92`).

## 4. Census, drift, and doc surfaces (loud ratchets — named so the plan reaches them)

- **Diagnostic census (`test/common/diagnostic-census-tests.sps`).** The new
  verifier resolution site moves the census: re-pin the per-code count (`:119`
  `(missing-error-declaration 1)` → 2, or a new `(missing-pause-declaration 1)`
  row), the `make-diagnostic/declarations` site total (`:615-619`), and the
  layer-3 fixture (`:526-549`). If a new code is chosen, add its `code-fixtures`
  witness (a machine emitting it) and update the derived catalog
  `.reference/verifier-diagnostic-catalog.md` (checked at `:659-671` under
  `BYTE_MACHINE_REPO_ROOT`). Re-measure every literal; never predict it.
- **`verify-tests.sps`** — a resolution case parallel to the error-node one
  (`:95`).
- **ABI-6 sites beyond `compile-tests.sps:208`.** The whole ABI-payload-guard
  group in `runtime-tests.sps` constructs at the current version and moves 6→7:
  `:286`, `:289` (the v2 stub machines) plus the guard group's `:457`, `:462`,
  `:514`, `:534`, `:538` (several on continuation lines a single-line grep misses)
  — and the "superseded version is refused / current one accepted" case moves its
  refused version 5→6 and accepted 6→7 with its labels. (`:531`/`:581`'s `2`/`1`
  are deliberately-wrong-version tests; leave them.) Re-author the ABI-literal
  mutation pin `SchemeMutationSuite.cmake` (FIND `machine 6`, REPLACE `machine 5`,
  irritant 5 → FIND `machine 7`, REPLACE `machine 6`, irritant 6) and its comment.
- **Round-trip printer (`test/support/harness/byte-machine/test/machine-print.sls`).**
  `print-pause` (`:120`) and `print-callback` (`:141`) render the reason field, or
  a reason-bearing machine loses it on print↔reparse — and `machine-corrupt.sls`
  (which edits the printed datum) needs the printed reason before any
  reason-targeting corruption entry.
- **Reference docs (mechanism-describing; version/status docs are Slice ②).**
  `.reference/source-ir-and-builder.md` (`:112`, `:140` constructor signatures —
  the `§27:1692` "documents every constructor" artifact);
  `.reference/generated-code-integration-chez.md` (`:98-103` parser-result
  accessors + `parser-result-pause`; `:122` "ABI currently `5`" is ALREADY stale,
  → 7); the pause-semantics lines in `.reference/transition-and-cursor-semantics.md`
  and `.reference/callback-span-lifetime.md`. Append a `parser-result-pause`
  disposition to the parent plan's `§9.3` accessor call list (the
  `parser-state-name` precedent, appended not inlined — the line-citation append
  rule).

## 5. Tests and the seven goldens

- **`pause-machine.sls`** — extend with **two distinct declared reasons** (e.g. a
  reason on `p1` and a different reason on `pe`), so criterion 4 (resume + re-pause
  reports two different reasons) is by-value; keep a reason-less pause too so the
  "no existing machine changes" path is still exercised. If a callback-pause reason
  is proven in the prototype, add a small callback-pause fixture (or extend an
  existing callback machine) carrying its own reason.
- **`differential-pause-tests.sps`** — extend `rfields` (`:32-35`) with
  `(project-error (parser-result-pause r))`, so a reason divergence between lanes
  is a cross-lane failure; add the resume-and-re-pause-two-reasons case and, if
  applicable, the callback-pause reason case; assert by value that the error slot
  is `#f`, `status` is `'paused`, and `parser-lifecycle` is `paused-feed` /
  `paused-finish` (criterion 3, unchanged).
- **`pause-interpret-tests.sps`** — the interpreter absolute oracle for the reason
  (a walk-logic defect the two executors share is visible here).
- **`normal-ir-tests.sps`** — a case mirroring `:111` (two machines differing only
  in a pause reason produce different fingerprints) and `:116` (an unreferenced
  reason declaration does not reach the encoding).
- **`normal-ir-tests.sps` length pins** (`:61`, `:76`) are unaffected — the
  normalized-state vector keeps 11 slots; only slots 5/7's values change from `#f`.
- **Goldens.** Regenerate **all seven** (`generated-{accumulate,counted,http-version,http,keyword-table,one-byte,pause}.golden.sls`)
  to ABI 7 — every one embeds `(byte-machine-make-compiled-machine 6 …)` verbatim
  and is byte-compared, so all move on the literal. Assert each fingerprint is
  **unmoved** except the pause golden's, whose reason-bearing arm and (guarded)
  fingerprint change by construction. A fingerprint move on any of the other six is
  a slice bug, not a re-baseline.
- **`compile-tests.sps:208`** → ABI 7.
- **Size measurement (criterion 6).** A before/after: the pause proving machine's
  emitted bytes WITHOUT a reason (the v0.3.0 shape) vs WITH a reason, MEASURED
  through the real emitter, with the reproduce command beside it (AGENTS.md,
  [[scratch-fixture-measurements]]). **Recorded, not a committed lane** (design
  §3.6): unlike the keyword-table's 34× win the reason's cost is incidental (one
  `byte-machine-make-parser-error/v1` call in one arm), so it is recorded in the
  design §3.6 and the `CHANGELOG.md` `[0.4.0]` entry (Slice ②) rather than gated
  by a `unit.pause-size` lane. Measured 2026-09-14: 1825 → 1942 bytes (+117).

## 6. Mutation accounting (69/622 → re-measured)

- **Re-anchor the pause pins the shape change breaks** (AGENTS.md,
  [[reanchor-replaces-not-just-finds]] — grep REPLACEs too):
  `SchemeMutationSuite.cmake:3708-3710` ("feed pause arm parks current on the
  continuation") and `:3727-3730` ("EOF pause parks paused-finish") anchor on the
  6-arg `(make-parser-result 'paused … #f)` text; the Pass 35/36 pins (`:476-483`)
  anchor on the pause lower/encode/emit arms; the boundary rewrite touches the
  error-threading pins near `:3688`; the ABI-literal pin `:14004-14007` → 7/6/6.
  Re-scan after each edit; confirm with the self-validating
  `scheme-mutation.cmake.direct` lane.
- **New pins**, each witnessed in its own SPEC lane's program: the reason-read at
  the pause-node arm and at the callback arm (`unit.pause` / `differential.pause`);
  the **error/pause boundary routing** — a mutant routing the reason into the error
  slot for a pause must redden (this is brief §6's guard turned into a pin); the
  `pause-reason-of` present/absent direction; the **fingerprint reason-encode arm**
  (a mutant dropping the reason bytes must move a differ-in-reason fingerprint
  case, pinned on the fingerprint group it alone reddens, the M11 keyword-fold
  precedent); and the errs-table reached-walk arm (a mutant dropping the pause
  reason from `reached` makes the emit-time assertion fire — pin the signature).
- Recount `EXPECTED_MUTATIONS`/`EXPECTED_PASSES` from the manifest, never predict;
  run the WHOLE scheme mutation lane (a new exit path can disarm an old mutation,
  AGENTS.md) and confirm each new/changed pin is caught **for the reason it names**
  — filter for the failure signatures (`CMake Error`, `wrong reason`, `UNCAUGHT`,
  the exit status), never the "suite complete" line.

## 7. Exit and boundaries

**Criteria met (brief §4).** (1) `make-pause-node` takes an optional reason, a
pause without one unchanged; (2) a declared pause reports a `parser-error`-shaped
value in the pause slot; (3) `status` stays `'paused`, lifecycle rows unchanged;
(4) resume + re-pause reports two different reasons (by-value); (5) interpreter ≡
generated, ABI bumped 6→7 read out of the emitted text; (6) the before/after size
measurement recorded. `make test` green in both Chez modes; the scheme mutation
lane green with recounted totals; all seven goldens at ABI 7 with only the pause
golden's fingerprint moved.

**Deferred to Slice ② (the release).** The version surface to `0.4.0`, the
`CHANGELOG.md` `[0.4.0]` section, the release-ledger `release-version` +
`release-ledger-tests.sps` lockstep, `README.org` and the milestone-status
surfaces, and the annotated tag `v0.4.0`.

**Out of Milestone 12 (design "Explicitly out").** A reason on
span-data/span-complete callback pauses (needs a span-declaration field no consumer
wants); a mandatory reason; any change to `status` or the lifecycle rows.

**A dependency to confirm before committing fixtures** (design §3.4, review Low):
the consumer models its reason-bearing upgrade pause as a **pause node** (brief §7
asserts this). If it were a span-completion callback pause, the seven fixtures
would still get `#f` — confirm against the consumer grammar in the prototype.
