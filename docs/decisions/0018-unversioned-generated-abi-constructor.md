# 0018: One unversioned generated-ABI constructor, with the version check first

Date: 2026-08-31
Status: accepted
Milestone: 4, Gate 0 (milestone-4-design.md §4.1)

## Context

Decided against the shipped tree at commit `a942327`, where Milestones 0-3 are
closed. The only later commit, `0a267de`, adds this milestone's design document
and touches no source; every `file:line` below was re-read at that tree.

Decision 0012 item 1 is the precedent this record breaks: a change to the
runtime↔generated seam ships as a new `byte-machine-make-compiled-machine/vN`
plus a bump of `current-abi-version`, itself following decision 0010 item 4's
"extends by a `/v2` constructor rather than an arity break". Milestone 4 moves
that seam again — the ABI payload must carry field initials — so the precedent
produces a `/v3`. The measurements below say that family has stopped paying
for itself.

**`/v1` refuses the version it is named for.** Its guard reads

    (unless (and (integer? abi-version) (= abi-version current-abi-version))

(`runtime.sls:51`), and `current-abi-version` is 2 (`runtime.sls:49`). A stale
generated file declaring ABI 1 — the only shape a `/v1` name describes — is
therefore rejected *by* `/v1`. It is already a tombstone, not a compatibility
path; the whole of what decision 0012 item 1 kept it for is that the rejection
is a clean assertion rather than an unbound-identifier import failure.

**The two guards disagree about where the number comes from.** `/v2` tests a
literal instead: `(unless (and (integer? abi-version) (= abi-version 2))`
(`runtime.sls:66`). They agree today only because the constant is 2, and they
fail in opposite directions the moment it moves. `/v2` goes on accepting 2 — a
hole that admits exactly the stale files decision 0012 item 1 added it to
refuse, and one that fails late: such an object loads, `exec` has the same
arity, nothing raises. `/v1` inverts instead, accepting only the new live
number and nothing else, so the one name whose contract is "the old shape" would
admit the newest one and hand a `/v2`-shaped `exec` to the four-argument `feed`
path.

**`/v1` has two call sites in the whole tree, both in one test program.**
`runtime-tests.sps:195` builds the stub machine for the `/v1` harness group, and
`runtime-tests.sps:245` is the refusal case. The first has to declare `2` to get
past the guard, and the comment above it says so
(`runtime-tests.sps:179-184`: "It declares abi 2 -- the current ABI version --
because /v1's guard checks (= abi current-abi-version)"). Nothing in `src/`
calls it, and none of the three goldens do: `render-machine` emits
`(byte-machine-make-compiled-machine/v2 2 …` (`compile.sls:164`).

**The `'v1` arm of `make-parser` is dead in production.** The variant `cond` at
`runtime.sls:112-123` reaches its `else` — the `'v1` arm at `:120-123` — only
for a compiled machine built by the `/v1` constructor (`runtime.sls:56`), which
is reachable only past the guard above. The emitter has emitted `/v2` since
Milestone 2, and a file emitted before that declares 1 and is refused, so no
generated library can reach the arm. Its only witness is the hand-built stub.

**The version *check* is nonetheless load-bearing here specifically.** Chez
prefers a compiled object over source and staleness is transitive across
imports; without the object-guard pair "a stale compiled object is silently
preferred over the source a 'source' lane claims to run"
(`milestone-0-slice-2-implementation-plan.md:590`). Every differential program
emits a library, `(load genfile)`s it and `eval`s the binding against the
*resident* runtime instance (`differential-http-version-tests.sps:48-53`), so a
stale generated object meeting a newer runtime is reachable inside this
repository's own build, not only across releases. What that argument justifies
is a check, not a name.

**Unversioned names are already the norm on this surface.**
`reserved-member-2` (`compile.sls:44-52`), the hand-maintained mirror of the
runtime's exports asserted set-equal to `environment-symbols` by
`reserved-drift-tests.sps:32-40`, carries twenty symbols, seventeen of which
have no version suffix. Nothing in the mirror or its drift guard depends on a
reserved name being versioned.

## Decision

1. **One unversioned `byte-machine-make-compiled-machine`, whose first action is
   the `(= abi-version current-abi-version)` check.** The check precedes every
   other guard and every field read, so a version mismatch is reported before
   any part of the payload is interpreted — which is what makes the payload safe
   to grow. The `/vN` family stops growing here: Milestones 5 and 6 plausibly
   move this seam again, and each `/vN` costs a dead-in-production variant arm,
   a permanent export, a `reserved-member-2` entry and an accessor pair.

2. **The growable payload is one quoted vector, not a rest-arg.** A rest-arg
   would let the payload grow *without* a version bump, and the version check is
   the only thing standing between a stale object and silent wrong answers; the
   vector keeps growth and the check coupled. It renders as `(quote #())` today,
   introducing no new callable identifier into the emitted body — the reason the
   shipped arms say `(quote error)` rather than calling anything
   (`generated-one-byte.golden.sls:17`). Member 0 is the field initials, empty
   until Slice ①b. This is §19.1:996's "immutable field/callback/debug
   metadata", carried positionally.

3. **`current-abi-version` goes from 2 to 3 (`runtime.sls:49`), and the
   emitter's literal moves in the same commit.** The number is duplicated by
   construction: `compile.sls` does not import the runtime
   (`compile.sls:14-17`), so the emitted `…/v2 2` literal (`compile.sls:164`)
   and `current-abi-version` are two independent constants with no static guard
   between them. Nothing but the differential lanes catches a disagreement, so
   they move together or not at all.

4. **`/v1` and `/v2` stay exported and are rewritten to refuse every version —
   in text distinct from each other and from the live guard.** Refusing *every*
   version, rather than the one they are named for, is what the measurements
   above require: a tombstone that still accepts a number is a hole. The textual
   distinctness is a hard constraint, not style. All mutations run at the
   default `SITES`, which "defaults to 1 and is asserted exactly"
   (`MutationRunner.cmake:58-59`) and fails loudly with "pattern occurs N times
   … expected N" (`MutationRunner.cmake:342-345`); AGENTS.md:147 records that
   `SITES` fails in *both* directions, so new code duplicating a pinned line
   breaks the suite at declaration. The `/v1` guard is pinned verbatim —
   `FIND [[(unless (and (integer? abi-version) (= abi-version
   current-abi-version))]]` at `SchemeMutationSuite.cmake:2544`, under LABEL
   "runtime: a mismatched generated-runtime ABI version is accepted" — and the
   `/v2` guard at `:2725` under "runtime: a mismatched /v2 ABI version is
   accepted". The suite already records distinctness as the reason those two
   differ (`SchemeMutationSuite.cmake:2719-2720`). Writing the live guard as a
   copy of the `/v1` text takes that `FIND` from one site to two, and the third
   guard would make it three.

5. **`reserved-member-2` gains the unversioned name and keeps both tombstones,
   in the same commit as the export change.** The mirror is hand-maintained
   (`compile.sls:44-52`) and `reserved-drift-tests.sps:32-40` asserts it equal
   to the runtime's live `environment-symbols`, so an export change that skips
   the mirror reddens the drift lanes rather than degrading quietly. That is
   decision 0012 item 4's rule, applied unchanged.

## Consequences

- **This amends decision 0012 item 1.** Its constant-bump half survives intact;
  its `/vN`-name half does not. Per AGENTS.md, 0012 gets a dated amendment note
  rather than a rewrite — the tree it was decided against is its evidence.
- **Parent §9.5:442 gains a Milestone 4 parenthetical**, on the precedent of the
  Milestone 2 parenthetical already in that line. §9.5:444 is *not* amended: its
  three requirements for a pre-1.0 ABI change are "a generated-ABI version bump,
  deterministic regeneration, and a changelog entry", and the version **number**
  bump is the requirement — it says nothing about a versioned binding name.
  Deterministic regeneration and the CHANGELOG entry bind the implementing slice
  exactly as written.
- **Decision 0010 item 4's purpose is kept and its mechanism replaced.** The
  seam still extends without an arity break; it now extends through the payload
  vector under one name instead of through a new versioned constructor. Item 4's
  other clause — the named `feed-outcome` record — is untouched.
- **The three goldens move**, each on the constructor line that embeds the name,
  the ABI literal and the IR fingerprint:
  `test/fixtures/generated-one-byte.golden.sls:20`,
  `test/fixtures/generated-pause.golden.sls:33`, and
  `test/fixtures/generated-http-version.golden.sls:85`. The same call is
  asserted as a literal string at one more site outside `test/fixtures/`,
  `test/common/compile-tests.sps:165`, which moves with them.
- **The runtime's `'v1` executor path becomes unconstructable**, and its
  disposition is owed by the slice that lands this, not by this record. Once
  `/v1` refuses every version, nothing can build a `'v1`-variant compiled
  machine, so `make-parser`'s `'v1` arm (`runtime.sls:120-123`),
  `parser-feed!`'s `else` (`runtime.sls:157`), `parser-feed-v1!`
  (`runtime.sls:205`) and `parser-finish!`'s raising `v1` arm
  (`runtime.sls:253`) lose their only witness — with them two shipped
  mutations, named by LABEL because the lines are stale on arrival: "runtime: a
  v1 machine is driven down the op path" and "runtime: the v1 result status is
  hard-wired to stopped". An arm no public API can reach cannot be witnessed
  and would ship dead owing an `EXPECT_SURVIVES`.
- **Two other pinned mutations re-anchor; neither loses its witness.** The
  `/v1` constructor's guard is a separate site from the executor path above:
  its `FIND` (`SchemeMutationSuite.cmake:2544`, LABEL "runtime: a mismatched
  generated-runtime ABI version is accepted") targets the guard at
  `runtime.sls:51`, still reachable because `/v1` stays exported. The `/v2`
  guard's `FIND` (`SchemeMutationSuite.cmake:2725`, LABEL "runtime: a
  mismatched /v2 ABI version is accepted") likewise targets `runtime.sls:66`.
  Item 4's tombstone rewrite deletes both guard texts outright, so both
  `FIND`s drop to zero occurrences — `MutationRunner.cmake:344-346`'s "update
  the mutation rather than deleting it" case, not `EXPECT_SURVIVES`. Refusing
  *every* version still refuses abi 1, so `runtime-tests.sps:243-245` (`/v1`)
  and `runtime-tests.sps:305-306` (`/v2`) keep raising and keep catching a
  mutant that stops raising. Neither is discharged by its witness surviving:
  left un-updated, each fails loudly at declaration rather than at a test.
- **This is distinct from the benchmark-gated `feed-outcome` `/v2`** reserved by
  decision 0010's Consequences and its Slice-B amendment, which stays gated on
  §23 evidence. That `/v2` is a change to the outcome *record*; this record
  touches only the compiled-machine constructor, and `feed-outcome` keeps its
  five slots and its `/v1` constructor.
- **Deliberately not touched.** Decision 0010 item 5's coded
  `generated-runtime-abi-mismatch` condition stays deferred: the collapsed
  constructor still raises `assertion-violation`. The canonical *encoding*
  format version is a different seam with a different lineage and has its own
  Gate 0 record. §20:1042's embedded generator version is measured unmet and
  stays unmet (`rg` for a generator version across `src/` and `test/common/`
  returns nothing) — the payload vector is its eventual home, but
  half-embedding it is worse than none.
