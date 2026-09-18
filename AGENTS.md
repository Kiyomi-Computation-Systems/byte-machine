# AGENTS.md

## Project guidelines

### Architecture & portability

* Use the functional core / imperative shell pattern
* Follow the 12 Factor Apps philosophy
* Project targets Chez Scheme (R6RS) only — see .decisions/0005-chez-only.md
* Project should be portable across macos (darwin), linux, and windows
* Project should be portable across amd64 and arm64

### Layout, process & libraries

* Internal working documents live in hidden top-level directories — plans in
  `/.plans`, decision records in `/.decisions`, the v0.1 reference set in
  `/.reference`. `/docs` is reserved for **public** documentation only (it holds
  none yet), keeping the published surface separate from the development record.
* Add entries to `CHANGELOG.md` for each release
* Makefile should have a `help` command which lists all of the make commands.
* Libraries are R6RS `.sls`; libraries and programs contain their own code —
  no shared include bodies (.decisions/0006-inline-libraries.md). R6RS
  forbids assigning an exported variable — reach mutable state through
  procedures.
* **A test needing a narrow public surface widened imports from the private
  library instead.** `graph.sls`'s header states that reading a built machine
  back is deliberately not part of the construction surface. Slice ⓪'s kind ×
  position matrix needed the nine node-kind predicates to assert each table row
  is the kind it is keyed by, and the cheap move was to export them from
  `graph.sls` — trading a documented contract for a test's convenience, where
  the export then reads to the next author as a supported API. It imports from
  `(byte-machine private ir)` instead: the test reaches inside knowingly, and
  the public narrowness stays true. Widen a public surface when a *user* needs
  it, never when only a test does.

### Testing & mutation discipline

* **Use TDD / test-driven development**
* **CI is one Linux job, run on demand, and its Chez build is cached.** On
  2026-09-07 the month's GitHub Actions budget was gone: a macOS job (billed at
  ten times a Linux minute) and a Linux job that built Chez from source ran on
  every push to every PR and on every merge, about sixty billed minutes a run.
  The macOS job is gone — Apple silicon is the platform every slice is measured
  on locally, with the `release` preset and the mutation lane, before it merges
  — and the Linux job runs only when a PR carries the `ci` label (a later push
  does not re-run: re-label, or `gh workflow run ci.yml --ref <branch>`, when
  the branch is final) and on every push to `main`. `.github/workflows/ci.yml`'s
  header is the rule, and its steps say when the Chez cache must be discarded.
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
* **An argument that a test CANNOT catch something must name both operands of
  its comparison.**
  Milestone 5 Slice ①a's position drift row shipped with a comment arguing it was
  blind under the mutation suite: the census reads the staged tree, so a mutation
  deleting an edge role deletes it from the code *and* from the set the test
  derives. The premise is true and the conclusion is backwards — the derived set
  is compared against a mapping **declared in the test file**, and a mutation
  rewrites only the file its own `FILE` names, so the mutated verifier meets an
  unmutated mapping and the row goes red. The slice had argued a real gap into
  existence and documented it as unclosable; the review closed it with a one-line
  pin. Before writing that a check is blind, name what it compares against and
  say which side the mutation reaches.
* **A scope claim inherits the scope of the measurement behind it.**
  The same slice wrote "the ONLY witness to the emitted signature anywhere in the
  tree" in three places. The measurement behind it had searched the **mutation
  declarations** only; the four committed goldens carry the same line and the
  determinism lanes compare them byte for byte. This is the novelty rule with the
  failure named: the widening happens in the retelling, not in the measuring.
  Carry the search's own boundary into the sentence — "the only assertion naming
  it as text", "the only witness in this SPEC lane" — and a later reader can
  check the claim against the search that produced it.
* **A plan that schedules a red intermediate commit is the thing that is wrong.**
  Slice ①a's plan split the ABI version bump, the `exec` widening and the payload
  growth into three tasks, then told Task 1 the tree would be "deliberately
  inconsistent" until Task 3 while Task 2 required the full suite green. Both
  cannot hold: the goldens regenerate once, so the lanes stay red until every
  half of the change has landed. The standing rule is that tests pass before every
  commit — when a plan conflicts with it, the plan is what gets corrected, and
  the tasks ship as one commit.
* **Count how many cases a mutant fails, and how differently — a mutant that
  crashes on unrelated inputs pins nothing.**
  A pin is attributable only if the cases that fail are the ones its decision
  reaches. Slice ⓪b's "reads only the first out-target" mutation was written as
  `(car (node-out-edges n))`, which raises on every node with *no* out-edges:
  109 of 116 cases failed with the identical `Exception in car`, including the
  one the pin's `EXPECT_OUTPUT_MATCHES` regex anchored on. The pin was green
  and measured nothing — the decision it names (first target versus all of
  them) was never exercised by the record that satisfied it. Re-shaped to guard
  the empty case (`(if (null? es) '() (list (car es)))`) so the mutant runs
  everywhere the baseline does, then re-pinned on a comparison record. After
  writing any mutation, read how many cases it fails and whether they fail
  *identically*: a uniform failure across most of the suite is a crash, not a
  discrimination.
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
* **Re-anchor a mutation's REPLACE with its FIND, or the mutant changes two things and the pin proves neither.**
  Re-anchoring is usually described as fixing the `FIND`, and that is the half
  the suite reports: a stale `FIND` fails loudly at declaration. A stale
  `REPLACE` fails at nothing. It still applies, the mutant still exits nonzero,
  and the pin still matches — but the mutant now differs from the baseline in
  **two** ways, so the failure it produces no longer isolates the decision the
  mutation names. Measured here twice in one slice: a re-anchored `FIND` of
  `parser-finish-op!`'s error arm left its `REPLACE` at the pre-slice text, so
  the mutant dropped the store *and* reverted the error value; and a new
  mutation's `REPLACE` was written as a no-op, which shipped `UNCAUGHT` and said
  so. After re-anchoring, read the `FIND` and the `REPLACE` **together** and ask
  what single decision separates them. A swap pair — where each mutation's
  `REPLACE` is the other's `FIND` — must move in lockstep for the same reason.
  Milestone 7 Slice ① measured a third shape a FIND-movement census cannot see: a
  pin whose `FIND` did **not** move — so a re-anchoring pass keyed on which FINDs
  went stale never re-examined it — but whose `REPLACE` named a construct the slice
  **re-contracted**. When the slice renamed `reaches-self?`→`self-cycle`, made
  `eof-terminal` answer a `(verdict path)` pair and `reach-from` return a
  `(name . parent)` alist, two such pins broke: `pass 4`'s `REPLACE` called
  `(reach-from …)` for its old list-of-names return, and arm 5's `REPLACE`
  returned a bare `'default-error` where the walk now needs `(verdict 'default-error
  path)`. Both were caught only by the lane's own "wrong reason" guard, and both
  `got`s were unchanged once the `REPLACE` matched the new contract. So when a
  slice renames or re-contracts a construct, grep every pin's `REPLACE` (and `FIND`)
  for that construct across **all** pins, not only the pins whose `FIND` moved.

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
  A third failure mode, added after Milestone 4 Slice ①b: **a UNION is inside
  neither set it unions.** Dropping a pass from `verify-machine`'s `append` emits
  exactly the union of its two arms' records, and that was filed "subsumed, it
  owns no record of its own" — but the relation is "inside *one* sibling's", and
  a union is inside neither, so it was separable all along by the same
  both-records conjunction the `:909` case already ships. The check is
  mechanical: compute the subset relation in **both** directions against every
  sibling, and only the direction that actually holds is subsumption. Note the
  asymmetry it leaves — once the union mutation is written, each ARM becomes a
  subset of it, which is subsumption **by construction** (the union mutant is
  strictly more permissive on every machine, so no fixture can redden an arm
  while leaving it green). That kind is genuinely closed rather than
  under-specified: there is nothing to separate, not merely nothing found. Keep
  the arm mutations anyway when they name distinct decisions — the cost is
  attribution, not detection — and record which kind you have.
  Re-sweep the whole pass after **each** fix, not once at the end: adding a
  *check* widens pins just as adding a mutation does (a new `no unreachable-node`
  check contained a bare pin as a substring and broke a pin sixteen mutations
  above it), and a first attempt can collide with a third mutant — one fix here
  had to be redesigned after its initial shape tied with a sibling.
