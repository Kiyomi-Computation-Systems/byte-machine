# 0021: EOF-chain classification is a multi-successor search — one DFS, worst case over all paths

Date: 2026-08-31
Status: accepted
Milestone: 4, Gate 0 (milestone-4-design.md §4.4)

## Context

Decided against the shipped tree at commit `a942327` (Milestone 3 close). Every
`verify.sls` and `runtime.sls` citation below is **pre-slice**: Slice ②'s first
task rewrites the function this record is about, so each names the construct as
well as the line.

`eof-terminal` (`verify.sls:356-385`) is structurally single-successor. Every
non-terminal arm tail-calls `loop` on exactly **one** target, with `seen` a flat
list threaded down that one path: the pause arm `(loop (pause-node-continuation
n) (cons name seen))` at `:366`, the byte-dispatch arm `(if (symbol? t) (loop t
(cons name seen)) 'default-error)` at `:379-381`, and the sequence arm at
`:382-384`, whose `if` (`:384`) happens to coincide with the byte-dispatch arm's
(`:381`) though the accessor at `:383` differs from `:380`'s
(`verify.sls:377-378`). `(memq name seen)` at `:360` is both the cycle test and
the whole of the walk's memory.

Parent §10.6:582, on the field branch: "Every possible result must have an
explicit target." A field branch carries two (`true-target`, `false-target` —
§9.1:305-306) and a field action carries `next` plus `error` (§9.1:301), `error`
being a node name and `#f` only when the operation cannot fail (design §4.3).
Neither shape has a representation in a walk that recurses on one target. Both
kinds are zero-width (§10.6:550, §11.4:652), so both can sit on an EOF chain —
which decision 0011 item 3 made a *chain* rather than a direct resolution
precisely so that later zero-width kinds could.

