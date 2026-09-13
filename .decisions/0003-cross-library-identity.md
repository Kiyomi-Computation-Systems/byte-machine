# 0003: A second library imports the owner, and a mutation is what enforces it

Date: 2026-08-17
Status: accepted
Milestone: 0, slice 4

Superseded: 2026-08-18 by [0006](./0006-inline-libraries.md) — the one-owner
rule and its import-vs-include mutation are retired with the include
mechanism. The identity lane itself survives, witnessed by 0006's replacement
mutation (a consumer inlining duplicate definitions instead of importing the
owner).

## Context

Parent plan [byte-machine-implementation-plan.md](../.plans/byte-machine-implementation-plan.md)
§7.2 requires that each shared body be included by exactly one implementation
library per runtime, and that other libraries import that owner rather than
including the body again. Its stated reason is that a second include gives
tagged-vector type tags and allocation-free singletons a second identity.

Slice 3 built the first owner and chose the representation that makes a
violation visible — a freshly allocated tag and marker, never symbols — but
could not witness one, because a single library cannot. Slice 4 adds the second
library and the test that can fail. See
[the slice-4 design](../.plans/milestone-0-slice-4-cross-library-identity.md).

## Measurements

Measured 2026-08-17, Darwin 25.5.0 arm64, Chez 10.4.1, Gambit 4.9.8, against the
real Chez launcher and the shipped placeholder body.

- **A shared body can name another library's exports as free identifiers, on
  both runtimes.** `placeholder-consumer.scm` defines only `consume` and refers
  to `placeholder?`, `placeholder-value` and `placeholder-marker`, which its
  wrapper's import list supplies. Both runtimes resolve them, from a working
  directory containing neither body. This is the mechanism Milestone 1 runs on
  and nothing in the tree exercised it before this slice.

- **The double-include defect is invisible to every lane except the one built
  to catch it.** With the consumer wrapper's import replaced by an `include`
  of the owner's body, both runtimes answer both identity claims wrongly.
  Nothing raises: the identity lane catches it through ordinary
  `check`/`check-equal` failures and exits 1 on both. The six
  `byte-machine.portability.placeholder-cwd-*` lanes stay green, because they
  import only the owner. This is §7.2's "both looking correct in isolation" in
  its literal form.

- **Chez and Gambit disagree about a library body that redefines an imported
  name.** Given a wrapper that both imports `(byte-machine placeholder)` and
  includes that library's body, Chez refuses to construct the library:
  `Exception: multiple definitions for make-placeholder and other identifiers in
  body`. Gambit constructs it and answers every question correctly. This record
  states the measurement, not a rule — see Consequences.

## Decision

1. **The consumer library imports the owner and is given its own shared body.**
   A bodiless re-exporter would satisfy deliverable D3 as written and leave the
   free-identifier mechanism unproved until Milestone 1 needed it.

2. **§7.2's "exactly one owner per body" is enforced by mutation, not by a
   configure-time guard.** Passes 26 and 27 of
   `test/support/cmake/SchemeMutationSuite.cmake` replace each consumer
   wrapper's import with an include and require the identity lane to fail. A
   mutation proves the defect is caught; a text scan would prove only that it is
   discouraged, and a commented-out include satisfies one. Slice 3 §3.1 rejected
   the guard and its reason has not changed.

3. **The mutation replaces the import; it never adds to it.** Forced by the
   third measurement: the augmenting variant fails on Chez for a reason
   unrelated to identity, which the runner's caught-for-the-declared-reason
   check rejects, and does not fail on Gambit at all.

## Consequences

- **The deferred one-owner guard is recorded here, where ownership is the
  subject.** It reopens when a shared body exists with no lane registered
  against it — at that point a missing or duplicated wrapper stops being caught
  at import, which is what currently makes the guard unnecessary. Slice 3
  recorded the same deferral in a document about the include *mechanism*;
  whoever adds Milestone 1's second library over an existing body will be
  reasoning about ownership and would not have looked there.

- **The identity test does not catch a second independent owner.** It catches a
  *consumer* that double-includes. A second owner wrapper that nothing imports
  alongside the first stays invisible, by the same slice-3 decision.

- **What Gambit does with a body that redefines an imported name is an open
  question, not a finding.** The measurement establishes that the construction
  does not fail; a follow-up probe using a deliberately wrong body produced
  results this slice could not reconcile into a single rule within its budget,
  and an inconclusive experiment is not a negative result. Milestone 1 builds
  several libraries over several bodies with real import graphs, and a runtime
  that silently accepts a name collision the other rejects is a portability
  hazard with no diagnostic. It needs its own measurement.

- **Identity under compiled lanes is untested.** Everything here is source mode,
  where separate instantiation is modelled rather than real. Slice 5 registers
  these same two programs against the Chez AOT, Gambit `.o1`, and `gsc -exe`
  lanes, which is where the risk is genuine.

- All measurements are single-host, single-version: one macOS arm64 machine,
  Chez 10.4.1, Gambit 4.9.8. Nothing here is a claim about any other release or
  Tier 1 platform.
