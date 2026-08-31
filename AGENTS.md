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
* **A fix that makes two lanes agree can disarm the test that caught them.**
  When a differential shows the interpreter and the generated lane disagreeing,
  the repair has two ways to be wrong: they can agree on the wrong value, and
  they can be made to agree by making the difference *unobservable*. Milestone 4
  Gate 0 shipped the second and caught it one review later: keying the generated
  lane's position-kind initialization on `finish?` made both lanes report `eof`
  at the default-EOF arm — and made that arm's per-site `(quote eof)` literal
  observationally identical to the inherited loop variable, so no differential
  and no mutation could tell them apart. A pin written from that record would
  have survived. After any cross-lane fix ask both questions: which value do they
  now agree on, and does the spec's own principle pick it? And can the mutant
  still be told from the baseline?

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
* **A mutation's witnessing test lives in its own SPEC lane's program.**
  A mutation is only witnessed by tests that run in the lane named by its
  `SPEC`. The runtime's SPEC lane (`byte-machine.unit.runtime.chez.source`)
  drives `runtime.sls` through hand-built op stubs, not the interpreter — so a
  runtime mutation whose only witness lives in `interpret-tests.sps` (a
  different lane) is uncaught. Slice ②b-1 shipped exactly this until an uncaught
  mutation surfaced it. When you add a mutation, put its witness in that
  mutation's SPEC-lane program.
* **A pin that matches text printed on every failing run asserts nothing.**
  `EXPECT_OUTPUT_MATCHES` is an *unanchored* regex over the spec command's
  stdout+stderr (`MutationRunner.cmake`), and two lines print on essentially
  every failing run: the FAIL-CONTEXT line (`backend=`, `mode=`, `os=`,
  `architecture=`, `machine-type=`, `artifacts=`, plus the
  `BYTE_MACHINE_TEST_NAME`/`BYTE_MACHINE_TEST_TMPDIR` values, which make
  `scheme`, `mutation`, `harness`, `cmake`, `direct` unconditional) and the
  summary line (`status=`, `cases=`, `checks=`, `failures=`). A pin that is a
  substring of either is the bare nonzero-exit catch this file forbids, wearing
  a signature. Slice ③ shipped `"ack"`, which hid inside `backend=`; a suite-wide
  audit then found four more. Pin a case-name tail plus the check label, so the
  pin resolves to one `(case, check)` pair — the FAIL grammar is
  `FAIL <group>.<case>: <what> -- <detail>`. A pin can also match another
  mutant's `-- <detail>` tail or a *group* name, so uniqueness among check
  labels is not sufficient; CMake `MATCHES` is not literal, so no metacharacters
  (`\\.` for a dot). The discriminator is the *pair*
  (`EXPECT_STATUS`, `EXPECT_OUTPUT_MATCHES`): mutations sharing a pin but
  declaring different statuses are still separated.
* **Judge a pin against the other mutants in its lane, not by reading it.**
  Static inspection cannot see a collision; re-judging each pin through
  `byte_machine_mutation_verdict` against every *other* mutation's captured
  output can. That pass is also what sorts the residue, which has three kinds
  and not two: **under-anchored** (the broad mutant emits a line the narrow one
  does not — a tighter pin exists), **subsumed** (the narrow mutant's whole
  failure set is a subset — no pin can separate them), and **separable but
  deliberately declined** (the sets differ, so a pin *could* discriminate, but
  only by embedding a value with a maintenance cost). A subset test reports the
  third as clean, so classifying by it alone records a deliberate trade as "no
  issue" — or worse, as "unfixable". Compare whole FAIL **records**, not lines:
  runtime details are multi-line condition dumps, and a line-level comparison
  manufactures false separability. Rule out under-anchoring by exhaustion
  ("no record it emits is unique to it"), not by inspection — only the former is
  checkable. Run the subset test *before* the fix pass, or you spend the cycle
  first and learn it was unfixable second.
* **"Subsumed" is a claim about the SPEC, not about the decision — and the relation is whole-set, not per-record.**
  The taxonomy above sorts residue into three buckets, and the sorting itself has
  two failure modes this repository has now hit both of. First, checking the
  wrong relation: "is each of my records shared with *someone*?" is not "is my
  whole record set inside *one* sibling's?" Milestone 3 Slice ②'s `:909`
  sequence-arm mutation was documented as genuinely subsumed when its two records
  were each shared with a *different* mutant and the intersection of the
  containing sets was empty — a pin requiring **both records together**
  separated it. Second, running the subset test and stopping: a subset test
  reports the third bucket as though it were the second, so four residues were
  filed "genuinely subsumed" without anyone attempting a fix, and three closed
  the moment someone did.
  A mutant with **zero unique FAIL records across the lane** is a signal that the
  specification is under-specified, not that its pin is unfixable. Two remedies
  are shipped here and both close this shape: an **attribution check** — assert
  the diagnostic that must be *absent* on a well-formed fixture, instead of one
  "accepted" boolean — and **count-don't-witness** — one fixture carrying both
  things a walk can reach, asserting the count, so each way of breaking the
  enumeration reports a different number. Only what survives an actual attempt
  may be called subsumed, and it must be recorded with the measurement.
  Re-sweep the whole pass after **each** fix, not once at the end: adding a
  *check* widens pins just as adding a mutation does (a new `no unreachable-node`
  check contained a bare pin as a substring and broke a pin sixteen mutations
  above it), and a first attempt can collide with a third mutant — one fix here
  had to be redesigned after its initial shape tied with a sibling.
