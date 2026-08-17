# AGENTS.md

## Project guidelines

* Use the functional core / imperative shell pattern
* Follow the 12 Factor Apps philosophy
* Use TDD / test-driven development
* A test that passes whether the code is right or wrong is worse than no test.
  Every decision in a module gets a mutation that breaks it, and the owning
  specification must notice. Seed an output variable before asserting it is empty.
* An uncaught mutation is a finding about the tests, not a reason to loosen it.
  Find something that can witness the decision before concluding nothing can —
  "this cannot be tested" is a claim to demonstrate, and an experiment that shows
  nothing is inconclusive, not negative. `EXPECT_SURVIVES` is for the genuinely
  unwitnessable, with a written reason; never to reach green.
* Shared `.scm` bodies use only the R6RS/R7RS common subset and never name Chez
  or Gambit; runtime-specific code lives only in the thin `.sls`/`.sld` wrappers.
  R6RS forbids assigning an exported variable — reach mutable state through
  procedures.
* Project should be portable across Chez and Gambit Scheme
* Project should be portable across macos (darwin), linux, and windows
* Project should be portable across amd64 and arm64
* Plans live in `/docs/plans`, decision records in `/docs/decisions`
* Add entries to `CHANGELOG.md` for each release

## Closing ritual

Run this when a branch's work is complete and reviewed. It is a ritual because
each step is easy to skip and each one left undone costs someone else later.

1. **Squash merge the PR.** One commit per branch on `main`. The granular
   history — the review trail, the fixes, the plan corrections they forced —
   stays readable in the PR.
2. **Catch up local `main`.** Fetch and fast-forward, so the next branch starts
   from what was actually merged rather than from where this one began.
3. **Clean up branches.** Delete the merged branch locally and on the remote.
   A branch list that still shows finished work makes the unfinished work
   harder to see.
4. **Reflect.** Put what was learned where it will be found again, choosing the
   destination by who needs it: durable facts and corrections into memory,
   project standards into this file, and anything the code should say about
   itself into a comment at the site. A finding recorded only in a session
   transcript has not been recorded.
