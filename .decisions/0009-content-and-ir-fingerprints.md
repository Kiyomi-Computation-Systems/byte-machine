# 0009: Two fingerprints, named apart — content fingerprint and IR fingerprint

Date: 2026-08-23
Status: accepted
Milestone: 1, Gate 0 (milestone-1-design.md §3.2)

## Context

The harness already ships a fingerprint: `(byte-machine test fingerprint)`, a
polynomial rolling hash mod 2^61-1 over a lane's manifest text, used for
build-provenance (decisions 0004, 0006). The parent plan's §20 introduces a
second, unrelated fingerprint — over the canonical normalized IR, permitted to
be 64-bit FNV-1a — embedded in emitted output and used for determinism
comparison. One word names two different objects over two different inputs.
Milestone 1 introduces the second, so the ambiguity becomes live now.

## Decision

1. **The shipped harness hash is the "content fingerprint" (a.k.a. manifest
   fingerprint).** It answers "is the declared manifest text unchanged and read
   identically?" It is provenance, not IR identity. Its library name
   `(byte-machine test fingerprint)` is unchanged.
2. **§20's hash is the "IR fingerprint".** It is computed over the canonical
   normalized IR and embedded in emitted output; it is the object compared in
   the D6 determinism checks. Phase 3 introduces it.
3. **Every site names which it means.** From Milestone 1 onward, prose, exports,
   and comments say "content fingerprint" or "IR fingerprint", never a bare
   "fingerprint", wherever both could be meant.

## Consequences

- Phase 3 introduces `(byte-machine ...)` code and tests for the IR fingerprint
  under the name "IR fingerprint"; it must not overload the harness's content
  fingerprint names.
- §20 of the parent plan is annotated to use "IR fingerprint" explicitly.
- No shipped code is renamed by this record; it fixes vocabulary before the
  second fingerprint exists.