* **`SITES` fails in BOTH directions — new code that DUPLICATES a pinned line breaks it too.**
  The familiar failure is "found 0, expected 1": an edit changed a `FIND`'s text.
  The one that gets missed is **"pattern occurs 2 times ... expected 1"**, when a
  *newly added* function duplicates a line some shipped mutation pins. Milestone 3
  Slice ③ drafted `pass-sequence-ambiguity` as a structural clone of
  `pass-overlap`'s `node-overlaps` — same `let outer`/`let inner` skeleton, same
  `ss`/`rest`/`out` bindings — and three shipped mutations pin **single lines** of
  that skeleton, so the clone took each from one occurrence to two and would have
  hard-failed the suite three times over, for mutations the slice never touched.
  Caught in planning, not by CI. The fix is to **rename the new function's
  bindings**, never to widen three shipped `FIND`s: cheaper, and it leaves the
  shipped pins alone. Copying a neighbouring pass's skeleton is the natural move
  here and is exactly the trap. To check, lex every `byte_machine_mutation(` block,
  keep those whose `FILE` is the file you touched, and count each `FIND` in the
  post-edit source against its declared `SITES` — counting by **FILE**, not by
  SPEC, because a SPEC census cannot see a second pass mutating the same file
  under a different lane (Pass 37 mutates `verify.sls` under the
  identifier-repertoire SPEC, invisible to a census of `verify.rejections`).

* **A pin is only ever verified against the mutants that existed when it was measured.**
  This is the same shape as the exit-path rule above: adding mutations to a lane
  can widen an existing pin's collision set, silently. When a branch adds
  mutations to lanes another branch has audited, that branch must re-measure
  after the merge — and the obligation belongs in the tree, named by mutation
  LABEL rather than line number, not in a session transcript.
* **Re-judge a pin sweep in BOTH directions — re-anchoring the incumbent is half of it.**
  The rule above says adding a mutation widens existing pins' collision sets. It
  reads one-directional and is not: you must also check whether an *existing*
  mutant matches the pin you are *adding*. Milestone 3 Slice ① Task 4 measured
  the pre-existing `normal-ir: dispatch cases are not sorted ascending by byte`
  mutant's output and re-anchored that pin — and never checked the reverse, so
  its own new pin was matched by that same sibling. Both failed the identical
  `(case, check)` pair, leaving decision 0014's headline claim pinned to a
  signature two mutations produce. Six per-task sweeps on that branch found
  three real collisions; the whole-branch review found the seventh *in the
  sweeps themselves*. Run a control on the merge base — a pass that is
  collision-free there and colliding at HEAD is the branch's doing, and that
  distinguishes an introduced defect from inherited debt. Record a genuinely
  subsumed residue **in the tree**, beside the pin, named by mutation LABEL: the
  session ledger is git-ignored, so an obligation left there has not been
  recorded.
* **A completion sentinel must read the observed value, and the loop over the loops needs one too.**
  No suite here declares an expected case or check count — `harness-summary`
  reports only what ran — so an exhaustive loop that never executes passes
  vacuously, and a sentinel is how that is closed. A sentinel computed from the
  *test's own expectation* closes nothing. Milestone 3 Slice ①'s `hits` counter
  incremented inside the `(memv b accepted)` branch, so it equalled the class
  size for every possible behaviour of the machine under test and could only
  fail if a fixture's own data held a duplicate — a fixture-integrity check
  wearing a behavioural sentinel's label, with a comment claiming it closed the
  "matcher accepts nothing" mode. Derive counters from what the system under
  test returned. And apply the rule one level up: the outer `for-each` over five
  fixtures had no sentinel at all, so dropping a fixture would have silently
  shrunk two groups and left the lane green. Assert the collection's own length
  where you iterate one. Note what found the vacuous sentinel: a mutation pin
  that never fired. Mutation testing catching a bad test is the argument for it.
* **A measurement that cannot fail visibly needs a control, not a re-read.**
  Slice ③'s close-out produced two plausible-and-wrong counts from two different
  methods, each returning a number that gave no reason to distrust it. Reading
  the output again would not have caught either; a deliberate control did — run
  the measurement a second way and compare, or construct the case the number
  claims is impossible. Two traps this repo's own mutation suite sets, both from
  one root cause (its comments contain CMake syntax and its bracket arguments
  contain unbalanced parens, so neither construct is recognisable without lexing
  the other): balancing parens from `byte_machine_mutation(` truncates the body
  and reports a false *absent*; counting `EXPECT_STATUS` textually picks it up
  inside `#` comments and reports a false *declared*. Only a single
  left-to-right lexer skipping both is sound.
