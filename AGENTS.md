# AGENTS.md

## Project guidelines

### Architecture & portability

* Use the functional core / imperative shell pattern
* Follow the 12 Factor Apps philosophy
* Project targets Chez Scheme (R6RS) only — see .decisions/0005-chez-only.md
* Project should be portable across macos (darwin), linux, and windows
* Project should be portable across amd64 and arm64
* **DO NOT** set up macOS CI runners: Linux only.

### Layout, process & libraries

* Plans live in `/.plans`, decision records in `/.decisions`, the v0.1
  reference set in `/.reference`. These and `AGENTS.md` are export-ignored, so
  `src/`, `docs/`, `examples/`, `README.org` and `CHANGELOG.md` never cite them.
* `.plans/lessons.md` holds the case history behind the rules below. Read it
  before writing or judging a mutation pin, or before closing a milestone.
* `/docs` is public documentation only: concise, plain, ELI5 for developers.
  `make site` renders it (generator in `/site`, tests in `/test/site`).
  Run `make check-site` after changing a page or a public export: it checks
  the nav, every link and anchor, and that `docs/reference.md` documents
  exactly the public exports.
* `CHANGELOG.md` gets an entry for each user-visible change, written for a user
  of the library. It never names a milestone, slice or decision record.
* `README.org` has no status section. Do not add one.
* `Makefile` has a `help` command listing every target.
* Libraries are R6RS `.sls`; libraries and programs contain their own code — no
  shared include bodies (.decisions/0006-inline-libraries.md). R6RS forbids
  assigning an exported variable — reach mutable state through procedures.
* Widen a public surface when a user needs it, never for a test. A test that
  needs internals imports from `(byte-machine private ...)`.

### Testing

* Use TDD. A test is finished when you have watched it fail. A test that
  passes whether the code is right or wrong is worse than no test.
* Prefer a check to a comment. Do not write tests that read code comments.
* Tests pass before every commit. A plan that schedules a red intermediate
  commit is wrong: ship those tasks as one commit.
* `make test` runs the pull-request selection. `make test-all` adds the
  mutation suites (~5 min, silent until done; `make test-mutation` streams
  progress). Judge a run by its exit status and its failure signatures
  (`CMake Error`, `wrong reason`, `UNCAUGHT`), never by "suite complete".
* CI is one Linux job: every push to `main`, and a PR once it carries the `ci`
  label. A later push re-runs nothing; re-label, or
  `gh workflow run ci.yml --ref <branch>`. The header of
  `.github/workflows/ci.yml` is the rule.
* Assert expected values. The interpreter and generated lanes can agree on a
  wrong value; after a cross-lane fix, ask which value they now agree on.
* Build fixtures that can see the defect: put the subject somewhere other than
  first or index 0, make two coordinate systems differ, and hold a slope's
  other dimensions fixed.
* A census ("every X gets Y") is checked over every X mechanically, with a
  sentinel counting what the code returned. Derive the set from the artifact,
  and derive the recogniser too. A table keyed by K asserts its rows are K. A
  document listing a set the code defines gets a check against the code.
* Adding a node kind, runtime op or arm kind: find every site in `src/` and
  `test/` that lists the existing ones and decide the new one's answer there.
  The allocation audit needs a witness for each new op or arm.
* A `case` over a state vocabulary names its normal case and raises in `else`.
* A test that re-enters the code under test bounds itself, so a mutant fails
  instead of hanging.
* Sequence effects with `for-each` or a named `let`. R6RS leaves `map`'s order
  unspecified.
* A test of saved or generated output runs that output's own code.

### Mutation suite

* Every decision in a module gets a mutation its specification catches. An
  uncaught mutation means strengthen the test. `EXPECT_SURVIVES` is for the
  demonstrably unwitnessable, with a written reason, never to reach green.
* Prefer a mutant caught by a failed comparison to one caught by a raise. Count
  the cases it fails: a uniform crash across the suite pins nothing.
* Put the witness in the program of the mutation's own `SPEC` lane.
* A pin is an unanchored CMake regex over the whole output (`.` matches a
  newline, `$` is the end of the output). Pin `<case>: <check label>` and the
  measured `got`; end a number with `[^0-9]`. Never match text that every
  failing run prints. A pin matches exactly once in its own mutant's output.
* Judge a pin against every other mutant in its lane, in both directions.
  "Subsumed" is a measured whole-set relation. Before recording one, try a
  pair check, a value spanning two inputs, and a trace carrying both cases.
* Re-anchor `FIND` and `REPLACE` together. When renaming or re-contracting a
  construct, search every pin's `FIND` and `REPLACE` for it. `SITES` also
  fails when new code duplicates a pinned line: rename the new code's
  bindings. Anchor on code, never on comments.
* A new exit path, witness, check or mutation can disarm or widen existing
  pins. Re-run the whole suite and re-judge the lane.
* Before retiring a mutation, stage the deletion and measure what still
  catches its case.
* Run audits and review fan-outs in an isolated worktree. An agent's edit
  corrupts a concurrent mutation run.

### Documentation & records

* Re-measure a number against the shipped artifact before it enters a doc.
  Write the command that produced it, and its qualifier, beside it.
* Narrow every "every", "the only" and "never" to what was searched. A claim
  that a check is blind names both sides of its comparison.
* Reviewers check claims against the code. Put this sentence in their prompts
  verbatim: *check what this claims the code or the spec DOES against the code
  and the spec, not against the prose*.
* **Correct a stale instruction in place; annotate a stale record.** A plan
  task, exit criterion or code comment is corrected. A measurement, finding or
  decision Context gets a dated note, and the top of the record says one was
  added (`.decisions/README.md`). A closed work order gets a disposition.
* Append to, never insert into, a file others cite by line. Cite by content
  where you can, and re-check citations after your last edit to the target.
* A comment explaining an absent arm says whether the arm would be inert or
  wrong. "Cannot fire" reads as permission to delete it.
* A comment that calls something fine or deferred says what would settle it.
  A deferral owed by whoever next edits some code is written at that code.
* Closing a milestone updates its plan, its design document, the parent plan
  and `CHANGELOG.md`'s `[Unreleased]`. Re-count every number in them from the
  tree, and find the thing in the tree before writing "met".

## Closing ritual

We run this when we're done and ready to merge the PR.

**Important**: ALWAYS ask before running this.

1. Squash merge the PR. A PR touching `src/`, `test/` or CMake gets the `ci`
   label once final and merges after that run is green; a docs-only PR needs
   no run. A run with `steps: 0` never started
   (`gh api repos/<owner>/<repo>/check-runs/<id>`): say so on the PR, name the
   local run that stands in for it, and merge.
2. Catch up local `main`.
3. Clean up branches. Delete the merged branch locally and on the remote.
   Retarget a stacked PR to `main` before deleting its base.
4. Reflect. Facts go to memory; project rules come here as one or two lines,
   with the case history in `.plans/lessons.md`; what the code should say
   about itself goes in a comment at the site.