**The failure is silent, and silence on this surface is reported as a clean
verdict.** `eof-terminal`'s final arm is `(else 'unknown)` (`:385`), and both
callers discard that answer: the §16.2:909 chain walk's `(case (eof-terminal m
t) ...)` ends `(else '())` (`:417-424`), and the byte-reachable-pause walk's
identical `case` ends the same way (`:449-456`). Point a dispatch node's
`eof-target` at a node of an unhandled kind and the analysis stops there and
reports nothing — `verify` answers ok `#t`, zero diagnostics, for a chain it
never classified.

Nothing downstream catches that. `parser-finish-op!` says so in its own header:
"No local cycle guard: termination relies on the verifier's
eof-zero-progress-cycle/eof-reachable-stop checks having already rejected
non-terminating and stop-terminating EOF chains" (`runtime.sls:275-280`), and
the generated finish path `parser-finish-v2!` (`:260-272`) runs `exec` once and
does not re-verify. Termination in both lanes is a claim this analysis makes.

The tree has already measured what that costs, in a note kept deliberately at
`verify.sls:307-318`: a sequence node whose mismatch edge reexecuted into itself
"verified with ok #t and zero diagnostics", and feeding it one non-matching byte
"did not return: reproduced under a timeout in both the interpreted lane
(parser-feed-op!'s `(loop pos)`, runtime.sls:200) and the generated lane
(compile.sls's emitted `(loop pos <target> off)` fallback), since neither has a
local cycle guard and both rely on this REPORT set." One node kind earlier, that
is this record's failure mode exactly: an unfed kind-dispatch arm, a clean
verdict, a hang in both lanes.

Finally, §16.2:909 already states the obligation over paths rather than over *a*
path — "every EOF path must reach finish or error after finitely many explicit
pauses" — so what follows is a reading of the requirement, not an extension of
it.

## Decision

1. **`eof-terminal` classifies a chain by searching every successor of every
   node it reaches, and the verdict is the worst case over all paths.** Any path
   reaching a stop yields `eof-reachable-stop`; any path that cycles yields
   `cycle`, which outranks it, because a cycle is the non-termination neither
   runtime loop guards against (`parser-finish-op!`'s loop at `runtime.sls:283`,
   whose header at `:275-280` says so; the generated lane's own chain, `:257`)
   and must survive the join. Only that one relation — `cycle` outranks
   `eof-reachable-stop` — is pinned in the source for determinism even where it
   is not yet observable; every other verdict falls through
   `pass-eof-execution`'s `case` to no diagnostic regardless of order, so this
   decision leaves the rest unfixed. `pass-eof-execution` `case`s on
   `eof-terminal`'s **single** answer (`verify.sls:417-424`, `:449-456`), so a
   node yields at most one EOF diagnostic however many arms its chain has, and
   the join's choice *is* the diagnostic the user sees.
2. **The walk is one depth-first traversal carrying two structures, and that
   settles the join.** A **path stack**: a back edge to a node on the current
   path is a `cycle`, and only that is. A **global visited set**: a node whose
   exploration has *completed* is not re-explored, its verdict is reused. Two
   paths converging is not a cycle, and re-walking the join makes a branchy
   chain exponential. Reuse is sound because any cycle through a node consists
   of nodes reachable from it, so it is found while that node is itself on the
   path — a completed node's verdict is therefore path-independent, and
   preserving that invariant is part of this decision. The two naive
   alternatives §4.4 first floated are two different algorithms with two
   different bugs, which is why neither is left to the implementing slice.
   Making `seen` per-path keeps one structure doing both jobs and pays 2^k
   paths for k branch nodes on a chain, re-classifying every join once per path
   into it. Letting one shared `seen` tolerate re-visits — that is, keeping it
   as the cycle test — reports `cycle` for a diamond that merely re-converges,
   a false rejection of a legal machine. "Is this node on the path I am on
   now" and "have I classified this node already" are different questions, and
   one list cannot answer both.
3. **`'unknown` is eliminated by the rewrite, not joined into the lattice.** The
   rewrite gives every §10.6 node kind `ir.sls` can construct its own arm, and
   `'unknown` leaves the answer set rather than becoming its least element. A
   value that both callers' `case` maps to `(else '())` is not a lattice bottom,
   it is the silence above; a residual arm may not reintroduce one.
4. **The rewrite is Slice ②'s first task, executed before either new node kind
   exists**, as a behaviour-preserving refactor whose oracle is *no diagnostic
   on any existing fixture changed*. Run with neither kind in `ir.sls`, so
   nothing confounds the refactor with new-arm behaviour — the `else` arms
   accept an unhandled kind silently, so a rewrite landing in the same commit
   as a new kind has no clean oracle, since a changed diagnostic could be
   either. Gate: `ctest --preset pr` and `--preset release` green, zero
   diagnostic-code or diagnostic-count edits in `test/common/verify-tests.sps`,
   and the three `normal-ir-tests.sps` IR fingerprints and all three committed
   goldens byte-identical.
   The gate above is silent on the artifact this rewrite most certainly touches:
   `test/support/cmake/SchemeMutationSuite.cmake` pins six mutation anchors to
   `eof-terminal`'s body or its two call sites — `:3532` (`(if (memq name seen)
   'cycle`), the pause arm at `:3603`, the sequence arm plus `(else 'unknown)`
   at `:4156`, and the call sites at `:3708`, `:3902`, `:4287`. The rewrite
   deletes the first three `FIND`s outright, since `(memq name seen)` is exactly
   what Decision 2 replaces, and `test/support/cmake/MutationRunner.cmake:59`
   asserts `SITES` exactly, so a stale `FIND` is a hard failure at declaration,
   not a silent skip; the suite is registered `LABELS unit`, so it already runs
   under both `pr` and `release`, not release alone. Re-anchoring any of the six
   is a re-measurement of that mutant's failure signature against the rewritten
   source, not a text edit, and the sweep runs in both directions: a re-anchored
   mutant is also checked against the mutant it replaces. Added to the gate:
   all six anchors re-measured and green (or carrying a recorded
   `EXPECT_SURVIVES`) under both presets.
5. **At §16.2:908's and :909's four filter sites, the two zero-width kinds
   follow the *pause* precedent and integer accumulate follows the *dispatch*
   precedent** (design §4.6). The unconditional source filters `(or
   (byte-dispatch-node? n) (sequence-dispatch-node? n))` at `verify.sls:400`
   (:908) and `:414` (:909) are **not** extended for field action or field
   branch; the byte-reachability-gated blocks at `:436-445` and `:446-458` are,
   each as a sibling block beside the pause block rather than by widening
   `(pause-node? n)` at `:438` and `:448`. Decision 0011's reasoning — recorded
   in the tree at `verify.sls:387-390`, "an eof-only-reachable pause legally
   continues into a finish node (decision 0011); a byte-reachable one must not"
   — applies verbatim to any zero-width kind. Integer accumulate reads input and
   joins the two unconditional filters instead, in Slice ③.

## Consequences

- **Rejects the alternative of forbidding field-action and field-branch nodes on
  EOF chains.** Decision 0011 item 3 already declined an "eof-target must
  resolve directly to a terminal" restriction so that intermediate nodes could
  sit on an EOF chain; forbidding an entire node kind there would re-impose that
  restriction for two kinds specifically, and the rejected alternative supplies
  no justification of its own for singling them out. A machine that, at EOF,
  branches on whether a length field was ever set is a legitimate and obvious
  use of that permission, and the branch cannot be resolved statically in its
  place, since field values depend on consumed input.
- **This extends decision 0011's analysis without changing any of its rules, and
  0011 needs no dated amendment.** Its item 3 names "zero-width
  action/callback/span nodes on the EOF path" as the future its chaining was
  general for; its item 4's three checks keep their wording, their codes
  (`eof-reachable-stop`, `eof-zero-progress-cycle`, `non-eof-into-finish`) and
  their byte-reachability/eof-reachability split. Every machine expressible
  before this record classifies identically after it — that is item 4's oracle.
  0011 fixed the rules, not the algorithm implementing them, so there is
  nothing in its text this supersedes. Contrast §4.1, which does owe decision
  0012 a dated amendment: it retires a name 0012 fixed.
- **Obliges** a `verify-tests.sps` fixture that distinguishes the two structures
  rather than merely exercising a branch: a diamond that must verify clean and a
  back edge that must report `eof-zero-progress-cycle`. A test that only walks a
  branching chain passes under both rejected algorithms.
- **Obliges** the field-action and field-branch arms to report their full
  successor set — `next` plus `error` when it is a symbol, both branch targets —
  in `node-out-targets` and `reexec-targets` as well, since `pass-reachability`,
  `pass-names`, `byte-reached` and `pass-zero-progress` all walk those two and
  would otherwise disagree with this walk about what a successor is.
- **Does not touch** `node-eof-target` (`verify.sls:82-85`), whose `(else #f)`
  is the right answer for two kinds that read no input, and adds **no** runtime
  cycle guard in either lane: termination stays a verifier obligation, exactly
  as `runtime.sls:275-280` states it. The generated finish path continues not to
  re-verify.
- **Does not settle** the other eleven silently-failing kind-dispatch sites the
  design's §7 census counts inside `verify.sls`. This record closes one of them,
  the one whose silence is reported as a clean verdict twice over; the rest keep
  whatever disposition their own slices give them.
