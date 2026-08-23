# AGENTS.md

## Project guidelines

### Architecture & portability

* Use the functional core / imperative shell pattern
* Follow the 12 Factor Apps philosophy
* Project targets Chez Scheme (R6RS) only — see docs/decisions/0005-chez-only.md
* Project should be portable across macos (darwin), linux, and windows
* Project should be portable across amd64 and arm64

### Layout, process & libraries

* Plans live in `/docs/plans`, decision records in `/docs/decisions`
* Add entries to `CHANGELOG.md` for each release
* Makefile should have a `help` command which lists all of the make commands.
* Libraries are R6RS `.sls`; libraries and programs contain their own code —
  no shared include bodies (docs/decisions/0006-inline-libraries.md). R6RS
  forbids assigning an exported variable — reach mutable state through
  procedures.

### Testing & mutation discipline

* **Use TDD / test-driven development**
* **Give every decision a mutation its spec catches.**
  A test that passes whether the code is right or wrong is worse than no test.
  Every decision in a module gets a mutation that breaks it, and the owning
  specification must notice. Seed an output variable before asserting it is empty.
* **Treat an uncaught mutation as a test to strengthen, never to loosen.**
  An uncaught mutation is a finding about the tests, not a reason to loosen it.
  Find something that can witness the decision before concluding nothing can —
  "this cannot be tested" is a claim to demonstrate, and an experiment that shows
  nothing is inconclusive, not negative. `EXPECT_SURVIVES` is for the genuinely
  unwitnessable, with a written reason; never to reach green.
* **After adding an exit path, re-run the whole mutation suite — a new exit can silently disarm a mutation.**
  Adding a new way for the program to exit can silently disarm an existing
  mutation. Slice 5a's reachability guard gave a *mutated* `harness-begin` its
  own route to status 3, so that mutation's baseline and mutant both landed on 3
  — still reported caught, no longer discriminating anything. After adding an
  exit path, re-run the whole mutation suite, not just the new lanes, and check
  each affected pass's baseline and mutant still differ for the reason the
  mutation names. A green suite will not tell you.
* **Gate a lane on every tool it uses, not only on its own backend.**
  A registration that depends on a tool other than its own backend is gated on
  that tool, not on the backend. A lane whose expectation is computed by a
  Chez process needs `if(BYTE_MACHINE_CHEZ_EXECUTABLE)` even when Chez is not
  its own backend; its own no-runtime skip fires on a missing instance of its
  own backend and says nothing about a missing Chez. Slice 5a shipped this bug
  twice, on a host where both were installed and neither review could see it
  without configuring a one-runtime build.
* **Prefer a mutation caught by a failed comparison over one caught by a raise.**
  Prefer the mutation form caught by a failed comparison over one caught by a
  raise. A raise-based catch depends on where the mutant happens to crash rather
  than on the assertion naming the decision. Before accepting one, try the
  opposite constant — slice 4's `(if #t` left the predicate's own case passing
  and made a later case error, where `(if #f` fails that case's `check-equal`
  outright and tests the same decision.
* **Before deleting a mutation, ask what its REPLACE still changes and whether any input can reach it.**
  A mutation is not dead just because its witnesses are. The Chez-only cut first
  deleted "a refused search list does not stop registration" as unwitnessable
  when its two Gambit fixtures went; its REPLACE still narrowed a two-clause
  guard, and the surviving clause — unknown-mode at registration — was reachable
  through a route nothing yet used (a lane NAME carrying one backend's mode
  while BACKEND names another). Before deleting a mutation, ask what its REPLACE
  still changes in the surviving tree and whether any input can reach it.
* **Keep a pass's provenance manifest off the file it mutates, unless self-reference is the declared mechanism.**
  A mutation pass's provenance manifest must not cover the file the pass
  mutates — unless self-reference is the declared mechanism. The 5b remainder's
  W9 pass as planned fingerprinted the same file every mutation in its group
  edited, so any edit tripped a generic mismatch: one mutation was "caught"
  without discriminating its decision, and the pass's declared survivor was
  reached and caught, falsifying its written reason — proven by a control (an
  inert comment edit flipped the lane identically). The corrected split is the
  rule: witness content decisions under a manifest that excludes the mutated
  file, and use a deliberately self-referential manifest only as its own named
  mechanism — it is exactly what makes an exit-path constant witnessable,
  because the mutation stales its own manifest and drives the run down the
  failure path whose constant it changed (SchemeMutationSuite passes 30/31).

### Documentation & record discipline