* **A plan's verification step whose expected result is prose is not a check — state a literal, a count, or "no output".**
  Milestone 3's Gate 0 plan wrote expectations of the form "the first prints the
  record, the §19.2 clause, and the design's §4.2 references, all agreeing." Two
  of those steps named the design document as a source of hits when that file
  contained none — its placeholder `0014–0017` holds "0014" and "0017" as
  substrings but not "0015"/"0016" — and both implementers reported the
  expectation matched, because the command did print hits from the *other* paths
  in the same invocation. The shipped content was right only because the
  reviewers re-derived it independently. This is the mutation rule one level up:
  a nonzero exit is not proof, and neither is output that merely resembles a
  description. Give every mechanical step an expected result that can fail — an
  exact literal, an exact count, or "no output / exit 1" — and when a step needs
  judgement ("read the surrounding lines and confirm the record's claim"), say so
  and separate it, so the mechanical half keeps a hard pass/fail.

### Documentation & record discipline

* **Re-measure against the shipped artifact before a number enters a doc or record.**
  A measurement earns a place in a design doc or decision record only once it has
  been re-taken against the shipped artifact. Numbers from a pre-design scratch
  fixture describe the fixture: slice 4 recorded a mutant as "exits 0", true of a
  bare driver with no harness and false of the shipped harness-integrated lane,
  and it propagated into five documents before review caught it. Decision 0002
  models the handling — re-measure, then state what was measured against what.
* **A decision and the reason it states fail independently — check the reason
  against the tree, not against the document.**
  A design call can be correct, well-argued and agreed while the sentence
  supporting it describes behaviour the code does not have, and the false reason
  is what the next slice acts on. Milestone 4's Gate 0 shipped three in five
  records, two of them originating in the design and propagated by the record
  that transcribed it: decision 0020 justified its `error`-slot rule by claiming
  the verifier rejects a spurious target as unreachable, when `pass-reachability`
  is a purely *syntactic* walk that reaches it and flags nothing (the rule was
  right; the true argument was the opposite and stronger); decision 0021
  justified permitting field nodes on EOF chains by a requirement §21 never
  states; decision 0022 cited §12.7's truncation row for a path where nothing is
  truncated. Put the instruction in the reviewer's prompt verbatim — *check what
  this claims the code or the spec DOES against the code and the spec, not
  against the prose* — because the task-scoped reviews that lacked it caught
  none of the three, and the one that carried it caught all three. When a finding
  lands, repair the reason without weakening the decision, then check whether the
  same sentence sits upstream in the design.

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
  with a later decision stops being evidence of anything. The note is half the
  job: a reader who arrives at a numbered item by citation never scrolls to the
  foot of the file, so the **top** of the record must also say a later note
  reached back into it, and the amended item must say so at the site.
  `docs/decisions/README.md` states that convention and the boundary it must
  not cross — a pointer routes, it never restates, because one that summarises
  the correction hands a reader the later decision's conclusion without the
  evidence the note carries, which is this bullet's rewrite arriving by the
  back door. Decision 0010 item 4 read "extends by a `/v2` constructor" with
  the note replacing that mechanism forty-seven lines below and three like it
  already in the file, and nothing at the top of the record saying so.
  An **instruction** —
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
  against the tree. Status lines are instructions too, and this project states
  its status in more places than any one step remembers: a slice that closes a
  milestone is not done until the milestone plan, the parent plan,
  `CHANGELOG.md`'s `[Unreleased]` preamble, that milestone's own design
  document, **and `README.org`'s status paragraph** all say it closed. The
  README is the one no step names, so its drift is unbounded rather than one
  slice deep. It still read "No public API exists yet. The repository currently
  holds the project plans and the build and discovery layer that the
  implementation will be developed against" — accurate at Milestone 0 — after
  Milestones 0, 1 and 2 had all closed, while the other four surfaces were
  current, each brought up to date by the slice that closed the work. A document
  no step names is a document nobody updates. Corrected in PR #24, whose sweep
  found two more stale claims sitting beside it: a CMake-version parenthetical
  written before CI existed, and a documentation list pointing only at the
  Milestone 0 plan. When a status line is the subject of the work, read all five
  before mirroring any one of them — that sweep found the parent plan's Status
  line stale on every ref (`git for-each-ref`) and the CHANGELOG preamble
  current only on an unmerged branch, both contrary to how they had been
  described.
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
* **Keep a count next to the qualifier that makes it true.**
  A number in a record is scoped by the words around it, and the scope is what
  gets dropped when the number is repeated somewhere else — at which point a
  true claim reads as a false one, or as a correction to a claim that was never
  wrong. Slice ③'s close-out hit this three times in one exchange: "no pin can
  separate them" restated without "no pin *worth its maintenance cost*"; a
  subsumption result restated without "over the reproducible lanes I actually
  swept"; and "the four pre-existing *one-byte-fingerprint* pins" answered with
  "five", which is the size of the cross-matching family — a different number
  from a different question, and the qualifier is the only thing that
  distinguishes them. Each was caught by someone checking the tree rather than
  the sentence. When two numbers answer different questions about the same
  thing, state both with their questions attached; when you restate someone
  else's number, carry its scope with it or do not carry the number.

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
