# 0015: Sequence lowering — ordinary dispatch prefix states, and an independently derived interpreter representation

Date: 2026-08-29
Status: accepted
Milestone: 3, Gate 0 (milestone-3-design.md §4.2)

## Context

Sequence dispatch is the sixth node kind in parent §10.6's closed set, and the
first Milestone 3 adds. §10.6:546, §17:957 and §19.2:1010 all say the compiler
lowers sequence alternatives into "resumable prefix states" without saying what a
prefix state *is* in normalized IR. Separately, §18:970 forbids the reference
interpreter from calling the normalizer or executing normalized IR, and §18:972
permits interpreter-private progress state inside a high-level source node — "such
as a sequence prefix" — but requires that representation be "derived independently
from the production normalizer".

These are one decision, not two. The interpreter≡generated differential is the
only mechanism that can catch incorrect sequence lowering (§18:970 says so
explicitly), and it can only do that if the two implementations are genuinely
independent. Deciding the normalized representation without simultaneously
deciding — and constraining — the interpreter's invites the natural refactor that
destroys the property: factoring "the shared prefix walker" into a common library.

## Decision

1. **A lowered prefix state is an ordinary normalized `dispatch` state.** No new
   state kind, no new encoding tag, no new emitter arm, and the encoding-format
   version byte is unchanged. A resumable byte-reading state is precisely what the
   shipped dispatch state already is, and the shipped need-input resume point
   therefore gives cross-feed resumability with no new mechanism.
2. **This is possible only because ambiguous terminal prefixes are rejected**
   (§10.6:544). That rejection guarantees every prefix state is either
   interior-with-children or a leaf, so none needs an "accept here" slot — which
   the shipped normalized state does not have. The rejection rule and this lowering
   are the same decision seen twice; changing either silently breaks the other.
3. **The reference interpreter represents "inside sequence *s* at prefix position
   *k*" as a compound `current` value.** It is derived independently of the
   normalizer, which is automatic rather than aspirational: `interpret.sls` imports
   no normalizer library, and this decision forbids introducing such an import or a
   shared prefix-walking helper for the purpose.
4. **Interpreter prefix state may not be closed over the compiled machine.** One
   compiled machine serves arbitrarily many parsers, so prefix progress lives in
   the parser's own `current`, never in a closure created at
   machine-construction time.
5. **A mid-sequence feed boundary returns `need-input`, never `paused`.** The two
   have different lifecycle consequences: `need-input` leaves the lifecycle
   `ready` for a direct further feed, while `paused` sets `paused-feed` and makes a
   further `parser-feed!` a contract violation until `parser-resume!`.
6. **A mid-sequence pause cannot arise, and no protocol for one is designed.**
   Every source edge target is a *declared* node name, and prefix positions have no
   declared names, so no source construct can route a pause into the middle of a
   sequence.

## Consequences

- **No `runtime.sls` change and no `/v3` ABI.** The runtime treats `current` as
  fully opaque — it never tests it, only stores it or hands it to the executor —
  and `parser-reset!` restores it from the entry slot, so a compound value flows
  through feed, `need-input`, finish and reset untouched. The `/v2` contract
  mentions no node kind; decision 0012 item 3 established that new behaviour rides
  on new status symbols and new state ids, not a new record.
- The interpreter's node lookup and node-kind dispatch must learn to destructure a
  compound `current`; today they match node names by identity and raise a contract
  violation on anything else. That is the whole of the interpreter change.
- **EOF discards prefix position, and that is correct.** §12.4:727 makes every
  lowered prefix state inherit the source sequence state's EOF edge, and decision
  0011 lets that chain terminate at a pause. At that point `current` parks on the
  pause's continuation and the prefix position is gone. EOF never returns to bytes
  — from `finish-ready` a `parser-feed!` is a contract violation — so nothing can
  observe the loss. An implementation must not assume byte matching resumes
  afterwards.
- Because the interpreter and the normalizer implement prefix matching twice, a
  divergence between them is a *test result*, not a merge conflict. Reviewers
  should treat a proposal to share the walker as a change to this decision.