* **A measurement written into prose goes stale when its fixture changes, and nothing checks prose.**
  A number in a comment, a plan or a commit message describes the tree *at the
  moment it was taken*; change the fixture and the sentence stays. Milestone 4
  Slice ①b declined a mutation as subsumed because it "reddens twenty-odd records
  across five unrelated groups" — true of a two-field fixture, and a third field
  was added **three steps later in the same task**, to separate a different pin,
  without re-measuring the paragraph. Actual: three records in one group, and the
  subsumption was false. The same slice shipped an `errs`-table fix whose own
  regression case could not see the defect it named, and a decision record that
  called the property "measured closed" while it was still false. Before citing
  your own earlier number, re-run the measurement; when you change a fixture,
  grep the file for prose describing it; and **state the command that produced a
  number beside the number**, so the next reader can re-run it instead of
  trusting it.
* **A correction is a record too. Read the whole block and the sites it cites before writing one.**
  Slice ①b measured five colliding pin pairs, compared that against a heading
  reading "SUBSUMED, four pairs", and wrote a dated correction saying the file
  was one short and that no separating attempt existed. Six lines below that
  heading the file already read "the four subsumed pairs listed above, **plus**
  arm 6 < arm 1", a later block listed all five by name, and arm 6's own pin
  carried a *measured* attempt. The heading counted one bucket at one audit
  moment. What was actually wrong was in a different file — a prior slice's plan.
  Name precisely which artifact is wrong; they are not interchangeable. Keep the
  retraction rather than deleting it, because the failure is the instructive part.
* **RETIRING a mutation is the one edit a clean sweep cannot see, and "another
  fixture already witnesses it" is a coverage claim, not a collision claim.**
  The sweep judges the pins that exist against the mutants that exist; delete a
  pin and it reports on one fewer of each, silently, and every remaining pin
  still resolves. Milestone 7 Slice ⓪'s plan retired "a sequence node's
  eof-target does not feed reachability" on the ground that a new group's
  sequence-dispatch pair witnessed its decision — and that pair answers the same
  with and without the arm, because the node the pair builds has its eof-target
  on a node the byte walk already reached. The suite was green, the sweep was
  clean, and the decision had no mutant naming it: the two survivors that
  reddened its case both name the BYTE half and emit `got 2` where the retired
  one emitted `got 1`. Before retiring a mutation on a replacement witness,
  STAGE THE DELETION and measure — which mutants still redden the case the
  retiring one owned, and does the replacement fixture separate the arm at all?
  A decision that a refactor RELOCATES is re-anchored onto its new reader; only
  one a later fix makes unobservable is retired. Both endings need the
  measurement, and only one of them needs a tombstone.
* **When one mutant WIDENS a relation and another DELETES the emission that
  reads it, the second contains the first by construction — and the separating
  fixture carries one of each kind.**
  A walk-widening mutant reports strictly fewer findings; an emission-deleting
  mutant reports none. So every check whose expectation is a finding of that
  code reddens under both, with the identical `got`, and the widening mutant has
  ZERO unique records — measured, not guessed, and it looks exactly like
  subsumption you have to accept. It is not: build one machine carrying an
  instance that is positive under BOTH relations (here a node with no in-edge at
  all) beside one positive under only the narrow relation. The widening mutant
  then still reports the first and the emission mutant reports nothing, so the
  two `got` lists differ and one record separates them. This is
  count-don't-witness with the two things named: the fixture must contain an
  instance each mutant treats differently, not two instances of the same kind.