* **Re-measure against the shipped artifact before a number enters a doc or record.**
  A measurement earns a place in a design doc or decision record only once it has
  been re-taken against the shipped artifact. Numbers from a pre-design scratch
  fixture describe the fixture: slice 4 recorded a mutant as "exits 0", true of a
  bare driver with no harness and false of the shipped harness-integrated lane,
  and it propagated into five documents before review caught it. Decision 0002
  models the handling — re-measure, then state what was measured against what.
* **Sweep a retired concept's whole vocabulary, not just its name.**
  A removal gate that greps the departed name is an inventory check, not a
  vocabulary check. The Chez-only cut's `rg -i gambit` cleared every file while
  "both runtimes", "two wrappers", and "parity proof" survived in shared-body
  headers — live comments asserting a contract the plan had retired. Removing a
  concept means sweeping its vocabulary too; the chez-only plan's §6 carries the
  executable form of that sweep.
* **Correct a stale instruction in place; annotate a stale record — never reword evidence.**
  A stale sentence is corrected or annotated according to what it does, not
  which file it sits in. A **record** — a measurement, a finding, a decision
  record's Context — gets an amendment note, because a record edited to agree
  with a later decision stops being evidence of anything. An **instruction** —
  a work order, an exit criterion, a Deliver or Scope list, a deliverable
  entry, or a comment in live code saying what the code is for — gets corrected
  in place, because leaving a false one is not preserving evidence, it is
  leaving a landmine, and what it used to say is in git. Three corollaries the
  close-out paid for: a record *document* still contains instruction sentences
  (the milestone plan's header pledges it keeps all its Gambit content, and its
  §7 deliverable entries still had to be corrected — so the pledge was scoped
  to name which sections it covers); a sentence that was **never true** is
  a third case, annotated rather than fixed when it is load-bearing
  (docs/decisions/0001-toolchain-discovery.md's claim of a CI that has never
  existed); and an instruction changes category when its work closes — a
  completed work-order item, or the exit criterion of a milestone that has just
  closed, has become the record of what was asked, so it gets a dated
  disposition and is never reworded to match what shipped, because rewording it
  edits the bar to fit the result (milestone-0-portability-spike.md's §8 items
  1–5 and its §12 criteria were dispositioned, not corrected, for exactly that
  reason). The demonstrated defect: milestone-0-portability-spike.md's
  work-order item 6 instructed an exit — "byte-identical output across
  implementations" — that decision 0005 had made impossible, and it survived
  two further slices — the include collapse (PR #8) and the 5b remainder
  (PR #10), each with its own plan, review, and merge — before anyone read it
  against the tree. Status lines are instructions too: a slice that closes a milestone is
  not done until the milestone plan, the parent plan, and CHANGELOG.md all say
  it closed.
* **Before writing "met" or "moot", find the thing in the tree.**
  A disposition is a claim, and "met" is the one easiest to get wrong. The rule
  above stops you editing a bar down to fit the result; its mirror is asserting
  the result reached the bar, and the Milestone 0 close-out shipped that twice in
  one branch. A block dispositioning the milestone plan's §8 said items 1-5 were
  "each met under the contract of its day — two runtimes, two wrappers, four
  lanes", when item 5 demanded four green lanes that never existed together: the
  two Gambit compiled lanes were cancelled with slice 5c before they were built,
  and `chez.aot` landed three days after Gambit was gone. The same branch called
  §5's decision D7 "moot" while the CMake modules, presets, Makefile targets, and
  probe it decided were all shipped and in force — declaring a live contract dead.
  Before writing "met" or "moot", find the thing in the tree. Then check what the
  document already says elsewhere: both defects contradicted two other sentences
  in their own file (§7 D5's dated note, and §12's disposition (4)).
* **Re-read every early artifact against HEAD before the final review, and note what changed in a dated amendment.**
  A record written in a slice's first task goes stale against that slice's own
  later tasks. The close-out wrote decision 0007 in task 1 and swept both
  governing plans in tasks 3 and 4; 0007 was never reconciled, and shipped
  quoting two sentences with zero live hits, an exit criterion its own row P12
  had reworded, and — the Critical — "the four deferred cells" citing the very
  entry row S12 had corrected to two, which is the number Milestone 1 scopes CI
  against. The fix is not to rewrite the record as though it were written at the
  end: the tree it was decided against is its evidence. State that tree, then
  disclose in a dated note what the change it authorised has since altered. And
  re-read every early artifact against HEAD *before* the final review rather than
  discovering it there.

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