* **A whole-pass sweep re-judges the pins that EXIST; it cannot notice a decision no pin names.**
  A clean sweep answers "do my pins still identify their own mutants", never
  "is every decision here pinned" — and it reads like the second. Milestone 4
  Slice ② widened the normalized state vector from eight slots to eleven and
  missed `seq-state`, the literal building every sequence-dispatch node's state;
  those shipped three slots short of the layout the file declares, and survived
  the task's own six mutations, a 36-pin/1260-pair sweep reporting **zero**
  collisions, and all 92 lanes. Invisible because those states carry kind
  `dispatch` and every reader of the new slots is kind-guarded. The plan and the
  commit both said "six state literals move in this commit"; there are **eight**,
  and the eighth is the one that was missed — a count describing the work done
  rather than the work owed. When a change has a CENSUS shape ("every X gains
  Y"), the check must be **total over X**, enumerated mechanically, with a
  sentinel reading the observed count — never a case per X you thought of.
* **A differential compares two implementations only where a fixture reaches both — and the operand must separate a member from its SIBLINGS.**
  Milestone 4 writes seven field operations and seven predicates twice on purpose,
  because a shared helper would make a lowering bug invisible to the
  interpreter≡generated differential. Slice ② shipped with **six of the fourteen
  in no fixture at all**; measured, inverting the emitter's `mask-none` alone left
  all 92 lanes at status 0. The subtler half: with `mask-all 12` on a field
  holding 12, an implementation computing `mask-any` answers *correctly*, so the
  case passed on the wrong predicate and the mutation survived — the operand had
  to become 14, where 12 carries some mask bits but not all. For any closed
  enumeration implemented more than once, census which members a fixture actually
  reaches before claiming coverage, then per member ask which sibling answers the
  same on that operand. Assert EXPECTED values, not only that the lanes agree:
  two lanes wrong the same way agree.

* **The generated lane's EOF span/callback behaviour IS the emitted feed arm, so
  it cannot differ from the feed side without moving the golden — and an upstream
  "suggested shape" is checked against the named invariants, not adopted.**
  `parser-finish-v2!` runs the *emitted* `exec` with `finish?` and cursor 0, so the
  generated lane's EOF span-end is the same emitted arm it runs mid-feed, calling
  the same runtime step. Milestone 10 (empty-span observability, decision 0042)
  arrived with a consumer brief proposing "the flush and the EOF arm get a separate
  suppress-only entry point; emitted code only reaches the span-end path, so it
  needs no edit" — true of the flush (a runtime-only path in `parser-feed!`) and
  FALSE of the EOF arm: routing EOF to a suppress-only path made the two lanes
  disagree, and forcing them to agree by suppressing would have required a
  `finish?` branch inside the emitted text, moving the HTTP determinism golden and
  re-anchoring a `compile.sls` mutation — the very cost the milestone was avoiding.
  Keeping the emitted text byte-identical therefore FORCED the EOF span-end to
  share the feed side's behaviour. The follow-on trap the whole-branch review
  caught: with EOF on the shared step, an empty span carried from a feed into
  finish fired only when its last feed happened to start at 0 (the per-feed
  re-anchor had zeroed its mark) — a slicing-dependent *presence* of a callback,
  not just a fragment boundary §14:837 permits to vary; the fix was to re-anchor
  the mark to 0 at the finish boundary too, so every empty span is announced
  uniformly. Two reversals, each because a plausible shape met an invariant it had
  not been checked against. When a change proposal comes from outside the codebase
  (a consumer brief, a review suggestion), name the invariants it rests on — here
  the finish executor path and the mark's coordinate system — and verify the shape
  against them before adopting it; the brief itself said to.

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
* **A shared fixture machine grown across slices emits a valid SUPERSET trace and moves its terminal WITHOUT failing fast — so an earlier slice's absolute assertions that pinned the OLD terminal, offset, or full trace go silently STALE, not red.**
  Growing one shared machine re-calibrates earlier lanes exactly as adding a mutant re-calibrates earlier pins: the earlier assertion still runs, still passes, and now describes a machine that no longer exists.
  `test/support/harness/byte-machine/test/http-machine.sls` is ONE machine built through `(byte-machine graph)` and extended in place each M8 slice (its header names the plan: ② replaces the request-line stop with the header section, ③ adds the fixed body, ④ the chunked body). Two kinds of assertion rot without erroring. **(a) THE TERMINAL:** Slice ① ended the request line at a `reqline-done` stop, so `byte-machine.unit.http-request-line` pinned a *stopped* terminal at the end of the 21-byte canonical `"GET /index HTTP/1.1\r\n"`. Slice ② replaced that stop with the header section, so the same input now reaches `need-input` at `header-line-start` — and because `src/` is untouched every slice (`git diff --stat main..HEAD -- src/` prints nothing) the request-line event prefix is emitted byte-for-byte unchanged and ONLY the terminal status/offset moved. The old "stopped at offset 21" expectation would have gone quietly WRONG rather than failing; it was hand-changed to `need-input`, and the same lane's split invariant re-driven from the 21-byte line's 20 interior cuts to the 23-byte no-body message's 22 (the two extra cuts are the appended empty-line CRLF). **(b) THE RECORDER:** each lane keeps its OWN trace recorder that binds a FIXED callback list, and a callback that fires while UNBOUND is a no-op that records nothing — truncating the trace to a prefix with no error. When ② extended this lane to ALSO drive a complete no-body message, `headers-complete`/`message-complete` fired, so the recorder had to grow from ①'s six request-line callbacks to twelve ("the fixture now fires these too; bind them so a complete no-body message's full trace is recorded"). Recorders are NOT uniform: the machine declares 23 callbacks (`body-data` is ③'s 13th, ④ adds ten), but the framing lane's recorder binds 13 and the close lane's binds 2 (message-begin/complete only) — each binds exactly what the inputs IT drives will fire. When a slice extends the machine PAST an earlier terminal, re-run every earlier lane that pins a stop/finish/offset and confirm it still names the *reachable* terminal; and whenever a lane's driven inputs grow to fire a callback its recorder does not bind, extend that recorder before trusting the trace. Prefer terminal-relative and total-over-the-fired-callback-set assertions to offset/prefix snapshots, so the next slice's growth cannot disarm them.
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
* **A closed-set totality row is a floor-independent pin substrate.** When a
  per-member counter pin is subsumed by a tight acceptance floor — removing the
  member drops acceptance below the floor, so the floor check reddens first and
  catches the mutant "for the wrong reason" — do not lower the floor and do not
  leave it unpinned. Pin the removal on the **totality row** that compares the IR's
  closed set (read from `ir.sls` as a datum) to the generator's exported draw
  table: its `set-equal` fails on the removed member *regardless of the floor* or
  of whether any counter zeroed, and the member-specific got-list makes the pin
  match only that removal. Measured in Milestone 7 Slice ②: exact-byte / byte-set /
  integer-accumulate / mask-none removals each drop the 36-vs-32 acceptance below
  the floor, so all four are pinned on their totality rows, not their counters; the
  floor check still co-fires on them, recorded as a by-construction containment
  (each has a unique totality witness). This works only for a **drawn** family (a
  draw table exists to diverge from the source); a **declared** family with no draw
  table (span events, schedule shapes) has a totality row against a cited literal
  that no removal mutation can exercise. And when a family's totality row is
  exercisable, give it **one** removal pin so the row itself is proven load-bearing
  — an unexercised totality row is a check no mutation shows would fire.
* **A "the saved artifact reproduces" test must run the artifact's OWN code, not a
  re-derivation from the inputs.** When a slice ships a saver, serializer or
  code-generator and asserts its output round-trips or re-runs, load the emitted
  artifact and run IT — its own emitted constructors, its own embedded oracle, its
  own lane construction — rather than reconstructing the expected result from the
  pre-save inputs. Otherwise a mutation that makes the saver emit a wrong-but-well-
  formed artifact (right data, wrong embedded behaviour) survives, because the check
  never read what the saver wrote. Measured in Milestone 7 Slice ③: the fixture
  saver's first reproduction check re-applied the probe's lie to the saved
  `(machine, input)` and would have missed a saver that embedded an honest `gen`
  (`gen := ref`); re-reading and evaluating the fixture's own `(define gen …)` is
  what caught it. Ask of every such check: which mutation to the saver's OUTPUT does
  it miss? If a wrong output still passes, the check is testing the inputs.
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
* **A table keyed by K must assert that its rows are K.**
  A data-driven matrix selects a builder by key and then tests whatever the
  builder returns — the key itself is never checked. Slice ⓪'s kind × position
  matrix had nine rows keyed by node kind; swapping one row's builder for
  another kind's would have left sixteen cells silently testing the wrong kind
  with the suite green, and the verdicts still matched because only two rules in
  the whole verifier are kind-sensitive. Every row now runs its kind's predicate
  over what it built. Wherever a table's key is used to *dispatch*, assert the
  key against the thing dispatched to; the key is data like any other and
  nothing else reads it.
* **A value computed for a comment is a value not asserted.**
  The same matrix computed the pruned skeleton's sink set under a comment saying
  it was part of each cell's recorded value, then discarded it — a description of
  work rather than the work. It is now an observed count (`exactly three cells
  prune the sink`), which fails if the pruning changes. If a computation's only
  consumer is a sentence, either assert it or delete it.
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

* **Append, never insert, into a file other documents cite by line.**
  `byte-machine-implementation-plan.md` is navigated exclusively by
  `§section:line`, and the design and every decision record carry dozens of
  those pointers into it. An insertion anywhere in the body silently re-numbers
  all of them, and no link check can see it because every citation still points
  at a real line. Measured: a ten-line disposition note inserted at §25:1570
  moved `§25:1572` — cited by decision 0022 for "callbacks are Milestone 5" —
  and `§29:1754` onto unrelated text. Dispositions and dated notes therefore go
  in an **appended** section at the foot, which shifts nothing above it. The
  same rule applies to any file whose content other files address by line, and
  the corollary is the safer habit: **cite by content where you can**, because a
  line number into a file your own branch edits is stale on arrival — this
  branch produced a second instance of exactly that, in a mutation comment
  citing `design:834-836`, stale by its own merge.

* **The mutation lane is one silent ctest entry — bound each command, stream per-pass progress, and never read a live process as a progressing one.**
  The scheme mutation lane runs 590 mutations inside a single ctest entry (~5 min),
  and ctest buffers a single test's output until it ends, so a plain `make test-all`
  sits silent on `Start 29:` for minutes — indistinguishable from a hang. Milestone 7's
  close hit exactly this: the lane was reported hung while it was in fact progressing,
  and a first diagnosis called it "fine" from one `ps` snapshot showing a live `chez` —
  but a live process is not a progressing one (it can be blocked), and a stall detector
  keyed on the program name gives false positives, because a pass with many mutations
  holds one program name across many fresh short-lived processes. Prove *advancement*
  (churning PIDs, rising CPU, an advancing timestamped log — sampled twice) before
  calling such a lane hung or fine. Two changes make the lane honest about itself:
  `byte_machine_mutation_run_spec` bounds each verify command with a per-command
  `TIMEOUT` (default 300s, env `BYTE_MACHINE_MUTATION_INVOCATION_TIMEOUT`), so one
  non-terminating mutation fails *by name* — `byte_machine_mutation_verdict` maps the
  non-numeric result a killed command returns to a `did-not-terminate` verdict rather
  than folding it into `caught`, where a hang would read as a silent success — instead
  of consuming the whole-lane ceiling in silence; and each pass prints a
  `pass N: K mutations against <specs>` header and each mutation an `[i/K]` line, which
  stream live under `ctest -V` (`make test-mutation`) and name the pass and mutation a
  failing or timed-out run stopped on. A *successful* plain run is still silent on that
  entry — that is ctest buffering one passing test, not a hang.

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
  `.decisions/README.md` states that convention and the boundary it must
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
  (.decisions/0001-toolchain-discovery.md's claim of a CI that has never
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

* **Teaching a lookup a new node kind does not teach the filters that consume it.**
  A new node kind arrives through one or two shared accessors — `node-eof-target`,
  `node-out-targets` — and it is tempting to believe that is the whole seam. It is
  not. Elsewhere the verifier enumerates kinds *by hand*, in filters written as
  `(or (byte-dispatch-node? n) (sequence-dispatch-node? n))` and in `cond`s with
  one arm per kind, and a kind missing from one of those is **silent**: the filter
  yields `'()` and the pass simply has nothing to say. Milestone 4 Slice ③ taught
  both accessors about `integer-accumulate-node?` and left three such sites
  unchanged; two were Critical. `eof-terminal`'s `classify` fell into its residual
  `else` and **raised out of verification**, so a legal machine got no verdict at
  all rather than a wrong one — under a comment asserting that `else` was
  unreachable because "every kind `ir.sls` can construct has its own arm".
  `pass-eof-execution`'s §16.2:909 walk never started from the new kind, so a node
  naming itself as its own eof-target verified with **zero diagnostics** and then
  looped forever in both executors — while `parser-finish-op!` states in its own
  comment that it carries no local cycle guard *because* it relies on that check.
  Every fixture missed all three by construction. When you add a node kind, grep
  for every predicate of every existing kind, visit each site, and decide the new
  kind's answer there explicitly — including the sites where the answer is "not
  this kind". A loud `else` protects only the sites that reach it.

* **"Pay it once" only applies to a change that costs something.**
  A seam slice exists so that a change moving a committed artifact is paid before
  any semantics, letting every later slice assert "no golden moved" as a gate.
  Milestone 5's decision 0025 scheduled its trailing slot-table section that way
  and it did not belong: a section writing zero bytes for a machine that declares
  nothing leaves the byte stream — and so the fingerprint — identical whether the
  code exists or not, so landing it later costs exactly what landing it early
  costs. That is the whole difference from decision 0019's header slot, which sat
  inside bytes every machine writes and therefore *had* to be claimed a slice
  ahead. Before assigning work to a seam slice, name the artifact it moves; if
  there is none, the seam argument does not reach it, and scheduling it there buys
  only a guard over always-empty inputs.
* **A datum the ABI carries must be in the fingerprint, and "the encoding" is not
  the same list as "what the emitter reads".**
  Decision 0019 item 2 already said it — a datum "must enter the *encoding*, not
  merely be read from the source machine" — and Milestone 5 Slice ①b broke it
  anyway, in the file whose own comments record paying for it twice. The encoder
  was handed the SLOT TABLES, which hold names and positions; the emitter built
  a separate list carrying kind, `required?` and `default-branch` into the ABI
  payload. Two machines differing only in `required?` then shared a fingerprint
  and emitted different libraries, one of which refuses to construct a parser.
  When one structure feeds the fingerprint and another feeds the emitter, they
  are two censuses of the same thing (see the census rule below): derive both
  from one source, or assert pairwise that every part which reaches the emitter
  moves the fingerprint.
* **A mutation whose decision a later fix SUBSUMES gets retired with the reason,
  not weakened until it passes.**
  Slice ①b pinned a section discriminator on the ground that two record kinds had
  identical payloads, so only the tag separated them. The same slice's fix gave
  the two records different shapes — and the pin went UNCAUGHT, the runner
  reporting "that specification is not testing this behaviour". The temptation is
  to loosen the pin's expectation until it is green again; the pin's decision no
  longer exists, so what it would then measure is nothing. Delete it, say in its
  place why, and pin the property the fix actually created.
* **A guard that raises can be shadowed by a raise from the line after it.**
  Slice ①b's ABI-payload length guard was pinned twice and read UNCAUGHT both
  times: a one-member payload raises whether or not the guard is there, because
  the very next line indexes past the end. `assertion-violation?` passed on both,
  and so did a predicate matching the offending vector as an irritant — the
  builtin's own error carries it too. Only `who` separated them. When a guard
  precedes an operation that would fail anyway, the assertion must name what
  distinguishes the guard's refusal, and the mutation suite is what proves it
  does.
* **A permissive `else` that means "the normal case" swallows every value later
  added to its vocabulary, and nothing can check it.**
  `parser-feed!` dispatched on lifecycle with an `else` that meant `ready`, so
  every value the `case` did not name EXECUTED INPUT. Milestone 5 Slice ② added
  `busy` and `poisoned`; without arms for them a poisoned parser would have
  silently re-executed, and no test could have noticed because nothing could
  produce those states yet — the defect and its only witness arrive in the same
  commit. Name the normal case as its own arm and make the `else` raise, in the
  commit that adds the first value, not the one that adds the second. The
  project's per-kind `cond`s already follow this rule; a `case` over a state
  vocabulary is the same construct wearing different syntax.
* **In a chain of widening minimums, only the LAST guard discriminates anything.**
  The generated ABI payload had one length guard per version — at least one
  member, then at least two at ABI 4 — on the reading that each should name the
  member a short payload lacks. Slice ② added member 2's guard and the ①b guard's
  mutation went UNCAUGHT: a later minimum subsumes every earlier one, so removing
  an earlier guard changes nothing any input can observe. Three collapsed into
  one reading a named constant. Before adding a guard whose condition implies an
  existing one, ask what input can now distinguish them; if none can, the earlier
  guard is prose with a raise attached.
* **A declared survivor's reason is only as durable as the control-flow shape it
  names, and closing a fall-through can close survivors elsewhere.**
  The file already says to re-run the whole suite after adding an EXIT path,
  because a new exit can disarm a mutation. The converse is just as real and cost
  two re-measurements to keep honest: "parser-feed!'s finished sticky arm is
  deleted outright" carried a twice-verified `EXPECT_SURVIVES` reason that rested
  entirely on that `else` meaning "ready" — the deleted arm fell through and the
  op path re-derived the identical tuple. Slice ② made the `else` loud for an
  unrelated reason and the mutant became caught; the runner said so itself ("The
  recorded limitation is stale"). Re-read every survivor whose reason names a
  fall-through, a default, or a shared branch when you change one.
* **A mutant can HANG the suite rather than fail it: the mutation runner has no
  per-mutant timeout.**
  Slice ②'s reentrancy probe called `parser-feed!` from inside a callback. Under
  the mutant that stops marking the parser `busy`, the inner feed finds a `ready`
  parser, runs the executor, reaches the same callback and feeds again — unbounded
  recursion, and the suite sat until it was killed rather than reporting. Any test
  that re-enters the code under test must bound itself (a one-shot flag is enough),
  and the bound is what turns the mutant into a failed comparison — it records
  `returned` where the baseline records `raised`.
* **A per-kind census in `test/` is still a per-kind census.**
  Milestone 5 Slice ②'s site table listed every place a new node kind must reach
  in `src/` and missed `verify-tests.sps`'s `t2-kinds`, the hand-written kind list
  behind §16.2:908's rows — because the table's scope was `src/` only. The
  reconciliation found it; the design's appendix now carries the `test/` censuses
  beside the source ones. When you write a "every site X must reach" table, say
  which directories were searched, and search both.
* **A comment that enumerates a closed set is a census, and it goes stale in silence.**
  `compile.sls` carried "this case already covers every kind `normal-state-kind`
  can produce (dispatch/stop/error/finish/pause)" through two slices that widened
  the set to eight — including one whose new arm sat eleven lines above the
  comment. Nothing failed, because prose is not checked. The same milestone shipped
  a `FORTY-EIGHT PASSES` banner against forty-nine, a "six state literals" census
  that was eight, and a sweep census that read 31 pins for a 32-pin pass because
  the tool matched `EXPECT_SURVIVES` as a substring and two blocks *discussed* it.
  Prefer deriving the set from the artifact — `member3-drift-tests.sps` walks the
  emitted library as a read datum and compares it against a declared list, which
  is a census with a test. Where prose must state a count, state where it was
  measured, and re-measure it when the thing it counts changes.

* **A derived census still declares the thing that finds it.**
  Deriving the set from the artifact moves the staleness one level up, it does
  not remove it. Slice ⓪'s diagnostic census walks `verify.sls` as a datum and
  derives all sixteen codes from the source rather than listing them — but it
  recognised emission sites by two hardcoded constructor names, so a third
  constructor, and every code emitted through it, would have shipped unpinned
  while the census stayed green and looked derived. The constructor set is now
  derived too (from the `define`s whose names start `make-diagnostic`), which
  also puts each new constructor's own header into the subtraction
  automatically. When you write a census, ask what set the *recogniser* is: if
  it is a literal, it is the census you actually shipped.

* **A committed document that enumerates a set the code also defines is another place that set drifts — check it against the code, and scope the check away from the mutation suite.**
  The derived-census rule above keeps a TEST honest against the source; a reference
  DOCUMENT that lists the same set needs the same discipline, or it becomes a
  thirty-first place for the set to go stale. Milestone 9's
  `.reference/verifier-diagnostic-catalog.md` lists the thirty diagnostic
  codes; `diagnostic-census-tests.sps` now asserts the catalog's code set equals
  the census it walks from `verify.sls`, so a code added to the verifier reddens
  the catalog until it is updated — the doc cannot silently lag the code. Two
  scoping traps make this more than a one-line check: (a) `diagnostic-census-tests.sps`
  is ITSELF a mutation verify command, so an unscoped doc-vs-code check would fire
  alongside the census pins on every `verify.sls` mutation and muddy their per-pin
  accounting; (b) the mutation suite runs against a STAGED tree that does not
  include `docs/`. Both are avoided by keying the check on `BYTE_MACHINE_REPO_ROOT`,
  which the ordinary ctest lane sets and the mutation runner does not — so the
  check runs under `ctest` and is skipped under the mutation suite, where a
  documentation-consistency check does not belong.

* **A release ledger is a derived census of the exit criteria, and a criterion it ships not-met is `amended`, never `met` and never quietly dropped.**
  Milestone 9's `(byte-machine test release-ledger)` carries `§26`'s fifteen
  criteria and `§27`'s eleven deliverables as data and RE-READS `§26`/`§27` from
  the parent plan to set-compare (two totality rows — adding or dropping a
  criterion in either the plan or the ledger fails by name, the derived-census
  rule applied to the exit gate). Its worth is the honesty it forces at the close.
  When a criterion cannot be met — M9 had no CI budget, so two Tier 1
  cross-cell/matrix criteria could not pass — the ledger carries it as a FOURTH
  state, `amended`, distinct from `met` and from a silent omission: an explicit
  dated `§7.3:195` amendment in the parent plan plus a release-note entry, which is
  exactly what `§7.3:203` demands ("cannot be silently waived in release notes").
  The lane asserts the whole partition (13 `met`, 2 `amended`, 0 `open`) and that
  no row names a receiver — nothing is owed and nothing is claimed met that is not.
  A release that shipped an unmet criterion as `met`, or dropped it from the
  ledger, would be the waiver the plan forbids, arriving through the ledger instead
  of the release notes.

* **Re-sweep every count after a fix wave, not just the tests.**
  A review's fix commits move counts, and the prose that quotes them is not part of
  the suite. Milestone 4 Slice ③ closed with a status block reading "358 mutations"
  and "78 verify.sls pins" against a tree at 368 and 81 — both true when written,
  both stale two commits later — while the census table three lines above them had
  been re-measured. The document disagreed with itself and with the CHANGELOG. A
  count restated in two places is a count that will disagree with itself: keep one
  authority, and after a fix wave re-read the fix's own commits for every number
  they moved.

* **Making one site loud is a fact about that site, not about the family.**
  `verify.sls` grew a loud `assertion-violation` on `join-over`'s *empty*
  zero-width join; the comment written beside it then claimed the `unresolved`
  verdict is unproducible altogether. Two different sites: `classify`'s
  `((not n) 'unresolved)` arm still answers it for any EOF successor naming no
  node, reached by two routes today. The false claim made the verdict's *tier*
  load-bearing and unwitnessed — a machine whose EOF chain reaches both a
  dangling name and a `stop` reports the stop only because `unresolved` loses
  the join — while the paragraph above it asserted that tiers make every
  assignment a one-token caught mutation, false for one of six. When a fix
  closes one producer of a value, name the site in the comment and go look for
  the others; "X can no longer happen" is a whole-tree claim and needs a
  whole-tree search. A load-bearing negative earns a second search method.

* **Do not anchor a mutation on prose.**
  A `FIND` that includes a comment line breaks every time that comment is
  corrected, which inverts what an anchor is for. One Slice ③ pin was re-anchored
  three times for this reason — it sat on a comment because the code it named
  occurs three times in the file — and the third break came from correcting that
  very comment's stale claim. Anchor on code. When the code alone is not unique,
  extend into the *following* construct rather than the preceding comment: the
  paragraph above a clause is the part most likely to be edited.

* **Run review and audit fan-outs in an isolated worktree.**
  Subagents told they may edit files to test a hypothesis will do so in whatever
  tree you point them at, and their edits are real between edit and restore. A
  `ctest` run alongside a Slice ③ audit reported 16/94, then 1/94, then 94/94 with
  `git status` clean each time; a detached worktree at the same commit settled it
  at 94/94. The mutation suite is worst affected — it stages the tree, so an
  outside edit inside that window produces bogus UNCAUGHT and caught-survivor
  verdicts that look exactly like real breakage. Use `isolation: "worktree"`, and
  never quote a suite result taken while such a workflow is live.

* **A comment justifying an ABSENT arm must say whether adding it would be inert
  or WRONG.**
  Milestone 5 Slice ③ shipped one saying an arm on the boundary flush's `paused`
  row "would be a guard that cannot fire". Measured, that arm would not have been
  inert: on that row the span is still active and the mark still points at the
  fragment the span end has just delivered, so the arm would have handed the
  application the same bytes twice. This repository ACTS on "cannot fire" — it
  deleted five such lines in that slice alone — so the phrase is an instruction,
  and using it for "would be wrong" is an invitation to break something.

* **In a cross-lane pin, the `expected`/`got` DIRECTION is the discriminator, not
  the (case, check) pair.**
  A mutation of one lane and the matching mutation of the other fail the SAME
  check with the SAME two values, transposed — the harness prints the second
  `check-equal` argument as "expected", so which lane you broke decides which
  side each value lands on. Two Slice ③ pins were byte-identical to their own
  siblings' output until they were re-pinned on the projection line rather than
  the kind line. Pin sweeps must compare captured output, not check labels.

* **A fixture that always declares the subject first cannot see a hard-coded 0.**
  Every span fixture in the tree declared the span's data callback first, so four
  independent sites resolving "the span's data-callback slot" were all satisfied
  by the constant `0`, in both lanes, with the suite green. Declaring the OTHER
  callback first is what made the resolution observable. The same shape applies
  to any slot, index or id that a fixture could give the value 0, 1 or "first" —
  put the subject somewhere else and see whether anything notices.

* **A lane that imports no project source is outside the mutation suite, and must
  say so at the site.**
  Slice ③'s liveness-probe lane tests Chez's GC primitives, not byte-machine, so
  there is nothing for a mutation to break and its absence from the suite is not
  a coverage gap. Its control is that both arms of the discrimination are asserted
  in one case — a probe answering a constant fails one of them. Write that down,
  or the next census counts the lane as unpinned.

* **Validate the NEXT slice's oracle while this slice is in flight.**
  Slice ③ carried Slice ④'s retention-oracle liveness probe forward and measured
  it through the real harness in both lanes. It cost one small lane; had it not
  discriminated under AOT compilation, ④'s entire oracle would have needed
  redesigning — and that is much cheaper to learn early than to discover inside
  the slice that depends on it. When a design rests a later slice's oracle on a
  measurement taken in a scratch driver, re-take it now.

* **A status surface written at the end of a slice is the least verified text in
  the repository.**
  Slice ③'s closing sweep wrote the four status surfaces and the ledger, then
  audited them: fourteen false claims, in prose minutes old — counts contradicting
  the tree, a defect tally split the wrong way, a universal that one site never
  satisfied, and a systematic off-by-one in `§section:line` citations inherited
  from the milestone design and multiplied fifty-five times. Nothing catches a
  wrong citation: a link checker sees a valid file and a grep sees a valid number.
  Audit the surfaces with something that MEASURES — re-count every total from the
  tree rather than from a commit message, open the plan at every cited line, and
  narrow every "every", "the only" and "never" before writing it.

* **A deferral is recorded where its RECEIVER will look, which for a role is the
  source site.**
  An obligation addressed to a STEP ("Milestone 6's counted consume owes X")
  belongs in that step's plan. An obligation addressed to a ROLE — "whoever next
  touches the field/accumulate emitted arms", "the next slice that changes this
  record's shape" — belongs in the file that role will open, because that person
  has no reason to open the parent plan. The parent plan is where a deferral is
  ADJUDICATED; it is not where either receiver looks, and a disposition that
  lives only there is a deferral with one end.
  Milestone 5's close-out found two of these owed to it, both recorded only in
  the plan, and wrote them into `compile.sls`, `interpret.sls` and `runtime.sls`
  at the exact constructs the receiver would edit. Write both ends, and say in
  the source note where the adjudication is, so the two cannot drift apart.

* **A test that drops the subject along with the evidence proves nothing.**
  The retention oracle's whole design is that the PARSER is held alive across the
  collection and only the fed bytevector is dropped. A probe that let the parser
  die too would report "not retained" about a runtime that stored the input in
  every slot it has — the storage would have died with it — and every arm would
  pass. Before believing a liveness or reachability result, name what is still
  alive at the moment of measurement and check the subject is on that list.

* **An APPROVAL with no receiver is invisible to every completeness sweep you
  have.**
  A milestone's close-out looks for two things: exit criteria, and obligations
  that name a receiver ("owed by whoever next touches X", "Milestone 6 owes Y").
  An owner's *approval* of a scope addition is neither. Milestone 5 approved
  three items at its Gate 0; two shipped, and the third — a verifier check for a
  field two new declaration families had just started carrying — shipped nowhere
  and appeared in no slice plan, no exit criterion and no deferral list. It was
  found only by a review asking a third question: **what did this milestone
  approve that the tree does not contain?**
  Ask that question at every close-out, against the design's own resolution
  sections, and give every approved item a slice at the moment it is approved —
  an approval that names no slice is a deferral nobody knows they are holding.
  Milestone 5 built the dropped item rather than deferring it, and it cost less
  than the deferral paragraph did: the check turned out to be a second call site
  of a predicate already shipped, folded into an existing conjunction, with no
  new diagnostic code and an unmoved census. **Price the item before deciding to
  defer it** — the estimate that justified deferring this one was written before
  anybody read the predicate it would reuse.


* **The mutation suite prints "suite complete" on the way to FAILING.**
  A mutation caught "for the wrong reason" — a mutant that exited nonzero but
  whose output did not match its pin — raises a `SEND_ERROR` from
  `MutationRunner.cmake` **inline, during the pass**, and
  `byte_machine_mutation_run` then prints no totals line for that pass at all.
  The reassuring `(N passes, M mutations)` line still appears, because it comes
  from the suite's own epilogue, which runs after the error. Slice ④ read a filtered
  log for `suite complete|UNCAUGHT` three times, saw `(55 passes, 471 mutations)`
  each time, and missed a wrong-reason error underneath it; the pin had been
  broken from the moment it was written.
  **Filter tool output for the FAILURE signatures, never for the success line.**
  For this suite that means `CMake Error`, `wrong reason`, `UNCAUGHT`, and the
  `tests passed` line — and the exit status, which is the only summary that
  cannot be printed by a run that then fails.

* **A pin's regex is matched against `FAIL <group>.<case>: <what>`, so `.*:`
  between group and case is a trap.**
  The group name in this repository routinely carries `§section:line`
  references, and a greedy `.*:` swallows their colons. Anchor a pin on the CASE
  name, which is followed by a literal `: `, and never on a wildcard bridging the
  group. The suite catches this — it is what "caught by coincidence, not by the
  decision this mutation names" means — but only after a full run.

* **`.*` between `expected` and `got` bridges to a LATER record, and a regex that
  ends at `got` is satisfied by every mutant that moves the value.**
  CMake's `.` matches a newline, so `expected .*, got X` is satisfied by any
  mutant whose output carries `got X` in any later FAIL record — Milestone 6
  Slice ①'s sweep found five such pins, one of them satisfied by a different
  mutant's `got`. And a pin that stops at `-- expected 8698736890881894294, got`
  names no `got` at all, so twenty unrelated mutants satisfied it. Spell the
  expected list in full with `.` for each literal paren, and pin the MEASURED
  `got` — taken by staging the mutant in a scratch copy and running the real
  launcher, never recomputed by hand.

* **A pin must resolve exactly ONCE in its own mutant's output, and nothing that
  runs by default counts.**
  A new check label that CONTAINS a shipped label — Milestone 6 Slice ② wrote
  "counted: gone in both lanes" beside the shipped "gone in both lanes" — makes
  the shipped pin's regex match two records of its own mutant's output. The lane
  is green, the mutation lane says caught (`MATCHES` asks whether, not how many),
  and the two-direction sweep is clean (it judges each pin against OTHER
  mutants). Only the whole-branch review saw it. Before committing a label in a
  lane that has pins, embed it in every pin's literal core and pick one that
  shares no run of words with any; after a sweep, count each pin's matches in
  its own mutant's output (`re.findall`, DOTALL) and require 1.

* **R6RS leaves `map`'s application order unspecified; drive anything sequenced
  with `for-each` or a named `let`.**
  A feed schedule expressed as `(map feed! slices)` ran the slices out of order
  under Chez, and BOTH lanes reported the same impossible result — no callbacks
  at all — so the differential "agreed" on the test's own error while a scratch
  driver showed the runtime behaving correctly. `map` is for pure lists; a feed,
  a resume, a finish, or any step whose effect the next step reads goes through
  `for-each` or an explicit loop, and when two lanes agree on an impossible
  value, suspect the test's ordering before the runtime.


* **A predicate that calls another predicate nests its mutants by construction,
  and the inner one's pins are the only real ones.**
  `valid-label?` calls `valid-reason?`, so every mutant of `valid-label?`'s
  symbol and string arms is strictly less destructive than the shipped
  permissive-`reason-char?` mutant — measured, that mutant reddens all four label
  cases and the reason case besides. Those arms therefore get **no pin**, and
  that is a closed question rather than a coverage gap: their control is that
  each is asserted in BOTH directions. What does get pinned is the part that is
  *not* nested — here the absence arm, which decides before the inner predicate
  is reached, and the per-family label conjuncts — but only once the fixture
  gives each family a record the inner mutant cannot produce. Measured: with the
  wrong-shape label on the callback alone, the SPAN family's conjunct mutant was
  itself nested and shipped unpinned for a day; the fix was a second fixture
  value, not a second pin.
  Before writing a pin, ask which shipped mutant already contains yours — and if
  one does, look for the fixture change that would separate them rather than
  dropping the pin.

* **`$` does not anchor a line in a mutation pin.** CMake's `MATCHES` anchors at
  the end of the whole captured output, so `got ..$` matches nothing and the
  suite reports the mutation "caught for the wrong reason". Assert the value's
  own shape instead: `got .[)]` is what says the list is EMPTY, and it is what
  separates a mutant that suppresses a finding from one that adds findings to the
  same case.


* **A `file:line` into a document your own commit also edits must be re-measured
  AFTER the last edit to that document.**
  Decision `0024`'s pointer into `milestone-5-design.md` has now been wrong three
  separate ways: wrong on arrival (off by twenty-two lines at the commit that
  wrote it), wrongly diagnosed as drift when it was corrected, and then stale
  again **within the correcting commit itself** — that commit inserted eighteen
  lines above the target after the new number was written. Resolving a citation
  when you type the sentence is not enough when the same change is still moving
  the file. Re-open every cross-document citation as the last step before commit,
  and prefer a searchable construct name to a line number whenever the target has
  one. See also the standard on status surfaces: this is the same failure with a
  shorter fuse.


* **Moving a documentation directory shifts every relative link into and out of
  it — a repo-wide link-check is the only guard, and some references are
  functional.** (2026-09-13) The internal doc sets left `/docs` for hidden root
  directories — `docs/plans` → `.plans`, `docs/decisions` → `.decisions`,
  `docs/reference` → `.reference` — so `/docs` carries only public documentation.
  A directory that drops from depth 2 (`docs/plans`) to depth 1 (`.plans`) changes
  the `../` depth of every link it holds: cross-set links became `../decisions/` →
  `../.decisions/`, and every root-reaching `../../X` lost one hop to `../X`; links
  from the other sets in gained one (`docs/decisions` → `docs/plans` was
  `../plans/`, now `.decisions` → `.plans` is `../.plans/`). Root-anchored
  references (repo-root paths in `README.org`/`CHANGELOG.md`, `../../docs/…` from
  `examples/`, and `repo "/docs/…"` reads in tests) only need the `docs/X` segment
  swapped for `.X`; docs-internal relative links need per-source-directory
  recomputation. Crucially, several references are **functional, not cosmetic**:
  `release-ledger-tests.sps` reads the implementation plan and the `§27` reference
  docs by path and set-equal-checks them against `release-ledger.sls`, and
  `diagnostic-census-tests.sps` reads `.reference/verifier-diagnostic-catalog.md`
  under `BYTE_MACHINE_REPO_ROOT` — so the move must update those paths and re-run
  the lanes, and a `git mv` comment edit inside a SOURCES `.sls` forces a provenance
  reconfigure. The guard that made this safe was a resolve-every-`](…)`-link
  checker run before and after: it went 17 pre-existing broken → 0, proving no new
  breakage (and incidentally fixing the pre-existing `./NNNN-*.md` decision links).


## Closing ritual

Run this when a branch's work is complete and reviewed. It is a ritual because
each step is easy to skip and each one left undone costs someone else later.

1. **Squash merge the PR.** One commit per branch on `main`. The granular
   history — the review trail, the fixes, the plan corrections they forced —
   stays readable in the PR. CI is on demand (the bullet in *Testing & mutation
   discipline* below): a PR touching `src/`, `test/` or CMake gets the `ci`
   label once its branch is final and merges after that run is green; a
   docs-only PR needs no run at all.

   **A run that never started is a billing refusal, not a red lane, and the
   difference is `steps=0`.** This account's Actions minutes are exhausted, so
   the labelled run comes back `failure` having tested nothing. Read it, do not
   infer it:

   ```sh
   gh api repos/<owner>/<repo>/check-runs/<id> --jq '{conclusion,steps:(.steps|length)}'
   gh api repos/<owner>/<repo>/check-runs/<id>/annotations --jq '.[].message'
   ```

   `steps: 0` plus *"The job was not started because recent account payments
   have failed or your spending limit needs to be increased"* is the signature.
   **The duration is not** — a four-second failure is scheduling latency and a
   four-second success would look the same, so a fast red proves nothing either
   way. When it is a refusal, say so on the PR with the two readings quoted,
   name the local selection that stands in for it, and merge. When it is not,
   it is an ordinary red lane and the ritual has not been satisfied.
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

## A median inside the clock is not a measurement

`bench/fixtures/baseline-tarm64osx.sls` was committed at one hundred iterations
per round. Read back, **ten of its twelve generated-lane medians are 0, 1 or 3
milliseconds** against a one-millisecond clock, with a recorded dispersion of
one or two milliseconds around them. Every `bytes-per-second` figure in that
artifact is a quotient over one of those, so the artifact recorded twelve
workloads and could measure none of them.

Nothing was wrong until someone tried to *use* it. `§23.3` asks for a threshold
derived from observed variance, and the variance there is the clock's, not the
parser's — so decision 0048 had to re-record the baseline at two thousand
iterations before it could derive anything. That is the cost of the original
omission: not a wrong number, an unusable one, found a milestone later by the
first person who needed a denominator.

**So: a recorded number needs a resolution claim beside it, and the way to
check one is to read the raw medians rather than the rates.** A rate hides the
problem — it is the small, unresolvable interval that produces the largest and
most impressive quotient. The two readings that matter are the median and the
dispersion, and if the dispersion is an appreciable fraction of the median, the
instrument is measuring itself. `chez-httparse` found the identical defect in
its own throughput lane the same day, from the other direction: it floored
elapsed time with `(max 1 ...)` before dividing, so a fast enough machine would
have printed a fabricated rate that sailed over every floor asserted below it.


## A slope is blind in the dimension it holds fixed

The allocation audit (decision 0040) measures a **slope**: two messages
differing only in length, allocation differenced, divided by the byte
difference. It was green, and it was right — the generated lane allocates
exactly 0 bytes per input byte, with a live control proving the apparatus can
see one.

It was also blind to 128 bytes per HEADER. Its two messages differ in the
length of one header *value*, so the header count is held fixed and a
per-header cost cannot appear in the quotient. It landed instead in the
per-message intercept, which that decision deliberately reports separately and
never divides by anything — so the number was on screen, in a figure whose
whole job is to not be a slope.

It was also visible in the committed baseline, to anyone who subtracted two
rows: `many-small-headers` at 5 216 B/message against `short-normal-requests`
at 1 504, over 29 extra headers, is 128 B/header exactly. Nobody subtracted
them for six milestones.

**So: a slope answers only the question its held-fixed variables allow, and
the variables it holds fixed are the ones nobody chose deliberately.** Before
trusting a zero, ask which dimension it is zero *in*, and whether that is the
dimension the thing being measured actually varies along. Real HTTP traffic
varies in header count far more than in header-value length, so the audit was
measuring the dimension that mattered least while asserting a property about
"the per-byte path". Every new slope gets its own live control for the same
reason the first one did — a slope of zero is indistinguishable from a
measurement that cannot move, in whichever dimension it is taken.
