# Proof that the Scheme harness's self-tests are not vacuous.
#
# The harness is the instrument every later milestone is measured with. If
# `check-equal` silently always returned true, the whole project would go green
# and stay green, and no test written with `check-equal` could notice. So each
# decision in the runner is broken in turn on a staged copy, and the self-tests
# must fail.
#
# THIRTY-ONE PASSES, BECAUSE THIRTY-ONE DIFFERENT WITNESSES ARE NEEDED
#
# EXPECTED_PASSES and EXPECTED_MUTATIONS are declared below; checked against
# byte_machine_mutation_totals' accumulated count once every pass below has
# run: that check is what a whole-branch review found nothing else could do --
# deleting the three matrix passes (21 to 23 in the numbering of the tree
# where this happened) by hand left this file's own suite reporting 37/37
# elsewhere, with the mutation count silently dropping from 56 to 53 and
# nothing anywhere noticing. The matrix itself -- passes 19 to 21 in the
# previous numbering -- retired outright in this task (decision 0006); see
# the replacement paragraph where it used to sit.
#
# Pass 1 runs the Chez self-tests lane against the runner.
#
# Pass 2 runs the Chez empty-selection lane through the exact-status helper, for
# the one decision in the runner that no in-process assertion can reach --
# harness-begin reading BYTE_MACHINE_TEST_FILTER out of the environment. A suite
# cannot set its own environment from inside the portable subset, and the
# harness exports no reader for the filter that read produces, so the only
# witness is a whole process that was supposed to select nothing and exit 2.
#
# Pass 3 runs the Chez bootstrap lane, for the defect that disarms the
# self-tests as it commits them: a failure counter that stops counting. Every
# assertion in every suite reports through the counter, so with it broken a
# failing suite prints its FAIL lines and still exits 0. The bootstrap counts
# its own failures with raw conditionals and exits by hand, which is exactly why
# it exists and why it is the only lane whose verdict survives.
#
# Passes 4 to 5 run the Chez launcher's two guard-directory refusals, one per
# pass, each through the exact-status helper. A refusal cannot be witnessed by a
# lane that is set up correctly, because a correctly set-up lane never reaches
# one: each needs its own deliberately wrong command line, and a verify command
# is fixed for the whole pass.
#
# Pass 6 is the launcher's `compile-imported-libraries` call, and it is the one
# mutation in this file that no single process can catch. See its recorded
# reason.
#
# Pass 7 is the library-directories pairing, the mechanism that makes
# `mode=source` an honest claim. No library root in this tree has a compiled
# object in it, so unpairing the root from the guard changes nothing anywhere
# else; the pass therefore builds a root that does have one, and runs the
# self-tests lane against it.
#
# Passes 9 to 17 are the launcher's parse decisions: an unknown flag, a flag
# with no value, a single-valued flag repeated, a required flag unchecked in
# general, one entry dropped from each of required-flags' three members, and
# one entry dropped from each of single-valued-flags' two members. Each gets
# its own pass because each needs its own deliberately wrong invocation and a
# verify command fixed for the whole pass, the same constraint passes 4 to 5
# already established -- generalised here from two decisions to nine.
#
# The three working-directory-matrix passes that used to sit between the
# parse decisions and the consumer pass retired with the include mechanism
# (decision 0006): with library roots absolute and source-directories empty,
# there is no resolution step left for a launch directory to change, so the
# claim the matrix witnessed empirically is now structural.
#
# Pass 20 is the fingerprint algorithm's own decisions -- the +1 that keeps a
# leading zero byte significant, the seed, the multiplier, the modulus, and
# combine's order sensitivity.
#
# Pass 21 is the hex digit table. It sets no manifest, so provenance is
# skipped here exactly as it is for every other pass but 22 through 25: what
# actually catches the mutation is the self-tests' own "hex digits render
# lowercase" case, which check-equals fixed literals ("ff", "deadbeef", "0")
# rather than deriving its expectation from fingerprint.sls.
#
# Passes 22 through 25 are the provenance check and the reachability guard
# that closes over it (Task 8): 22 is the comparison, 23 the
# missing-expectation branch, 24 the call site that reaches
# harness-verify-provenance! at all, and 25 harness-provenance-reachability-
# diagnosis itself, each witnessed through the exact-status helper so that
# exit 3 -- the refusal -- is the green baseline, exactly as passes 4 and 5 do
# for the launcher's guard-directory refusals. A third refusal -- a manifest
# naming an unreadable source -- has no mutation; see the stated blind spot
# recorded beside pass 23 below. Pass 24 was pass 22's second mutation until
# Task 8: see the detail beside its declaration for why the reachability guard
# made WRONG_FP_FILE's exit-3 baseline ambiguous for that one mutation and not
# for pass 22's own.
#
# Pass 26 is the aot launcher's own library-path pairing (C3) and its
# source-directories narrowing (C3b) -- the mechanism that makes `mode=aot`
# an honest claim, the same argument pass 7 already makes for `mode=source`.
# The objects it exercises are compiled once, from the staged tree, into this
# pass's own work directory, and reused by passes 27 to 29 below. C3 is
# witnessed against a divergent library source planted where only an
# unpaired object directory would read it; C3b is EXPECT_SURVIVES, for the
# reason recorded beside it.
#
# Passes 27 to 29 are the aot-side launchers' three genuinely new refusals --
# chez-aot.ss's missing-program check, chez-aot.ss's dirty-source-guard
# check, and chez-compile.ss's unpaired-roots check -- each witnessed the
# same way passes 9 to 17 witness chez-source.ss's parse decisions: a
# deliberately wrong invocation through the exact-status helper, since a
# correctly set-up lane never reaches a refusal on its own. The flag-block
# copies both files carry from chez-source.ss are deliberately not re-proven
# here; each launcher's own header records what that leaves unwitnessed.
#
# Pass 30 is design W9's first half: the two decisions inside
# harness-verify-provenance! that no one-source manifest can witness -- the
# split character and the combining order. Passes 22 to 25 pack their verify
# command through BYTE_MACHINE_EXPECT_COMMAND, whose | packing forbids a
# multi-source manifest, so this pass runs the lane command bare instead:
# its baseline is a passing provenance run (exit 0), and each catchable
# mutation turns that into the mismatch refusal (exit 3), with no wrapper
# needed. Its manifest deliberately excludes harness.sls, the file both
# mutations edit -- an earlier version included it, and an inert one-byte
# edit nowhere near either decision was enough to trip the identical
# refusal, which proved the catch was not discriminating anything.
#
# Pass 31 is design W9's second half, and needs the opposite manifest.
# harness-provenance-failure!'s single shared exit line is reachable only
# from a run whose own provenance has already failed, so witnessing it means
# deliberately naming harness.sls -- the file this mutation edits -- in the
# very manifest that checks it. What the plan first carried as a structural
# survivor for this constant turned out to be witnessable once self-
# reference was treated as the mechanism rather than the mistake pass 30 had
# to avoid; AGENTS.md is explicit that a decision which can be witnessed
# does not get an EXPECT_SURVIVES.
#
# WHAT THIS SUITE NEEDS FROM ITS ENVIRONMENT
#
# The self-tests assert that the lane declared its execution mode, that the
# registration's test name is visible, and read the fingerprint fixture
# through adapter-file-bytes, so BYTE_MACHINE_EXECUTION_MODE=source,
# BYTE_MACHINE_TEST_NAME, and BYTE_MACHINE_FINGERPRINT_SAMPLE (naming
# test/fixtures/fingerprint-sample.bin) must all be set in this process;
# CTest supplies all three -- see this suite's registration in
# test/CMakeLists.txt. Run by hand without them, the baseline fails before any
# mutation is tried -- which is the designed behaviour, not a bug: an
# unverifiable baseline makes every mutation look caught. Pass 38's baseline
# additionally needs BYTE_MACHINE_GOLDEN_FILE (naming
# test/fixtures/generated-one-byte.golden.sls), which the same ctest
# registration supplies and which execute_process passes through unmodified
# to that pass's own verify command.

cmake_minimum_required(VERSION 3.26)

# See "THIRTY-ONE PASSES..." above. Declared here, rather than only in
# prose, so the count enforced at the bottom of this file is the same text a
# reader checks by eye at the top -- one number to keep in sync, not two
# that can quietly disagree. 25 passes / 60 mutations before the aot task;
# pass 26 adds two (C3, C3b) and passes 27 to 29 add one each, so 25 + 4 =
# 29 passes and 60 + 2 + 1 + 1 + 1 = 65 mutations before this task; W9 adds
# three mutations across two passes, not one -- pass 30 (the split
# character, the combining order) and pass 31 (the exit constant, which
# turned out witnessable after all once its manifest was allowed to be
# self-referential on purpose, superseding the declared survivor the plan
# first carried for it) -- so 29 + 2 = 31 passes and 65 + 3 = 68 mutations.
# Milestone 1 Phase 1's adapter os-table mapping mutation joins the existing
# self-test batch (pass 31, already declared) rather than opening a new pass,
# so passes stay at 31 and 68 + 1 = 69 mutations.
#
# Milestone 1 Phase 2 (semantic core) opens one new pass per executor module,
# each appended after pass 31 below, for three new passes: 31 + 3 = 34.
# Pass 32 is the runtime's THREE decisions -- advance consumes a byte, the
# need-input guard is not a stop, and advance increments the stream offset.
# Pass 33 is the verifier's THIRTEEN decisions: the eight originally witnessed
# (reachability, exact-byte overlap, zero-progress detection, the machine-name
# grammar check, transition missing-target, duplicate-name, undeclared-error-
# reference, and the default-eof membership check) plus five closed by the
# Phase-2 review fix-wave (the schema guard, duplicate-error-declaration, the
# entry site of missing-target, and the node-name and error-code sites of the
# name-portability check -- each a distinct SITES witness of a decision the
# verifier emits). Pass 34 is the interpreter's TWO decisions -- dispatch
# matches the byte to the right case, and an unverified machine is refused.
# So 69 + 3 + 13 + 2 = 87 mutations across the three new passes.
#
# Milestone 1 Phase 3 Slice A adds two passes and twenty mutations: Pass 32
# (runtime) gains four -- v1 variant dispatch, the ABI-version check, the v1
# result-status read, and v1 stickiness -- so 3 -> 7; Pass 35 (the normalizer)
# adds six -- the FNV offset, the FNV prime, the byte-mixing XOR, the entry id,
# the transition sort, and error-code resolution; Pass 36 (the emitter) adds ten
# -- options validation, the compiled-ok verdict, the unverified-render refusal,
# the binding grammar, the three reserved-set members, the advance and reexecute
# loop tails, and the error-arm code. So 34 + 2 = 36 passes and 87 + 20 = 107
# mutations.
#
# Milestone 1 Phase 3 Slice B's D7 task adds one pass, Pass 37 (the identifier
# repertoire and binary-LF proof), with four mutations: the verify-site first-
# char check, the verify-site and compile-site interior-char check (name-char?
# is shared text between verify.sls and compile.sls, so each mutation anchors
# on the definition that follows to stay unique per file), and the emitter's
# final-newline CRLF injection. So 36 + 1 = 37 passes and 107 + 4 = 111
# mutations.
#
# Slice B's D6 task adds one more pass, Pass 38 (deterministic emission
# against the committed golden): the writer's export line loses its exact
# spacing, so the rendered bytes stop matching
# test/fixtures/generated-one-byte.golden.sls and determinism-one-byte-
# tests.sps's own golden comparison fails. One mutation. So 37 + 1 = 38
# passes and 111 + 1 = 112 mutations.
#
# Slice B's property-generator task adds another pass, Pass 39 (the property
# differential is non-vacuous): the dispatch byte test's rendered comparand is
# shifted by one, mod 256, so every generated executor accepts the byte one
# above what it should -- re-anchoring Pass 36's advance-arm-lowering mutation
# against the *property* lane instead of the one fixed machine, so the
# generated-machine differential is proven to notice divergence too. One
# mutation. So 38 + 1 = 39 passes and 112 + 1 = 113 mutations.
#
# Slice B's member-2 drift task adds the last pass, Pass 40 (the drift guard):
# reserved-member-2 drops parser-feed! (grammar-invalid as a binding, so
# valid-binding? behaviour is unchanged and only the drift set-equality
# notices), and reserved-drift-tests.sps's check-equal fails on the mismatch.
# One mutation. So 39 + 1 = 40 passes and 113 + 1 = 114 mutations.
#
# Slice B's placeholder-deletion task (Task 5) retires three passes outright
# instead of adding one: Pass 8 (six mutations -- vector-ness, the length
# check's two failure modes, the tag check, the tag's symbol-vs-fresh-
# allocation identity, and per-call marker allocation), Pass 18 (three
# mutations -- the unchecked argument, the marker-not-value branch, and the
# lookalike-not-singleton outcome), and Pass 19 (one mutation -- the
# ownership pass, the slice's reason for existing). All three mutated files
# left with the M0 placeholder libraries, superseded by the emitter and its
# end-to-end example, which now exercise the real public library boundary
# (spike §11; milestone-1-design.md §6) -- so what these passes proved
# non-vacuous no longer exists to prove anything about. Consistent with the
# matrix's own retirement above, the surviving passes keep their numbers
# rather than closing the gap. So 40 - 3 = 37 passes and
# 114 - (6 + 3 + 1) = 104 mutations.
#
# Milestone 2 Slice ②a's Task 1 (decision 0013) adds one more mutation to the
# existing Pass 32 (the runtime) rather than opening a new pass: parser-feed!'s
# invalid-slice guard now raises a coded &byte-machine-contract condition
# instead of assertion-violation, so the guard's own predicate -- code
# 'invalid-slice, who 'parser-feed! -- is a decision the accept/reject/
# need-input cases above it do not exercise. Passes stay at 37 and
# 104 + 1 = 105 mutations.
#
# Slice ②a's Task 2 replaces the sticky result cache with an explicit lifecycle
# field on the same Pass 32: -1 sticky, +2 lifecycle. The sticky mutation's FIND
# anchor is gone (idempotent re-execution replaces the cache, so setting-vs-not-
# setting it is unobservable); the stopped and error lifecycle arms are each a
# distinct decision (recording the terminal state) that the accept/reject cases
# above them do not otherwise exercise. Passes stay at 37 and
# 105 - 1 + 2 = 106 mutations.
#
# Slice ②a's Task 3 adds parser-reset! to the same Pass 32: three more
# decisions -- restoring the entry state, zeroing the stream offset, and
# returning the lifecycle to ready -- none of which the feed-path mutations
# above exercise (they run before any reset call exists). Passes stay at 37
# and 106 + 3 = 109 mutations.
#
# Each of the three reset mutations below is individually caught by its own
# named EXPECT_OUTPUT_MATCHES check for the right reason: does-not-restore-
# entry by "re-parses from entry" (a status check), does-not-zero-offset by
# "offset zeroed then advanced by one", and does-not-return-to-ready by
# "ready after reset". That per-mutation correctness does NOT mean the three
# checks are mutually isolated, though. Under does-not-restore-entry, the
# offset check also fails: observing a zeroed offset requires re-parsing
# from the entry state (the alternative -- reading the offset directly --
# has no public parser-offset accessor), and that re-parse itself depends on
# `current` having been restored; with `current` left at the stop terminal,
# the re-feed hits it and returns without advancing, so the offset comes
# back 0 instead of the expected 1. The offset check is therefore not an
# exclusive witness of offset-zeroing on this one-byte stub machine -- it
# also (correctly) reacts to a broken entry-restore. The lifecycle check is
# unaffected by the other two mutations, so only this one pair overlaps.
#
# Milestone 2 Slice ②b-1's Task 1 (decision 0011, the finish node + §16.2 EOF
# verification) adds three more decisions to the same Pass 33 rather than
# opening a new pass: non-eof-into-finish (a byte edge must not target a
# finish terminal), eof-reachable-stop (an eof-target chain must not reach a
# stop terminal), and eof-zero-progress-cycle (an eof-target chain must not
# cycle). None of the existing Pass 33 mutations above reach pass-eof-
# execution or eof-terminal, which did not exist before this task. Passes
# stay at 37 and 109 + 3 = 112 mutations.
#
# Slice ②b-1's Task 2 (parser-finish! + eof-target execution through the
# interpreter) adds one more decision to the existing Pass 34 (the interpreter
# now reports a finish node as kind 'finish, which parser-finish! branches on)
# and two more to the existing Pass 32 (the runtime): an exhausted dispatch
# taking its eof-target, and a dispatch with no eof-target routing to the
# machine's default-eof error. No new pass opens -- parser-finish! and the
# `finish` kind are new decisions inside modules both passes already cover.
# Passes stay at 37 and 112 + 1 + 2 = 115 mutations.
#
# A code-review fix to Task 2 adds one more mutation to the same Pass 32: the
# `finish` arm parser-feed-op! itself owns (§12.2 finished x feed! -- a parser
# already parked at a finish node re-fed returns finished, consuming zero) had
# a functional test but no witnessing mutation. Passes stay at 37 and
# 115 + 1 = 116 mutations.
#
# Milestone 2 Slice ②b-2's Task 1 (the dormant /v2 runtime machinery) adds two
# more decisions to the same Pass 32, both witnessed by the new /v2 stub group
# in runtime-tests.sps: parser-finish-v2! must drive `exec` with finish? #t
# (not #f), and the /v2 constructor's ABI guard must refuse a version other than
# the literal 2. The existing "a v1 machine is driven down the op path" mutation
# is re-anchored in place (parser-feed!'s `if` became a three-way `case` when the
# /v2 variant landed) -- same decision, same count, so it neither adds nor drops
# a mutation. Passes stay at 37 and 116 + 2 = 118 mutations.
#
# Slice ②b-2's Task 2 (the generation flip) adds one mutation to Pass 35 (the
# normalizer) and three to Pass 36 (the emitter). Pass 35 gains the dispatch
# default-eof encoding: the resolved eof routing is now hashed, so dropping the
# default-eof code from the canonical bytes moves the (re-baselined) one-byte
# golden. Pass 36 gains the three new emitter decisions, each witnessed by a
# finish-node fixture (eof-fin) added to compile-tests.sps: the finish terminal
# arm (renders 'finished, not 'stopped), the exhausted-dispatch eof branch (emits
# the resolved default-eof code), and the finish? guard (the exhausted dispatch
# branches on finish?, not a constant). Passes stay at 37 and 118 + 1 + 3 = 122
# mutations.
#
# Slice ②b-2's whole-branch review (item d) adds one more mutation to Pass 35
# (the normalizer): Task 2's default-eof mutation above witnesses only the
# DEFAULT eof-encode arm (tag 1 + code symbol), reached by the one-byte machine.
# The NODE arm (tag 0 + u32be routed node id) had no golden and no mutation
# because no machine in the SPEC lane routed eof to a named node. normal-ir-
# tests.sps now pins a second golden over the shared eof-machine (s0/s1 both
# route eof to named nodes), so dropping the routed node id from the encoding
# moves that node-routing golden and its fingerprint case catches it. Passes
# stay at 37 and 122 + 1 = 123 mutations.
#
# Milestone 2 Slice ③'s Task 1 (the pause node in the source IR + verifier)
# adds five more decisions to the existing Pass 33 (the verifier) rather than
# opening a new pass: a pause continuation is an out-target for both name
# resolution and reachability (node-out-targets), eof-terminal walks a pause
# continuation instead of stopping at it, a byte-reachable pause into a finish
# node is rejected (§16.2:908), a pause continuation joins the reexecute
# zero-progress walk (a pause consumes no input), and a byte-reachable pause's
# continuation chain is itself checked as an EOF path (§16.2:909). The
# existing zero-progress-detection mutation is re-anchored in place (its guard
# widened to admit pause nodes), same decision and count, so it neither adds
# nor drops a mutation. Passes stay at 37 and 123 + 5 = 128 mutations.
#
# Task 1's whole-branch review found two of those five decisions unwitnessed
# and adds one mutation each, still on Pass 33: the PASS 5 filter guard's
# `(pause-node? n)` disjunct (no fixture exercised a zero-width cycle with no
# byte-dispatch node in it until a second check was added to the existing
# pa->pb->pa EOF-pause-cycle fixture), and the D4(b)/(d) byte-reachability
# gate shared by both new pass-eof-execution checks (witnessed at only one
# of its two call sites -- the other's effect is masked by a pre-existing,
# ungated check that already emits the identical diagnostic code, so
# dropping the gate there is not caught at all; see the two mutations' own
# comments for the measurement). Passes stay at 37 and 128 + 2 = 130
# mutations.
#
# Slice ③'s Task 2 (runtime lifecycle: the full §12.2 operation matrix,
# parser-resume!, the D1 sticky short-circuit) adds ten decisions to the
# existing Pass 32 (the runtime) rather than opening a new pass: parser-
# resume!'s two acks and its own prohibited-cell else arm (three), the newly-
# prohibited feed and finish rows (two), the feed-side stored-error read
# (one), the feed and EOF pause arms' lifecycle mapping and current-parking
# (three), and the sticky-stopped row's consumed field (one). Four pre-
# existing mutations are textually broken by Step 3's refactor and re-
# anchored in place, same decision and count each, so they neither add nor
# drop a mutation -- see each one's own comment for what moved and why.
# AGENTS.md's exit-path rule (three new raise sites, plus a short-circuit that
# bypasses executor arms four mutations above relied on reaching) requires a
# whole-pass review, not just confirming the four re-anchors still discrim-
# inate: it found three more decisions this task's own new code introduced
# with no witness at all -- parser-finish-op!'s plain error arm (unreachable
# by any fixture before the pause-op stub's s1 -> 'trunc), and the /v2 finish
# path's own error-store and pause arms (no /v2 fixture re-read a stored
# value or reached a pause state) -- each closed with one more mutation. A
# fourth near-miss, the default-eof arm's OWN store (as opposed to its
# routing, re-anchored above), turned out already witnessed by the plan's own
# ②b-2-carry case, so it is one dedicated mutation, not a gap needing a new
# fixture. Passes stay at 37 and 130 + 10 + 4 = 144 mutations.
#
# A subsequent review of Task 2's 14 additions found the implementation
# itself correct but seven of their EXPECT_OUTPUT_MATCHES signatures
# substring-vacuous: harness.sls's FAIL-CONTEXT line prints unconditionally
# on every recorded failure and contains " backend=chez", so bare "ack" (a
# substring of "backend") was satisfied by any failure at all, not the one it
# named -- the two resume-ack mutations and the feed-pause mutation used it.
# Bare "lifecycle" and "consumed" are not vacuous under that same mechanism,
# but both collide with unrelated group/case names elsewhere in this file
# ("one-byte parser lifecycle", "parser-lifecycle tracks ready -> terminal")
# or with several other check labels ("consumed" alone names eight), so
# neither pins the decision it claims to. All seven (and the default-eof
# store mutation's "stored error value", a substring of the feed-side store
# mutation's own "feed-stored error value") are re-pinned in place to their
# owning case's own words; no FIND/REPLACE changed, so this does not move the
# count. The same review found two more decisions this task's own code left
# with no witness: parser-feed!'s finished sticky arm (no fixture repeated a
# feed once lifecycle was already 'finished) and the error sticky arm's
# `next` field (both existing witnesses fed from a zero start, so `start`,
# the literal 0, and (parser-offset parser) were indistinguishable) -- each
# closed with a new runtime-tests.sps case and its own mutation. A third
# finding, parser-reset!'s stored-error clear, is genuinely unobservable
# through the public API (parser-stored-error is unexported and both its
# read sites require lifecycle = 'error, which reset overwrites to 'ready in
# the same call) and is declared EXPECT_SURVIVES rather than left
# undeclared. Passes stay at 37 and 144 + 3 = 147 mutations.
#
# A whole-branch cleanup pass over Slice 3 closes two more gaps and re-pins
# three signatures that were already catching their mutant for the right
# reason but not provably a UNIQUE one. Pass 33 gains one mutation: the
# D4(d) byte-reachability gate's second call site (the eof-terminal-chain
# check), left uncaught by verdict above, is now witnessed by ATTRIBUTION --
# two new checks in the pa->pb->pa fixture assert the eof-zero-progress-cycle
# diagnostic's NODE, not just its code, and ungating this site puts a
# redundant copy on pa that only those checks see. Pass 32 gains one
# mutation: parser-feed!'s finished sticky arm, witnessed above for its
# field values, gets a second mutation for its own existence (whole-clause
# deletion), declared EXPECT_SURVIVES and measured directly -- the 'op
# executor reaches the identical result tuple from `current` regardless, and
# neither other variant exercises the path. Neither addition opens a new
# pass. The same review re-pinned three EXPECT_OUTPUT_MATCHES values: the
# resume-ack mutation's "acks feed-ready and reopens feed: ack" named a
# downstream consequence rather than the decision itself, re-pinned to the
# case that states the decision directly; the EOF-pause mutation's "resumes
# to finish-ready: lifecycle" was a prefix of two sibling checks in its own
# case, extended into the measured detail to become exact; and "sticky
# consumed zero" -- the one recent pin with no case prefix, because its
# case's own name ends in a parenthesised section number a regex cannot
# match literally -- is extended into its own measured detail instead, for
# the same exactness the case-prefix gives its siblings. No FIND/REPLACE
# changed in any of the three, so none of this moves the count. Passes stay
# at 37 and 147 + 1 + 1 = 149 mutations.
#
# Milestone 2 Slice ③'s Task 3 (the interpreter pause kind + shared pause-
# machine fixture + pause-interpret lane) adds the last pass, Pass 41 (the
# interpreter's two pause decisions): a pause node's own kind, unreachable by
# any earlier SPEC lane because no fixture before this task's pause-machine
# built a pause-node?, and the pause-target message resolving to the pause
# node's continuation rather than the pause node itself. Two mutations. So
# 37 + 1 = 38 passes and 149 + 2 = 151 mutations.
#
# Slice ③'s Task 4 (the pause node in the normalizer + emitter) adds three
# more mutations to the existing Pass 35 and two more to the existing Pass 36
# rather than opening a new pass: the normalizer's lower arm (a pause's
# resolved continuation id, not its own), its encode arm (tag 4 + u32be
# continuation id hashed into the fingerprint), and the encode arm's tag
# value alone (4 -> 3, colliding with finish's own tag byte), and the
# emitter's pause arm (renders the `paused` outcome) and its next-state (the
# continuation target, not the pause node's own id). Each is witnessed in its
# own SPEC lane's program: normal-ir-tests.sps gains a "pause normalization"
# group (a structural case plus a measured-then-pinned fingerprint golden);
# compile-tests.sps gains a third inline fixture (the eof-fin precedent)
# asserting both rendered pause arms. The lower-arm mutation is pinned to the
# structural "p1 target" check rather than the fingerprint it also disturbs as
# a side effect, the more precise of its two witnesses. The two encode-arm
# mutations were originally pinned to the fingerprint golden's own check
# label, "pause fingerprint", on the argument that a label unique in the file
# needs no numeral. The Slice ③ pin re-audit measured that label's FAIL line
# in the output of seven OTHER mutants of the same pass -- every
# fingerprint-affecting mutation in the lane moves the pause golden too -- so
# each now carries its own measured "got" value, which is what actually
# separates the siblings; the two emitter mutations were likewise re-pinned
# to measured check-equal details after compile-tests.sps's content-blind
# `check` probes were replaced. See each mutation's own comment. Passes stay
# at 38 and 151 + 5 = 156 mutations.
#
# Slice ③'s Task 6 (the property generator learns eof/finish/pause: a
# generated machine's entry can now route eof to a finish node `done`, and a
# byte case can now target an explicit pause `pausep`; the differential
# driver -- property-differential-tests.sps -- now stays live across a
# pause/resume/finish schedule instead of feeding one byte to a throwaway
# parser) joins the existing Pass 39 (Slice B) with three mutations, rather
# than opening a new pass: Pass 39 already runs this same program under this
# same verify command (it re-anchors Slice A's advance-arm-lowering mutation
# against the property lane), so a second reset/baseline/re-stage for the
# identical spec would only pay the suite's most expensive lane's cost twice
# for no new discrimination -- the pattern this slice's Tasks 1, 2 and 4
# already established, each joining an existing pass rather than opening one.
# (Review caught an earlier draft of this that opened "Pass 42" instead,
# reasoning from the plan's own "Pass 39" citation and the unrelated fact
# that Pass 41 above is this slice's one genuinely new pass; passes 39 and
# 40 are M1 Slice B's, never claimed by this slice's earlier tasks, so
# joining 39 was available and is what this task's mutations do now.)
#
# The generator's third (reachability) constraint -- gen-machine adds
# `pausep` only when gen-cases reports some case actually drew it -- gets no
# dedicated mutation, consistent with machine-gen.sls carrying none for its
# two pre-Slice-③ constraints either (the target-`start`-forces-`advance`
# rule, the first-case `stop` pin): breaking that gate manufactures an
# unreachable node, which the property lane's own "machine N verifies"
# checks already fail on every build, so a dedicated mutation would be
# redundant with a check the lane already runs. The eof and pause draws
# THEMSELVES are a different matter -- hard-wiring either one's coin to a
# constant reproduces a machine shape `verify-machine` still accepts (the
# pre-Task-6 generator ran green under this same lane, 81 checks / 0
# failures, before either draw existed), so no existing check fails and both
# draws needed their own new anti-vacuity assertions before they could be
# witnessed at all. property-differential-tests.sps now carries both:
# paused-count (added with the pause draw) and finished-count (added by this
# fix, mirroring it), each asserted >= 1 across the seed's 40 machines.
#
# The first new mutation breaks resume-pair! (property-differential-
# tests.sps), the one place either side's parser-resume! is called, shared
# by the feed-pause and finish-pause loops: REPLACE swaps the two real calls
# for a pair of hardcoded acks, so neither parser's lifecycle actually
# leaves paused-feed. The very next operation the driver runs on them --
# feed-loop!'s post-resume re-feed of the slice's remainder -- lands on
# runtime.sls's own lifecycle-violation guard, which the driver does not
# catch; harness-case's own guard catches it instead and records it as
# "case raised". Measured: `code: lifecycle-violation who*: parser-feed!
# detail: (paused-feed feed)`. Pinned to "paused-feed feed" -- the measured
# detail tuple, metacharacter-free and specific to this exact lifecycle/op
# pair, printed by nothing else in this program's output (a bare
# "lifecycle-violation" would also match a violation raised for a different
# reason, so the detail is the more precise of the two).
#
# The second new mutation targets the pause draw's own probability line in
# machine-gen.sls: pause-drawn? is hard-wired to #f, so no case is ever
# offered `pausep` as a target and no generated machine ever includes one.
# paused-count's own assertion fails, at 0, exactly when this line is
# mutated. Pinned to "observes a pause", the assertion's own words and
# otherwise unused in this program.
#
# The third new mutation targets the eof draw's own probability line, the
# same way: eof? is hard-wired to #f, so no dispatch node's eof-target is
# ever `done` and no generated machine ever reaches `finished`.
# finished-count's own assertion fails, at 0, exactly when this line is
# mutated. Pinned to "idle-completion finish", the assertion's own words and
# otherwise unused in this program.
#
# So passes stay at 38 and 156 + 3 = 159 mutations.
set(EXPECTED_PASSES 38)
set(EXPECTED_MUTATIONS 159)

# --- Slice ③ pin re-audit: what an EXPECT_OUTPUT_MATCHES can and cannot say --
#
# EXPECT_OUTPUT_MATCHES is an UNANCHORED regex over the verify command's
# stdout+stderr, so a pin matching text that every failing run prints is a
# bare nonzero-exit catch wearing a disguise. Text that is unconditional in
# a harness lane: the FAIL-CONTEXT line's `backend=`, `mode=`, `os=`,
# `architecture=`, `machine-type=`, `artifacts=`, and the values of
# BYTE_MACHINE_TEST_NAME / BYTE_MACHINE_TEST_TMPDIR that
# byte_machine_add_test supplies (so `scheme`, `mutation`, `harness`, `cmake`
# and `direct` are all unconditional here); and the summary line's `status=`,
# `cases=`, `checks=`, `failures=`. The FAIL grammar is
#   byte-machine-harness: FAIL <group>.<case>: <what> -- <detail>
# so a sound pin resolves to exactly ONE (case, check) pair. MATCHES is a real
# regex: `(` `)` `.` are metacharacters, so a case name carrying a
# parenthesised section reference cannot be used as a tail unescaped.
#
# All 34 of this slice's pins were re-judged against the captured output of
# every other mutation in their own lane -- 797 pair judgments through
# byte_machine_mutation_verdict, part of a 2008-pair sweep over all 89 pinned
# mutations in the six lanes this slice touched. Every pin whose match landed
# on a DIFFERENT
# (case, check) than its own -- five, all in Pass 33's pause group, each
# pinned to a bare diagnostic CODE rather than to a check -- was re-anchored,
# and four more that shared a check with a sibling were extended with the
# measured detail that separates them (Pass 32's two paused-row refusals, Pass
# 35's two pause-fingerprint mutations). Pass 36's two emitter mutations
# needed the SPEC to change, not the pin: see that pass's own comment.
#
# Twelve pairs remain where one mutation's whole failure set is a SUBSET of a
# broader sibling's, with byte-identical details -- a decision subsumed by a
# kill-switch above it, not an under-anchored pin. No output text can separate
# these, and each is still caught at the check that names its own decision:
#   p32 resume-on-paused-feed  < feed-pause maps to paused-feed
#   p32 resume-on-paused-finish < EOF pause parks paused-finish
#   p32 /v2 finish error stored < /v2 finish drives exec with finish? true
#   p33 pause continuation out-target      < missing-target never reported
#   p33 eof-terminal chains through pause  < eof-target cycle is a finish
#   p33 pause joins zero-progress walk     < zero-progress never fires
#   p33 pause-only zero-progress cycle     < zero-progress never fires (also
#                                            < pause joins the walk)
#   p33 byte-reachable pause chain is EOF  < EOF-reachable stop accepted
#   p33 byte-reachability gate (:908)      < pause continuation out-target
#   p39 pause draw / eof draw              < inverted dispatch byte test
# The last pair is the only one with a cheap remedy, and it was declined
# deliberately: property-differential-tests.sps counts a pause only when BOTH
# sides agree they paused, so a compile.sls divergence zeroes the same two
# anti-vacuity counters the generator mutations zero. Counting the oracle's
# own pause instead would separate them, but it would weaken what the guard
# asserts (that the LANE drove a real agreeing pause) for a pin-specificity
# gain, and both mutations are already caught at their own checks.

include("${CMAKE_CURRENT_LIST_DIR}/MutationRunner.cmake")

get_filename_component(SOURCE_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)

if(DEFINED ENV{BYTE_MACHINE_TEST_TMPDIR})
  set(WORK_DIR "$ENV{BYTE_MACHINE_TEST_TMPDIR}")
else()
  set(WORK_DIR "${SOURCE_ROOT}/build/scheme-mutation")
endif()
set(STAGE_DIR "${WORK_DIR}/stage")

# The object guard the Chez launcher requires. It lives outside the stage
# because the stage is removed and rebuilt on every run, and the launcher
# refuses to start if the guard is missing.
set(GUARD_DIR "${WORK_DIR}/guard")
file(REMOVE_RECURSE "${GUARD_DIR}")
file(MAKE_DIRECTORY "${GUARD_DIR}")

# Two more guards, for the two refusals that need a guard directory in a state
# the build never otherwise produces. The absent one is named and deliberately
# not created.
set(DIRTY_GUARD_DIR "${WORK_DIR}/guard-dirty")
file(REMOVE_RECURSE "${DIRTY_GUARD_DIR}")
file(MAKE_DIRECTORY "${DIRTY_GUARD_DIR}")
file(WRITE "${DIRTY_GUARD_DIR}/stray-object.so"
  "Not a compiled library. Its only job is to stop this directory being empty.\n")

set(ABSENT_GUARD_DIR "${WORK_DIR}/guard-absent")
file(REMOVE_RECURSE "${ABSENT_GUARD_DIR}")

if(NOT BYTE_MACHINE_CHEZ_EXECUTABLE)
  message(FATAL_ERROR
    "byte-machine-mutation: BYTE_MACHINE_CHEZ_EXECUTABLE was not passed in. "
    "This suite runs a real execution lane, so it cannot be verified under the "
    "no-scheme preset; the registration must forward the discovered path.")
endif()

# src is staged whole: --library-root arguments throughout this file resolve
# every product library through it, each of which now owns its own text
# directly (decision 0006). There is no separate wrapper/body split left to
# keep reachable together; staging the one directory every library lives
# under is enough.
set(BYTE_MACHINE_MUTATION_STAGE_DIRS
  "cmake" "test/support/cmake" "test/support/harness" "test/support/launchers"
  "src" "test/common")

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-self-tests.sps")

set(RUNNER test/support/harness/byte-machine/test/harness.sls)
set(CHEZ_ADAPTER test/support/harness/byte-machine/test/harness.sls)
set(LAUNCHER test/support/launchers/chez-source.ss)

# --- Assertions ------------------------------------------------------------

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.sps
  LABEL "runner: check passes whatever it is given"
  FIND [[(define (check what value)
  (harness-count-check!)
  (if value]]
  REPLACE [[(define (check what value)
  (harness-count-check!)
  (if #t]])

# Narrower than the mutation above, and not covered by it: `check` still returns
# #f and still counts the check, but the failure is never recorded. A suite
# built on this would print no FAIL line, count no failure, and exit 0 while
# every assertion in it "failed".
byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.sps
  LABEL "runner: a false check counts but records no failure"
  FIND [[      (begin (harness-record-failure! what "expected a true value") #f)))]]
  REPLACE [[      #f))]])

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.sps
  LABEL "runner: check-equal compares identity instead of structure"
  FIND [[  (if (equal? actual expected)]]
  REPLACE [[  (if (eq? actual expected)]])

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.sps
  LABEL "runner: check-not-equal is no longer the inverse"
  FIND [[  (if (equal? actual unexpected)]]
  REPLACE [[  (if (not (equal? actual unexpected))]])

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.sps
  LABEL "runner: check-fail records nothing"
  FIND [[  (harness-record-failure! what detail)
  #f)]]
  REPLACE [[  #f)]])

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.sps
  LABEL "runner: check-raises accepts a thunk that returned normally"
  FIND [[      ((eq? (car outcome) 'returned)]]
  REPLACE [[      ((eq? (car outcome) 'never-happens)]])

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.sps
  LABEL "runner: a failure never marks its case as failed"
  FIND [[  (set! harness-current-case-failed #t)]]
  REPLACE [[  (set! harness-current-case-failed #f)]])

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.sps
  LABEL "runner: a duplicate case id is silently accepted, making one registration unreachable"
  FIND [[      ((harness-member? id harness-case-ids)]]
  REPLACE [[      (#f]])

# harness-record-error! takes one argument where harness-record-failure! takes
# two, so the "case raised" label goes with the call it belongs to: keeping it
# would mutate the arity rather than the classification, and the arity violation
# is caught by a different assertion than the one this line claims to exercise.
byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.sps
  LABEL "runner: a raise inside a case is recorded as an error rather than that case's failure"
  FIND [[                   (harness-record-failure!
                    "case raised"
                    (adapter-describe-condition (car (cdr outcome))))]]
  REPLACE [[                   (harness-record-error!
                    (adapter-describe-condition (car (cdr outcome))))]])

# harness-group and with-cleanup re-raise through identical text, so each of the
# two mutations below anchors on the line above the `if` -- the group-stack pop
# for one, the tail of the cleanup report for the other. They were one SITES 2
# mutation until a review showed what that concealed: a multi-site mutation is
# "caught" as soon as any one site is caught, and only the cleanup site was.
# harness-group pops its name off the stack *before* it re-raises, so deleting
# the re-raise still leaves every prefix correct; the group merely returns the
# condition instead of throwing it, and the one self-test that raises inside a
# group asserted only that no prefix was left behind. Split, each re-raise has
# to be witnessed on its own, and the group one stayed uncaught until
# "a group re-raises its body's condition" was added to the self-tests.
byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.sps
  LABEL "runner: a group swallows its body's condition instead of re-raising it"
  FIND [[    (set! harness-group-stack (cdr harness-group-stack))
    (if (eq? (car outcome) 'raised)
        (raise (car (cdr outcome)))]]
  REPLACE [[    (set! harness-group-stack (cdr harness-group-stack))
    (if #f
        (raise (car (cdr outcome)))]])

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.sps
  LABEL "runner: with-cleanup swallows its body's condition instead of re-raising it"
  FIND [[             (adapter-describe-condition (car (cdr cleanup-outcome)))))))
    (if (eq? (car outcome) 'raised)
        (raise (car (cdr outcome)))]]
  REPLACE [[             (adapter-describe-condition (car (cdr cleanup-outcome)))))))
    (if #f
        (raise (car (cdr outcome)))]])

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.sps
  LABEL "runner: cleanup never runs"
  FIND [[    (let ((cleanup-outcome (guard (e (#t (list 'raised e)))
                             (list 'value (cleanup)))))]]
  REPLACE [[    (let ((cleanup-outcome (list 'value #f)))]])

# FIND used to open on `(cond (...` itself, back when the error clause was the
# cond's first clause. Task 8 gave harness-exit-status a new first clause --
# provenance outranking both -- which pushed the error and failure clauses one
# line down, onto their own matching indentation; anchoring on those two lines
# alone is what survives a further clause ever being added the same way again.
byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.sps
  LABEL "runner: a failure outranks a harness error in the exit status"
  FIND [[        ((> harness-error-count 0) harness-status-harness-error)
        ((> harness-failure-count 0) harness-status-failed)]]
  REPLACE [[        ((> harness-failure-count 0) harness-status-failed)
        ((> harness-error-count 0) harness-status-harness-error)]])

# --- Probes ----------------------------------------------------------------

# The FIND consumes the whole line, its trailing newline included, so the
# replacement carries a newline of its own; without one it would swallow the
# following line as well and delete more than it names. An inert comment rather
# than an empty replacement, because an explicitly empty single-value argument
# is left undefined by cmake_parse_arguments at the 3.26 floor this project
# declares (CMP0174 is 3.31+), and REPLACE is required.
byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.sps
  LABEL "runner: a probe does not restore the state it displaced"
  FIND [[        (harness-restore-state! saved)
]]
  REPLACE [[        ;; deleted
]])

# Anchored on the preceding line so the pattern is pinned to the tail of
# harness-clear-state! rather than to any future assignment of the same
# variable: harness-set-filter! and harness-begin both assign harness-filter,
# and a bare pattern would start matching one of them after an innocuous edit.
byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.sps
  LABEL "runner: a probe inherits the ambient filter and skips its own cases"
  FIND [[  (set! harness-failures '())
  (set! harness-filter #f))]]
  REPLACE [[  (set! harness-failures '()))]])

# --- Empty selection -------------------------------------------------------

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.sps
  LABEL "runner: an empty selection is not diagnosed"
  FIND [[    ((> case-count 0) #f)]]
  REPLACE [[    ((> case-count -1) #f)]])

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.sps
  LABEL "runner: a filtered-out run is diagnosed as having registered nothing"
  FIND [[    ((> skipped-count 0)]]
  REPLACE [[    (#f]])

# --- Output ----------------------------------------------------------------

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.sps
  LABEL "runner: probe output suppression is removed"
  FIND [[(define (harness-quiet?) (> harness-probe-depth 0))]]
  REPLACE [[(define (harness-quiet?) #f)]]
  EXPECT_SURVIVES
    "suppression changes only what is printed, never a counter or a status, so no assertion can observe it from inside the process; it is covered by the manual check in the implementation plan's Task 5 step 9, and its real cost -- a log that teaches readers to ignore FAIL lines -- is not machine-checkable")

# The other two print-only decisions, and the same argument. The adapter
# protocol exposes no output-capture service, and the runner may not reach
# past its protocol for one -- so the harness has no way to read
# back what it printed -- and this suite judges a mutation by the verify
# command's exit status, so an output difference is invisible to it whatever
# lane it runs.
# byte-machine.harness.verbose.chez.source closes the half that can be closed:
# it runs a real program with the variable set, so the path is executed and a
# break that raises is caught. What no layer checks is that the line was
# printed. Spec section 5.3 records the manual check that does.
byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.sps
  LABEL "runner: the value read for BYTE_MACHINE_TEST_VERBOSE is discarded"
  FIND [[    (set! harness-verbose (if (and v (not (string=? v ""))) #t #f)))]]
  REPLACE [[    (set! harness-verbose #f))]]
  EXPECT_SURVIVES
    "the verify command that judges this mutation does not set the variable, so both runs take the same branch -- harness-verbose ends up #f either way -- and the two are byte-identical, not merely indistinguishable by exit status. In a process that does set it the whole difference is one printed line per passing case: no counter, no case count, no status moves, and this suite judges by exit status. byte-machine.harness.verbose.chez.source proves the read happens and does not raise; that the value read is honoured is covered by the manual check recorded in spec section 5.3 -- either self-tests lane with BYTE_MACHINE_TEST_VERBOSE=1 prints one pass line per case and none without it")

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.sps
  LABEL "runner: a passing case is never announced under verbose"
  FIND [[                 (if harness-verbose
                     (harness-say (string-append "byte-machine-harness: pass " id))))]]
  REPLACE [[                 #f)]]
  EXPECT_SURVIVES
    "the pass line is the only thing this branch produces, and a line that is not printed changes no counter and no status; byte-machine.harness.verbose.chez.source still proves the branch is reached and does not raise, but only a reader of the log can see the line itself, which is the manual check recorded in spec section 5.3")

# --- The Chez adapter's export list ----------------------------------------

byte_machine_mutation(
  FILE ${CHEZ_ADAPTER} SPEC harness-self-tests.sps
  LABEL "chez adapter: an exported adapter name is dropped"
  FIND [[    adapter-os adapter-architecture adapter-execution-mode]]
  REPLACE [[    adapter-architecture adapter-execution-mode]])

# Not every export is load-bearing, and pretending otherwise would be the more
# comfortable lie. harness-summary, harness-empty-selection-error, and
# harness-failure-context are used only from the runner section of harness.sls
# itself, inlined there by the include collapse (decision 0006); an internal
# reference resolves against the definition, never through the export list.
# Dropping any of the three therefore changes nothing any lane can observe --
# and with one adapter there is no second export list to keep in step with, so
# the export is a tripwire, not a contract. Recorded here so the blind spot is
# asserted rather than remembered, and so the day one of them acquires a
# caller outside the library, this line fails.
byte_machine_mutation(
  FILE ${CHEZ_ADAPTER} SPEC harness-self-tests.sps
  LABEL "chez adapter: an export used only inside the runner section is dropped"
  FIND [[    harness-begin harness-finish harness-summary harness-exit-status]]
  REPLACE [[    harness-begin harness-finish harness-exit-status]]
  EXPECT_SURVIVES
    "harness-summary, harness-empty-selection-error, and harness-failure-context are referenced only from the runner section of harness.sls itself; an internal reference resolves inside the library whatever the export list says, so no lane imports the three and none can notice one going missing")

# Load-bearing, unlike the three names in the survivor above: the fingerprint
# library now reads files itself (byte-machine test fingerprint), so
# harness-fingerprint-file no longer reaches adapter-file-bytes at all. The
# self-tests' own direct call -- reading the fingerprint sample fixture
# through it -- is the only thing left that makes dropping this export
# visible.
byte_machine_mutation(
  FILE ${CHEZ_ADAPTER} SPEC harness-self-tests.sps
  LABEL "chez adapter: adapter-file-bytes is dropped from the export list"
  FIND [[    adapter-value->string adapter-describe-condition adapter-file-bytes]]
  REPLACE [[    adapter-value->string adapter-describe-condition]])

# The line these two retired mutations targeted is gone with the include
# mechanism; what replaced it is deliberate narrowing, measured inert.
byte_machine_mutation(
  FILE ${LAUNCHER} SPEC harness-self-tests.sps
  LABEL "launcher: source-directories is left at Chez's default instead of emptied"
  FIND [[(source-directories '())]]
  REPLACE [[;; deleted]]
  EXPECT_SURVIVES
    "measured inert (decision 0006, extending 5b's C3b): no include form exists anywhere, library resolution runs through library-directories, and no lane's outcome differs between an empty source path and Chez's default; the line is kept as narrowing, not as behavior")

# --- The adapter's os-table -------------------------------------------------

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.sps
  LABEL "adapter: an os-table row maps to the wrong name"
  FIND [[("osx" . "darwin")]]
  REPLACE [[("osx" . "linux")]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "tarm64osx os")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Second pass: harness-begin's read of the environment filter -----------
#
# The self-tests cannot witness this one. They check the normalisation rule
# directly, on the pure function, but the read itself only matters to a process
# whose ambient filter came from outside it -- and a suite cannot set its own
# environment from inside the portable subset, nor read back the filter the
# runner stored. The empty-selection lane is that process: it registers one case
# its filter cannot select and must exit 2. Break the read and the case runs, the
# suite exits 0, and the exact-status helper says so.
#
# The helper is what makes exit 2 the passing outcome here, which the mutation
# runner requires: it judges "caught" as a nonzero result from the verify
# command, so the verify command must be one that exits 0 when the lane is
# healthy.

byte_machine_mutation_reset()

string(JOIN "|" EMPTY_SELECTION_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-empty-selection.sps")

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${CMAKE_COMMAND}" -E env
  "BYTE_MACHINE_TEST_FILTER=no-case-has-this-in-its-name"
  "${CMAKE_COMMAND}"
  "-DBYTE_MACHINE_EXPECT_EXIT=2"
  "-DBYTE_MACHINE_EXPECT_COMMAND=${EMPTY_SELECTION_COMMAND}"
  -P "${STAGE_DIR}/cmake/ByteMachineExpectExit.cmake")

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-empty-selection.sps
  LABEL "runner: harness-begin ignores BYTE_MACHINE_TEST_FILTER"
  FIND [[  (set! harness-filter
        (harness-normalize-filter
         (adapter-environment-variable "BYTE_MACHINE_TEST_FILTER")))]]
  REPLACE [[  (set! harness-filter #f)]])

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Third pass: the failure counter itself ---------------------------------
#
# Declared under the self-tests lane first, and observed UNCAUGHT there: with
# harness-record-failure! no longer counting, a self-test that fails prints its
# FAIL line, marks its case failed, and leaves the exit status at 0. The
# mutation disarms the mechanism every assertion reports through as it commits
# the defect, so no suite written with `check` can witness it -- which is
# precisely the argument the bootstrap lane exists to answer. It judges the
# primitives with raw conditionals, counts its own failures, and exits by hand.

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-bootstrap.sps")

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-bootstrap.sps
  LABEL "runner: a recorded failure is never counted, so a failing suite exits 0"
  FIND [[  (set! harness-failure-count (+ harness-failure-count 1))]]
  REPLACE [[  (set! harness-failure-count harness-failure-count)]])

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Passes 4 to 5: the launcher's two guard-directory refusals -------------
#
# The launcher decides whether a lane runs at all, and its object guard is the
# sole mechanism that makes `mode=source` an honest claim. Neither refusal can
# be reached by a lane that was set up correctly, so each gets a deliberately
# wrong command line of its own, run through the exact-status helper so that
# exit 2 -- the refusal -- is what a healthy launcher scores.
#
# A third refusal used to live here: a missing required flag, witnessed by
# invoking the launcher with no arguments at all (SPEC named after that
# invocation's own ctest lane, byte-machine.harness.launcher-no-program.chez.source,
# since there was no program on the command line to name). It is gone. Slice 3's
# parse-decision passes below replace it with one mutation per required-flag
# entry, each a strictly more precise witness of the same decision than a
# zero-argument invocation was; keeping both would mean two mutations proving
# the same line, one of them permanently coarser. The retired ctest lane
# itself still runs, unchanged, as a real regression test -- it is just no
# longer this suite's witness.
#
# SPEC names the registered lane rather than a program basename, because the
# witness is a whole invocation and not a program: "passing" means the named
# program never ran.

byte_machine_mutation_reset()

string(JOIN "|" LAUNCHER_ABSENT_GUARD_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--object-guard" "${ABSENT_GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-bootstrap.sps")

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${CMAKE_COMMAND}"
  "-DBYTE_MACHINE_EXPECT_EXIT=2"
  "-DBYTE_MACHINE_EXPECT_COMMAND=${LAUNCHER_ABSENT_GUARD_COMMAND}"
  -P "${STAGE_DIR}/cmake/ByteMachineExpectExit.cmake")

# EXPECT_OUTPUT_MATCHES captures what this mutation actually, verifiably
# produces: with the existence check gone, the very next line calls
# directory-list on a path that does not exist, which Chez itself refuses --
# a real, deterministic consequence of deleting exactly this check, not the
# launcher's own die(). Verified against a real staged run, not guessed; see
# byte_machine_slice3_launcher_pass's header comment below for why the wrapper's
# own exit code (0 or 1) cannot make this distinction by itself.
byte_machine_mutation(
  FILE ${LAUNCHER} SPEC byte-machine.harness.launcher-absent-guard.chez.source
  LABEL "launcher: a guard directory that does not exist is assumed rather than checked"
  FIND [[(if (not (file-directory? object-guard-dir))]]
  REPLACE [[(if #f]]
  EXPECT_OUTPUT_MATCHES "Exception in directory-list")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

byte_machine_mutation_reset()

string(JOIN "|" LAUNCHER_DIRTY_GUARD_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--object-guard" "${DIRTY_GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-bootstrap.sps")

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${CMAKE_COMMAND}"
  "-DBYTE_MACHINE_EXPECT_EXIT=2"
  "-DBYTE_MACHINE_EXPECT_COMMAND=${LAUNCHER_DIRTY_GUARD_COMMAND}"
  -P "${STAGE_DIR}/cmake/ByteMachineExpectExit.cmake")

# The one that matters most: a guard directory that has acquired a file is no
# longer a guard, and the lane would go on reporting mode=source while loading
# whatever was put there.
#
# EXPECT_OUTPUT_MATCHES here is "bootstrap: failures=0", not anything about the
# stray file: with this check gone the launcher does not notice the dirty
# guard at all, so the whole staged bootstrap program runs and passes, ending
# with its own success banner. That is the correct, deterministic consequence
# of deleting exactly this line, verified against a real staged run.
byte_machine_mutation(
  FILE ${LAUNCHER} SPEC byte-machine.harness.launcher-dirty-guard.chez.source
  LABEL "launcher: a guard directory with a file in it is accepted as a guard"
  FIND [[(if (not (null? (directory-list object-guard-dir)))]]
  REPLACE [[(if #f]]
  EXPECT_OUTPUT_MATCHES "bootstrap: failures=0")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Sixth pass: a source lane that compiles what it imports ---------------
#
# Its own guard directory, because this is the one mutation here whose effect is
# to write into one.

byte_machine_mutation_reset()

set(COMPILE_GUARD_DIR "${WORK_DIR}/guard-compile")
file(REMOVE_RECURSE "${COMPILE_GUARD_DIR}")
file(MAKE_DIRECTORY "${COMPILE_GUARD_DIR}")

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--object-guard" "${COMPILE_GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-bootstrap.sps")

byte_machine_mutation(
  FILE ${LAUNCHER} SPEC byte-machine.harness.bootstrap.chez.source
  LABEL "launcher: a source lane is allowed to compile what it imports"
  FIND [[(compile-imported-libraries #f)]]
  REPLACE [[(compile-imported-libraries #t)]]
  EXPECT_SURVIVES
    "deleting the call is provably unobservable -- Chez's own default for compile-imported-libraries is already #f -- so the only mutation with an effect is turning it on, and its entire effect is a file: Chez writes byte-machine/test/harness.so into the object half of the library-directories pair, which is the guard, and it does so after the launcher has already asserted the guard was empty. No single process can see it. The registered lanes can, and do: with compilation on, the first Chez lane to run pollutes the shared object guard and three of the harness preset's tests fail. This suite runs one process per mutation, so what it can prove about this line is only that the line is still there")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Seventh pass: the library-directories pairing ---------------------------
#
# The pairing is the launcher's central mechanism. Chez looks for a library's
# compiled object only in the *object* half of a library-directories pair, so
# pairing the library root with a directory the build keeps empty is the whole
# reason this lane may call itself "source". Three places in the tree assert
# that -- the launcher's own header, test/CMakeLists.txt, and spec section 7.1 --
# and until this pass nothing checked it. `(library-directories (list
# library-root))` left every test green, because no library root in this tree
# has an object beside its source for Chez to prefer.
#
# So this pass builds one, in a library root of its own. A garbage `.so` is not
# enough: Chez silently ignores a file it cannot read as a library, and both the
# pristine and the unpaired run then exit 0 -- an inconclusive experiment, not
# evidence that the pairing does nothing. The object here is genuinely compiled,
# from a copy of the adapter whose `adapter-runtime-name` returns a sentinel,
# and the pristine `.sls` stays beside it so the baseline has real source to
# load. The sentinel is what makes the catch legible: the mutated run fails
# *because the object was loaded*, and says so in its banner, its FAIL-CONTEXT
# line, and its summary, rather than failing for some unrelated reason.
#
# Everything lives under this suite's work directory. The source tree is only
# read, no other pass's guard is touched, and this pass gets an empty guard of
# its own so that a future change to the shared one cannot quietly decide the
# result.
#
# Reached only when a Chez was passed in, the same way every other Chez pass
# here is: this file refuses to start without one, and the registration in
# test/CMakeLists.txt is guarded on the same variable, so `ctest --preset
# no-scheme` never reaches the compile below.

byte_machine_mutation_reset()

set(POISON_DIR "${WORK_DIR}/poisoned-library-root")
set(POISON_ROOT "${POISON_DIR}/root")
set(POISON_SOURCE_DIR "${POISON_DIR}/poisoned-source")
set(POISON_OBJECT "${POISON_ROOT}/byte-machine/test/harness.so")
set(POISON_GUARD_DIR "${WORK_DIR}/guard-poisoned")

file(REMOVE_RECURSE "${POISON_DIR}" "${POISON_GUARD_DIR}")
file(MAKE_DIRECTORY "${POISON_ROOT}/byte-machine/test")
file(MAKE_DIRECTORY "${POISON_SOURCE_DIR}/byte-machine/test")
file(MAKE_DIRECTORY "${POISON_GUARD_DIR}")

# Asserted, not assumed, for the same reason SITES is: if the adapter is
# refactored past this pattern the "poisoned" copy would be a pristine one, the
# mutated run would pass, and the mutation would be reported UNCAUGHT with no
# hint that the poison was the thing that broke.
set(POISON_FIND [[  (define (adapter-runtime-name) "chez")]])
set(POISON_REPLACE [[  (define (adapter-runtime-name) "POISONED-FROM-OBJECT")]])

file(READ "${SOURCE_ROOT}/${CHEZ_ADAPTER}" POISON_PRISTINE)
string(FIND "${POISON_PRISTINE}" "${POISON_FIND}" POISON_AT)
if(POISON_AT EQUAL -1)
  message(FATAL_ERROR
    "byte-machine-mutation: the Chez adapter no longer contains "
    "'${POISON_FIND}', so the object this pass compiles would be an unpoisoned "
    "copy and the library-directories mutation would prove nothing. Update the "
    "pattern rather than dropping it.")
endif()
string(REPLACE "${POISON_FIND}" "${POISON_REPLACE}" POISON_MUTATED "${POISON_PRISTINE}")

# The pristine source goes down first, and the object is written by the
# compile below.
#
# The object is preferred only while it is not older than the .sls beside
# it -- and, transitively, while its imported fingerprint library also
# resolves to a non-stale object (the MEASURED note below). What died with
# the include (decision 0006) is the include-era caveat this paragraph used
# to carry: no STAGED file's mtime participates any more, because the
# library no longer re-resolves harness-runner.scm at load time.
file(WRITE "${POISON_ROOT}/byte-machine/test/harness.sls" "${POISON_PRISTINE}")
file(WRITE "${POISON_SOURCE_DIR}/byte-machine/test/harness.sls" "${POISON_MUTATED}")

# harness.sls now imports (byte-machine test fingerprint) (Task 3 of the
# include collapse), so the object compiled below has a real library
# dependency for the first time. MEASURED, not assumed: Chez's staleness
# check on a compiled library is transitive -- an object is trusted only if
# every library it imports also resolves to a non-stale compiled object, not
# bare source. A minimal two-library reproduction confirmed this directly: an
# importer's freshly compiled object was silently discarded in favour of its
# own pristine source whenever the imported library resolved to source only,
# even though the importer's own root was searched first and its object was
# not stale by itself. Giving fingerprint no compiled object anywhere in this
# pass's roots (the shape the plan called for, reasoning "the second root
# exists only to resolve the fingerprint import") reproduces exactly that:
# the poisoned harness object is silently rejected and the baseline's
# pristine banner prints instead, so the mutation below goes UNCAUGHT. The
# fix is to make POISON_ROOT self-sufficient: a real, non-stale fingerprint
# object beside the poisoned harness object, compiled first so harness's
# object is never older than a library it depends on.
#
# One cross-copy invariant this relies on: the compile below resolves
# fingerprint's import from ${SOURCE_ROOT}/test/support/harness (the
# real source tree, via library-directories), while the verify run further
# down resolves the same import from POISON_ROOT's own copy. Compiling
# against one copy and running against another is safe here only because
# the file(READ)/file(WRITE) pair immediately below makes the two
# byte-identical by construction -- the same guarantee the pristine
# harness.sls copy above already depends on.
file(READ "${SOURCE_ROOT}/test/support/harness/byte-machine/test/fingerprint.sls"
     POISON_FINGERPRINT_PRISTINE)
file(WRITE "${POISON_ROOT}/byte-machine/test/fingerprint.sls" "${POISON_FINGERPRINT_PRISTINE}")

set(POISON_COMPILE_SCRIPT "${POISON_DIR}/compile-poisoned-object.ss")
file(WRITE "${POISON_COMPILE_SCRIPT}"
";; Written by SchemeMutationSuite.cmake, never committed. Compiles the
;; poisoned adapter copy into the library root that holds the pristine source,
;; so a launcher which stops pairing that root with an empty object directory
;; loads the object instead of the source. This is a per-runtime staging file,
;; not harness text, so naming Chez here is allowed.
;;
;; Both halves of the poison are read from the source tree, not from the stage:
;; the two are byte-identical by construction, and reading the stage would make
;; this pass depend on the previous pass having left it in place.
(library-directories (list (cons \"${SOURCE_ROOT}/test/support/harness\" \"${POISON_GUARD_DIR}\")))
;; Compiled first, and into POISON_ROOT itself (not the guard): harness's own
;; object is trusted only if this one is also a real, reachable object by the
;; time harness compiles, per the transitive staleness note above.
(compile-library \"${POISON_ROOT}/byte-machine/test/fingerprint.sls\"
                 \"${POISON_ROOT}/byte-machine/test/fingerprint.so\")
(compile-library \"${POISON_SOURCE_DIR}/byte-machine/test/harness.sls\"
                 \"${POISON_OBJECT}\")
")

execute_process(
  COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}" "--script" "${POISON_COMPILE_SCRIPT}"
  RESULT_VARIABLE POISON_RC
  OUTPUT_VARIABLE POISON_OUT
  ERROR_VARIABLE POISON_ERR)
if(NOT POISON_RC EQUAL 0 OR NOT EXISTS "${POISON_OBJECT}"
   OR NOT EXISTS "${POISON_ROOT}/byte-machine/test/fingerprint.so")
  message(FATAL_ERROR
    "byte-machine-mutation: could not compile the poisoned library root "
    "(exit ${POISON_RC}). Without a real object for both harness and the "
    "fingerprint library it now imports, the library-directories mutation "
    "cannot discriminate, and a run against a file Chez cannot read as a "
    "library, or a harness object it distrusts for an unresolved import, "
    "passes either way.\n"
    "${POISON_OUT}${POISON_ERR}")
endif()

# Makes "not older than the source" true by construction rather than by the
# compile happening to take a second, which a filesystem with coarse timestamps
# would not record. The fingerprint object is touched first, preserving the
# dependency order the compile above already established: harness's object
# must never be older than a library it imports.
file(TOUCH "${POISON_ROOT}/byte-machine/test/fingerprint.so")
file(TOUCH "${POISON_OBJECT}")

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${POISON_ROOT}"
  "--object-guard" "${POISON_GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-self-tests.sps")

# EXPECT_OUTPUT_MATCHES turns the paragraph above's claim -- that the mutated
# run "says so in its banner, its FAIL-CONTEXT line, and its summary" -- into
# something this suite enforces rather than merely asserts in prose. The
# sentinel is the literal string written into POISON_REPLACE above, so a rc
# that happens to be nonzero for some other reason (a staging error, an
# unrelated crash) is reported caught-for-the-wrong-reason instead of caught.
byte_machine_mutation(
  FILE ${LAUNCHER}
  SPEC "harness-self-tests.sps against a library root holding a compiled object"
  LABEL "launcher: the library root is no longer paired with the object guard"
  FIND [[(library-directories
 (map (lambda (root) (cons root object-guard-dir)) library-roots))]]
  REPLACE [[(library-directories library-roots)]]
  EXPECT_OUTPUT_MATCHES "POISONED-FROM-OBJECT")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Passes 9 to 17: the launcher's parse decisions -------------------------
#
# Deleting a refusal does not produce a wrong answer; it produces an invocation
# that is accepted and then fails somewhere else, or does not fail at all. Two
# of these mutations leave the launcher reaching malformed input and dying at
# 255 rather than 2, which the exact-status helper reports as out-of-vocabulary.
# That is still caught, and it is the honest outcome: the refusal exists exactly
# so that malformed input is named rather than stumbled over.

set(LAUNCHER_BASE_ARGS
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-bootstrap.sps")

# byte_machine_slice3_launcher_pass(<lane> <label> <find> <replace>
#                                   <expect_output_matches> <arg>...)
#
# One pass: point the verify command at a deliberately wrong invocation, declare
# one mutation, run it. Defined here rather than inlined nine times because the
# only thing that varies is the lane, the command line, and the mutation.
#
# expect_output_matches exists because the wrapper's own exit code is only ever
# 0 or 1 -- ByteMachineExpectExit.cmake's message(FATAL_ERROR) exits 1
# regardless of what the real launcher's exit status was, so a nonzero result
# here means only "the real process did not exit 2", never which of the two
# very different ways that can happen: the invocation this pass built runs to
# completion once the deleted check stops blocking it (verified as
# "bootstrap: failures=0" -- the bootstrap program's own success banner,
# reachable only by loading and running the entire staged launcher and
# program), or it reaches a later, unrelated Chez error and dies with an
# out-of-vocabulary status (verified per pass -- see the call sites below).
# Both are legitimate evidence that the deleted check mattered. What neither
# looks like is a read error from a staged file that stopped being valid
# Scheme, which is what this project measured exactly once: a REPLACE that
# opened a line comment and swallowed a list's closing parens (recorded next to
# the --library-root mutation below) caught the pass at exit 255 on
# "Exception in read: ..." rather than on the refusal it names. Every value
# passed here was captured from a real staged run of the mutation it guards,
# not guessed.
#
# The reset, the declaration and the run all happen inside this function on
# purpose. byte_machine_mutation_reset and byte_machine_mutation both write the
# counter with PARENT_SCOPE, so they agree only while they share a caller;
# splitting them across this boundary would leave the run seeing a count from
# somewhere else.
function(byte_machine_slice3_launcher_pass lane label find replace expect_output_matches)
  byte_machine_mutation_reset()

  string(JOIN "|" packed
    "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
    "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
    ${ARGN})

  set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
    "${CMAKE_COMMAND}"
    "-DBYTE_MACHINE_EXPECT_EXIT=2"
    "-DBYTE_MACHINE_EXPECT_COMMAND=${packed}"
    -P "${STAGE_DIR}/cmake/ByteMachineExpectExit.cmake")

  byte_machine_mutation(
    FILE ${LAUNCHER} SPEC "${lane}"
    LABEL "${label}"
    FIND "${find}"
    REPLACE "${replace}"
    EXPECT_OUTPUT_MATCHES "${expect_output_matches}")

  byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")
endfunction()

byte_machine_slice3_launcher_pass(
  byte-machine.harness.launcher-unknown-flag.chez.source
  "launcher: an unrecognised flag is accepted"
  [[        ((not (member (car rest) known-flags))]]
  [[        (#f]]
  "bootstrap: failures=0"
  "--librarie-root" "${STAGE_DIR}/test/support/harness" ${LAUNCHER_BASE_ARGS})

byte_machine_slice3_launcher_pass(
  byte-machine.harness.launcher-missing-value.chez.source
  "launcher: a flag with no value is accepted"
  [[        ((null? (cdr rest))]]
  [[        (#f]]
  "Exception in cddr"
  ${LAUNCHER_BASE_ARGS} "--library-root")

byte_machine_slice3_launcher_pass(
  byte-machine.harness.launcher-repeated-flag.chez.source
  "launcher: a single-valued flag may be given twice"
  [[   (if (> (length (flag-values flag)) 1)]]
  [[   (if #f]]
  "bootstrap: failures=0"
  ${LAUNCHER_BASE_ARGS}
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-self-tests.sps")

# SPEC must name a lane `ctest -N` actually lists: it is the transcript name a
# real invocation is judged under, and once a verify command is set (as every
# pass in this file does), SPEC is otherwise ignored -- so a value that names
# no real lane is checked by nothing, and nothing notices. This pass and the
# entry-specific one below that drops --library-root from required-flags both
# run the identical missing-library-root invocation, so both are witnessed by
# the same registered lane, byte-machine.harness.launcher-no-library-root.chez.source.
# An earlier revision renamed this pass's SPEC to
# "byte-machine.harness.launcher-required-flag-unchecked.chez.source" to stop
# the two mutations sharing one name in the transcript -- a real problem -- but
# that traded it for a worse one: a unique SPEC value naming a lane that does
# not exist. The disambiguation belongs in LABEL instead, which is free text
# with no such constraint: this pass witnesses decision 2's own check (the
# `if` that runs once per required flag, so it breaks identically no matter
# which flag the invocation happened to omit -- library-root was picked only
# because it made a convenient invocation to reuse), while the pass below
# witnesses required-flags' library-root *entry* specifically, i.e. whether
# the flag is still in the list decision 2 walks at all. Two different lines,
# two different mutations, one shared witness.
byte_machine_slice3_launcher_pass(
  byte-machine.harness.launcher-no-library-root.chez.source
  "launcher: a missing required flag is not noticed (decision 2's own check, general across every entry; reuses the no-library-root invocation below only for convenience)"
  [[   (if (null? (flag-values flag))]]
  [[   (if #f]]
  [[library \(byte-machine test harness\) not found]]
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-bootstrap.sps")

# Three more: one per entry in required-flags. The check above is one decision,
# but the list it walks is three, and an entry dropped from it is invisible to
# every invocation except the one omitting that flag.

byte_machine_slice3_launcher_pass(
  byte-machine.harness.launcher-no-program.chez.source
  "launcher: --program is dropped from required-flags"
  [[  (list "--program"]]
  [[  (list ;; --program removed by mutation]]
  "Exception in car"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--object-guard" "${GUARD_DIR}")

byte_machine_slice3_launcher_pass(
  byte-machine.harness.launcher-no-object-guard.chez.source
  "launcher: --object-guard is dropped from required-flags"
  [[        "--object-guard"]]
  [[        ;; --object-guard removed by mutation]]
  "Exception in car"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-bootstrap.sps")

# --library-root is the last entry in required-flags, so its source line ends
# with two closing parens -- the list's and the define's -- rather than one.
# A FIND that matched only the flag's text left both dangling after a REPLACE
# that opened a line comment: the comment swallowed ")) " too, so the staged
# file was not readable Scheme and died with a read error at exit 255 rather
# than the launcher's own required-flag refusal -- caught, but for the wrong
# reason, and witnessing nothing about the decision this pass names. The FIND
# below includes the trailing "))" so the REPLACE can close the list itself.
# Whichever entry ends up last in required-flags after a reorder or a fourth
# addition inherits this hazard and needs the same treatment.
byte_machine_slice3_launcher_pass(
  byte-machine.harness.launcher-no-library-root.chez.source
  "launcher: --library-root is dropped from required-flags"
  [[        "--library-root"))]]
  [[        ;; --library-root removed by mutation
        ))]]
  [[library \(byte-machine test harness\) not found]]
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-bootstrap.sps")

# Two more, for single-valued-flags. --object-guard has never been exercised as
# a repeated flag: the general check just above is witnessed only through
# --program (LAUNCHER_BASE_ARGS already carries one --object-guard, so this
# pass repeats it rather than adding a second fixture guard directory --
# decision 3 counts occurrences, not distinct values). Dropping --object-guard
# from single-valued-flags specifically, leaving the check itself and
# --program's membership in the list untouched, is invisible to every
# invocation but this one.
byte_machine_slice3_launcher_pass(
  byte-machine.harness.launcher-repeated-object-guard.chez.source
  "launcher: --object-guard is dropped from single-valued-flags"
  [[(define single-valued-flags
  (list "--object-guard" "--program"))]]
  [[(define single-valued-flags
  (list "--program"))]]
  "bootstrap: failures=0"
  ${LAUNCHER_BASE_ARGS}
  "--object-guard" "${GUARD_DIR}")

# required-flags' own rationale -- "an entry dropped from it is invisible to
# every invocation except the one omitting that flag" -- applies just as much
# to single-valued-flags' other member, so --program gets the same treatment.
# It sits last on its line, hard against the list's and the define's closing
# parens -- the same position that made --library-root's required-flags
# mutation above catch a read error instead of the decision it names (the
# hazard recorded there). The FIND below matches the whole two-line form,
# both closing parens included, and the REPLACE is itself a complete,
# well-formed define, so there is no dangling ")" left for a comment to
# swallow.
#
# The invocation below repeats --program, so the real lane witnessing it is
# byte-machine.harness.launcher-repeated-flag.chez.source, not a name of this
# pass's own -- see the SPEC-must-name-a-real-lane comment above the
# required-flag-unchecked pass for why that match matters and what happens
# when it drifts.
byte_machine_slice3_launcher_pass(
  byte-machine.harness.launcher-repeated-flag.chez.source
  "launcher: --program is dropped from single-valued-flags (reuses the launcher-repeated-flag invocation, which already repeats --program)"
  [[(define single-valued-flags
  (list "--object-guard" "--program"))]]
  [[(define single-valued-flags
  (list "--object-guard"))]]
  "bootstrap: failures=0"
  ${LAUNCHER_BASE_ARGS}
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-self-tests.sps")

# --- Pass 20: the fingerprint algorithm --------------------------------------
#
# The self-tests assert measured literals, so any change to seed, multiplier,
# modulus, the +1, or the digit table moves at least one of them.

set(FINGERPRINT test/support/harness/byte-machine/test/fingerprint.sls)

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-self-tests.sps")

byte_machine_mutation_reset()

# Without the +1 a NUL contributes nothing, and the three leading-zero cases
# collapse into one value. This is the only mutation here that a fixed set of
# literals could survive if the literals happened not to include a NUL --
# which is why they do.
byte_machine_mutation(
  FILE ${FINGERPRINT} SPEC harness-self-tests.sps
  LABEL "fingerprint: leading zero bytes stop being significant"
  FIND [[                           (+ (bytevector-u8-ref bv i) 1))]]
  REPLACE [[                           (bytevector-u8-ref bv i))]])

byte_machine_mutation(
  FILE ${FINGERPRINT} SPEC harness-self-tests.sps
  LABEL "fingerprint: the seed changes"
  FIND [[(define harness-fingerprint-seed 14695981039346656)]]
  REPLACE [[(define harness-fingerprint-seed 14695981039346657)]])

byte_machine_mutation(
  FILE ${FINGERPRINT} SPEC harness-self-tests.sps
  LABEL "fingerprint: the multiplier changes"
  FIND [[(define harness-fingerprint-multiplier 1000003)]]
  REPLACE [[(define harness-fingerprint-multiplier 1000033)]])

byte_machine_mutation(
  FILE ${FINGERPRINT} SPEC harness-self-tests.sps
  LABEL "fingerprint: the modulus changes"
  FIND [[(define harness-fingerprint-modulus 2305843009213693951) ; 2^61 - 1]]
  REPLACE [[(define harness-fingerprint-modulus 2305843009213693907)]])

# Combining becomes a sum, so order stops mattering and the two combine cases
# collapse to one value.
byte_machine_mutation(
  FILE ${FINGERPRINT} SPEC harness-self-tests.sps
  LABEL "fingerprint: combining stops being order sensitive"
  FIND [[              (modulo (+ (* h harness-fingerprint-multiplier) (+ (car rest) 1))]]
  REPLACE [[              (modulo (+ h (+ (car rest) 1))]])

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 21: the hex rendering table -----------------------------------------
#
# MEASURED 2026-08-17. No manifest is set, so provenance is skipped here
# exactly as it is for every other pass but 22 through 25 below:
# BYTE_MACHINE_FINGERPRINT_FILES is unset, harness-verify-provenance! returns
# #t immediately, and the self-tests suite runs its own cases undisturbed. It
# is the self-tests' own "hex digits render lowercase" case that actually
# witnesses this mutation -- it check-equals fixed literals ("ff", "deadbeef",
# "0") rather than deriving its expectation from fingerprint.sls, so mutating
# the digit table fails an ordinary comparison: the process exits 1 (the
# harness's own "an assertion failed" status) with a "byte-machine-harness:
# FAIL " line, which is exactly what EXPECT_STATUS and EXPECT_OUTPUT_MATCHES
# below assert and exactly what the real run reports caught.

set(HEX_MUTATION_FIND [[(define harness-hex-digits "0123456789abcdef")]])
set(HEX_MUTATION_REPLACE [[(define harness-hex-digits "0123456789ABCDEF")]])

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-self-tests.sps")

byte_machine_mutation(
  FILE ${FINGERPRINT} SPEC harness-self-tests.sps
  LABEL "fingerprint: hex digits become uppercase"
  FIND "${HEX_MUTATION_FIND}"
  REPLACE "${HEX_MUTATION_REPLACE}"
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "byte-machine-harness: FAIL ")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Passes 22 and 23: the provenance check itself ----------------------------
#
# Wrapped in the exact-status helper so exit 3 -- the refusal -- is the green
# baseline, exactly as passes 4 and 5 do for the launcher. A mutation that makes
# the check more permissive drops the inner status to 0, the wrapper reports
# nonzero, and the mutation is caught. Continued below by passes 24 and 25,
# which this pair's own comments point to at the place each split off.
#
# THE MANIFEST NAMES ONE SOURCE ON PURPOSE
#
# BYTE_MACHINE_EXPECT_COMMAND packs its argument vector with `|`, which is also
# the manifest separator, so a two-element manifest would be unpacked as two
# arguments. One source is enough: these passes test whether the check runs and
# is consulted, not how values combine, which pass 20 covers. Passes 24 and 25
# keep the same one-source manifest for the same reason.

set(RUNNER_BODY test/support/harness/byte-machine/test/harness.sls)

set(WRONG_FP_FILE "${WORK_DIR}/wrong.fingerprint")
file(WRITE "${WRONG_FP_FILE}" "not-a-fingerprint")

byte_machine_mutation_reset()

string(JOIN "|" PROVENANCE_MISMATCH_COMMAND
  "${CMAKE_COMMAND}" "-E" "env"
  "BYTE_MACHINE_FINGERPRINT_FILES=${STAGE_DIR}/test/support/harness/byte-machine/test/fingerprint.sls"
  "BYTE_MACHINE_EXPECT_FINGERPRINT_FILE=${WRONG_FP_FILE}"
  "--"
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-self-tests.sps")

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${CMAKE_COMMAND}"
  "-DBYTE_MACHINE_EXPECT_EXIT=3"
  "-DBYTE_MACHINE_EXPECT_COMMAND=${PROVENANCE_MISMATCH_COMMAND}"
  -P "${STAGE_DIR}/cmake/ByteMachineExpectExit.cmake")

byte_machine_mutation(
  FILE ${RUNNER_BODY} SPEC byte-machine.harness.provenance.chez.source
  LABEL "provenance: the comparison always reports agreement"
  FIND [[    ((string=? expected computed) #f)]]
  REPLACE [[    (#t #f)]])

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# "provenance: harness-begin stops checking at all" used to live here, sharing
# this pass's WRONG_FP_FILE verify command with EXPECT_EXIT 3. Task 8's
# reachability guard (test/support/harness/byte-machine/test/harness.sls,
# harness-provenance-reachability-diagnosis) made that ambiguous: with the call
# removed, harness-provenance-checked never becomes #t, and the guard now
# refuses with status 3 of its own accord -- the same number WRONG_FP_FILE's
# mismatch was already producing, for an unrelated reason. ByteMachineExpectExit
# compares only the number, so both baseline and this mutation satisfy
# EXPECT_EXIT 3 and the wrapper reports "exited as expected" either way: not
# caught, not because nothing noticed, but because two different refusals now
# agree on the one status this vocabulary gives refusals. Moved to pass 24
# below, which is what gives it a baseline the guard cannot also produce.

# Pass 23: the same wrapper, but the expectation file does not exist, so the
# refusal under test is the missing-expectation branch rather than the
# comparison. Its mutation leaves the guard `(not expected)` matching -- so
# there is no fallthrough to the next clause -- and changes only what the
# matched branch returns: silently #f instead of the diagnosis string.
# harness-verify-provenance! reads that #f as nothing to report and lets the
# run proceed as though the missing expectation had been verified.
#
# Measured 2026-08-17: caught, but not by exiting 0. The self-tests' own
# "a missing expectation is its own diagnosis" case calls
# harness-provenance-diagnosis(#f, ...) directly and checks that a diagnosis
# comes back; with the branch mutated that check fails outright -- an
# ordinary comparison -- and the whole run reports byte-machine-harness
# status 1, not 3. The exact-status wrapper below compares that 1 against the
# declared EXPECT_EXIT of 3 and reports the mismatch. Both routes are a
# failed comparison; neither is a raise.
#
# An earlier form mutated the guard instead of the branch: `(not expected)`
# became `(and #f expected)`, which never matches, so control fell through to
# `(string=? expected computed)` with expected still #f. string=? on a
# non-string is a type violation, so that form was caught by Chez's top-level
# handler killing the process at exit 255 -- outside the harness's own status
# vocabulary, and before a single self-test case ran -- rather than by the
# assertion naming this decision. Replaced once this comparison-based form
# was found, per AGENTS.md's preference for a failed comparison over a raise.
byte_machine_mutation_reset()

string(JOIN "|" PROVENANCE_ABSENT_COMMAND
  "${CMAKE_COMMAND}" "-E" "env"
  "BYTE_MACHINE_FINGERPRINT_FILES=${STAGE_DIR}/test/support/harness/byte-machine/test/fingerprint.sls"
  "BYTE_MACHINE_EXPECT_FINGERPRINT_FILE=${WORK_DIR}/never-produced.fingerprint"
  "--"
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-self-tests.sps")

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${CMAKE_COMMAND}"
  "-DBYTE_MACHINE_EXPECT_EXIT=3"
  "-DBYTE_MACHINE_EXPECT_COMMAND=${PROVENANCE_ABSENT_COMMAND}"
  -P "${STAGE_DIR}/cmake/ByteMachineExpectExit.cmake")

byte_machine_mutation(
  FILE ${RUNNER_BODY} SPEC byte-machine.harness.provenance-absent-expectation.chez.source
  LABEL "provenance: a missing expectation stops being a diagnosis"
  FIND [[    ((not expected)
     (string-append
      "no expectation was supplied, so nothing can say whether this run "
      "executed the text it was supposed to. This run computed " computed "."))]]
  REPLACE [[    ((not expected) #f)]])

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# A stated blind spot: the third refusal -- a manifest naming an unreadable
# source -- has no mutation here. Making it witnessable would need an
# expectation crafted to equal what the mutant computes after the read fails,
# which is a value with no meaning outside that mutation. It is covered by its
# registered lane, byte-machine.harness.provenance-missing-body.chez.source,
# and this is recorded rather than papered over with an EXPECT_SURVIVES, which
# AGENTS.md reserves for the genuinely unwitnessable.

# --- Pass 24: the call site, witnessed against a baseline the guard cannot
# also satisfy -----------------------------------------------------------
#
# Continues "provenance: harness-begin stops checking at all" from pass 22,
# with a different baseline. WRONG_FP_FILE cannot be reused: it makes the
# unmutated lane's correct behaviour exit 3, and after Task 8 this mutation's
# broken behaviour *also* exits 3 (the reachability guard's own refusal), so a
# wrapper that only compares the exit number cannot tell them apart -- both
# read as "exited 3 as expected." Giving the lane an expectation it actually
# matches makes the unmutated baseline exit 0 instead, which the guard cannot
# produce (harness-provenance-checked is #t by the time harness-summary reads
# it, so the guard stays quiet and the self-tests' own pass/fail is what
# decides). The mutation still removes the call, so harness-provenance-checked
# stays #f, the guard still refuses, and the lane still exits 3 -- now cleanly
# distinct from the 0 baseline instead of coinciding with the old one.
#
# THE MANIFEST NAMES ONE SOURCE, AS ABOVE, AND ITS EXPECTATION IS COMPUTED, NOT
# WRITTEN BY HAND
#
# byte_machine_expected_fingerprint in test/CMakeLists.txt is a CMake function,
# unreachable from this standalone script, so the value is produced the same
# way it is: running fingerprint-manifest.ss over the staged fingerprint.sls.
# THE ALGORITHM IS NOT REIMPLEMENTED HERE applies here just as it does there.
set(CORRECT_FP_FILE "${WORK_DIR}/correct.fingerprint")
execute_process(
  COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}" "--script"
          "${STAGE_DIR}/test/support/launchers/fingerprint-manifest.ss"
          "${STAGE_DIR}/test/support/harness"
          "${GUARD_DIR}"
          "${CORRECT_FP_FILE}"
          "${STAGE_DIR}/test/support/harness/byte-machine/test/fingerprint.sls"
  RESULT_VARIABLE fp_rc
  OUTPUT_VARIABLE fp_out
  ERROR_VARIABLE fp_err)
if(NOT fp_rc EQUAL 0)
  message(FATAL_ERROR
    "byte-machine-mutation: could not compute pass 24's baseline fingerprint "
    "(exit ${fp_rc}): ${fp_out}${fp_err}")
endif()

byte_machine_mutation_reset()

string(JOIN "|" PROVENANCE_UNCALLED_COMMAND
  "${CMAKE_COMMAND}" "-E" "env"
  "BYTE_MACHINE_FINGERPRINT_FILES=${STAGE_DIR}/test/support/harness/byte-machine/test/fingerprint.sls"
  "BYTE_MACHINE_EXPECT_FINGERPRINT_FILE=${CORRECT_FP_FILE}"
  "--"
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-self-tests.sps")

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${CMAKE_COMMAND}"
  "-DBYTE_MACHINE_EXPECT_EXIT=0"
  "-DBYTE_MACHINE_EXPECT_COMMAND=${PROVENANCE_UNCALLED_COMMAND}"
  -P "${STAGE_DIR}/cmake/ByteMachineExpectExit.cmake")

byte_machine_mutation(
  FILE ${RUNNER_BODY} SPEC byte-machine.harness.provenance.chez.source
  LABEL "provenance: harness-begin stops checking at all"
  FIND [[  (harness-verify-provenance!)
  (harness-clear-state!)]]
  REPLACE [[  (harness-clear-state!)]])

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 25: the reachability guard itself -------------------------------
#
# harness-unreached-provenance.sps (test/support/harness/self/) deliberately
# never calls harness-begin, so its lane's baseline already exits 3 through
# the guard alone -- no WRONG_FP_FILE trick needed, and no
# BYTE_MACHINE_EXPECT_FINGERPRINT_FILE either, since nothing in this lane's
# reachable code ever compares a fingerprint. Two mutations, because
# harness-provenance-reachability-diagnosis's rule has two halves that fail
# independently (V13's own comment: "manifest and not checked?"): the
# diagnosis can stop firing, or checked? can stop meaning what its name says.
# Either one drops the baseline's 3 to 0, which EXPECT_EXIT catches cleanly --
# unlike pass 24, nothing else in this lane's execution can also produce 3, so
# no separate baseline is needed here.
set(UNREACHED_PROVENANCE_SPEC byte-machine.harness.unreached-provenance.chez.source)

byte_machine_mutation_reset()

string(JOIN "|" PROVENANCE_REACHABILITY_COMMAND
  "${CMAKE_COMMAND}" "-E" "env"
  "BYTE_MACHINE_FINGERPRINT_FILES=${STAGE_DIR}/test/support/harness/byte-machine/test/fingerprint.sls"
  "--"
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-unreached-provenance.sps")

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${CMAKE_COMMAND}"
  "-DBYTE_MACHINE_EXPECT_EXIT=3"
  "-DBYTE_MACHINE_EXPECT_COMMAND=${PROVENANCE_REACHABILITY_COMMAND}"
  -P "${STAGE_DIR}/cmake/ByteMachineExpectExit.cmake")

byte_machine_mutation(
  FILE ${RUNNER_BODY} SPEC ${UNREACHED_PROVENANCE_SPEC}
  LABEL "provenance: the reachability diagnosis stops guarding"
  FIND [[  (if (and manifest (not (string=? manifest "")) (not checked?))]]
  REPLACE [[  (if #f]])

byte_machine_mutation(
  FILE ${RUNNER_BODY} SPEC ${UNREACHED_PROVENANCE_SPEC}
  LABEL "provenance: harness-provenance-checked starts true, so unreached looks reached"
  FIND [[(define harness-provenance-checked #f)]]
  REPLACE [[(define harness-provenance-checked #t)]])

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 26: the aot launcher's library-path pairing ------------------------
#
# C3 and C3b, measured 2026-08-17 and re-measured against the shipped lane
# (design section 5.3, remainder addendum). The objects are compiled once,
# here, from the staged tree; the plant is a byte-divergent copy of the
# harness library dropped at its library-relative path inside the object
# directory, touched newer than the objects. Under the shipped pairing the
# plant sits in a directory Chez consults only for objects and is never
# read; under C3's unpaired shape every object directory is also a source
# directory, Chez finds the newer source, re-expands it, and load-program
# refuses the different compilation instance at 255 -- outside the status
# vocabulary, reported as a process that died, which is the honest shape of
# this defect.
byte_machine_mutation_reset()

set(AOT_PASS_DIR "${WORK_DIR}/aot-pairing")
file(MAKE_DIRECTORY "${AOT_PASS_DIR}/harness" "${AOT_PASS_DIR}/src"
     "${AOT_PASS_DIR}/source-guard")
execute_process(
  COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}" --script
          "${STAGE_DIR}/test/support/launchers/chez-compile.ss"
          --library-root "${STAGE_DIR}/test/support/harness"
          --object-dir "${AOT_PASS_DIR}/harness"
          --library-root "${STAGE_DIR}/src"
          --object-dir "${AOT_PASS_DIR}/src"
          --program "${STAGE_DIR}/test/support/harness/self/harness-bootstrap.sps"
          --output "${AOT_PASS_DIR}/harness-bootstrap.so"
  RESULT_VARIABLE aot_compile_rc)
if(NOT aot_compile_rc EQUAL 0)
  message(FATAL_ERROR
    "byte-machine-mutation: pass 26 could not compile its artifacts (rc "
    "${aot_compile_rc}); nothing this pass reports would mean anything.")
endif()
file(MAKE_DIRECTORY "${AOT_PASS_DIR}/harness/byte-machine/test")
file(COPY_FILE
  "${STAGE_DIR}/test/support/harness/byte-machine/test/harness.sls"
  "${AOT_PASS_DIR}/harness/byte-machine/test/harness.sls")
file(APPEND "${AOT_PASS_DIR}/harness/byte-machine/test/harness.sls"
  "\n;; planted: only an unpaired library path can read this file\n")
file(TOUCH "${AOT_PASS_DIR}/harness/byte-machine/test/harness.sls")

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${CMAKE_COMMAND}" "-E" "env" "BYTE_MACHINE_EXECUTION_MODE=aot" "--"
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}" "--script"
  "${STAGE_DIR}/test/support/launchers/chez-aot.ss"
  "--object-dir" "${AOT_PASS_DIR}/harness"
  "--object-dir" "${AOT_PASS_DIR}/src"
  "--source-guard" "${AOT_PASS_DIR}/source-guard"
  "--program" "${AOT_PASS_DIR}/harness-bootstrap.so")

# EXPECT_STATUS and EXPECT_OUTPUT_MATCHES are exactly what this pass's own
# verify command produced against the mutated launcher, run once and read
# before this narrowing was added: rc 255 and, on stdout,
# "Exception: loading .../harness.sls yielded a different compilation
# instance of (byte-machine test harness) from that required by compiled
# program" -- Chez's own load-program refusal, reached because the plant is
# now the newer file in a directory the mutated library-directories call
# also treats as a source directory. Matches the header's measured
# prediction; EXPECT_OUTPUT_MATCHES anchors on the stable substring rather
# than the full sentence, which embeds this machine's absolute build path.
byte_machine_mutation(
  FILE test/support/launchers/chez-aot.ss SPEC byte-machine.harness.self.chez.aot
  LABEL "chez-aot launcher: the source guard is unpaired from the object directories"
  FIND [[(library-directories
 (map (lambda (dir) (cons source-guard-dir dir)) object-dirs))]]
  REPLACE [[(library-directories object-dirs)]]
  EXPECT_STATUS 255
  EXPECT_OUTPUT_MATCHES "different compilation instance")

# FIND carries its own trailing newline, which the plan text's version of this
# mutation did not: the bare pattern also opens the "WHY source-directories IS
# ALSO EMPTIED" paragraph's own worked example above ("run once with
# (source-directories '()) and once left at Chez's unset default"), so without
# the newline the pattern matches twice -- code once, prose once -- and the
# SITES-count guard in byte_machine_mutation refuses it (found 2, expected 1)
# rather than silently mutating the comment along with the code. Confirmed
# against the shipped file: the comment's occurrence is followed by " and",
# never by end-of-line, so anchoring on the trailing newline is precise, not
# merely convenient.
byte_machine_mutation(
  FILE test/support/launchers/chez-aot.ss SPEC byte-machine.harness.self.chez.aot
  LABEL "chez-aot launcher: source-directories is not emptied"
  FIND [[(source-directories '())
]]
  REPLACE [[(source-directories (list "."))
]]
  EXPECT_SURVIVES
    "measured inert 2026-08-17 and re-measured through the shipped lane: library resolution runs through library-directories, no file in the inline tree includes another (decision 0006), so this line narrows nothing reachable today; kept in the launcher because it costs one line and guards a future load or include added to the launcher itself. Reopening condition: a Chez that re-resolves a compiled library's sources at load time.")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Passes 27 to 29: the aot-side launchers' new refusals -------------------
#
# The same argument as passes 9-17: a correctly set-up lane never reaches a
# refusal, so only a deliberately wrong invocation can notice one being
# deleted. Three passes, matching the three registered refusal lanes -- the
# decisions genuinely new in these files. The verbatim flag-block copies
# are deliberately not re-proven here; the launchers' own headers record
# what is and is not witnessed per copy.
#
# Unlike byte_machine_slice3_launcher_pass above, EXPECT_STATUS and
# EXPECT_OUTPUT_MATCHES are optional here rather than a fixed positional
# parameter: passes 9-17 were each written with their narrowing already
# known, but these three are narrowed only after being run once and read (see
# the call sites below), so the helper has to accept an invocation carrying
# neither, either, or both. cmake_parse_arguments pulls them out of ARGN
# ahead of the launcher's own command-line arguments -- none of which is
# spelled "EXPECT_STATUS" or "EXPECT_OUTPUT_MATCHES" -- and each is forwarded
# to byte_machine_mutation only when given, the same CMP0174-motivated
# reasoning as byte_machine_add_exit_code_test's WORKING_DIRECTORY
# (ByteMachineExpectExit.cmake): a keyword forwarded with an empty value
# would parse as though it were never given at this project's 3.26 floor, but
# silently, since CMP0174 does not warn about it before 3.31.
#
# The reset, the declaration and the run all happen inside this function on
# purpose, the same reason byte_machine_slice3_launcher_pass's header gives.
function(byte_machine_slice5b_launcher_pass launcher_file lane label find replace)
  cmake_parse_arguments(pass "" "EXPECT_STATUS;EXPECT_OUTPUT_MATCHES" "" ${ARGN})

  byte_machine_mutation_reset()

  string(JOIN "|" packed
    "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
    "--script" "${STAGE_DIR}/${launcher_file}"
    ${pass_UNPARSED_ARGUMENTS})

  set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
    "${CMAKE_COMMAND}"
    "-DBYTE_MACHINE_EXPECT_EXIT=2"
    "-DBYTE_MACHINE_EXPECT_COMMAND=${packed}"
    -P "${STAGE_DIR}/cmake/ByteMachineExpectExit.cmake")

  set(narrow_args "")
  if(DEFINED pass_EXPECT_STATUS)
    list(APPEND narrow_args EXPECT_STATUS "${pass_EXPECT_STATUS}")
  endif()
  if(DEFINED pass_EXPECT_OUTPUT_MATCHES)
    list(APPEND narrow_args EXPECT_OUTPUT_MATCHES "${pass_EXPECT_OUTPUT_MATCHES}")
  endif()

  byte_machine_mutation(
    FILE ${launcher_file} SPEC "${lane}"
    LABEL "${label}"
    FIND "${find}"
    REPLACE "${replace}"
    ${narrow_args})

  byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")
endfunction()

# Run once and read before narrowing, the same discipline as C3 above.
# EXPECT_STATUS is not used: this pass runs through ByteMachineExpectExit.cmake,
# same as every byte_machine_slice3_launcher_pass call above, and that
# wrapper's own message(FATAL_ERROR) always exits 1 on a non-matching real
# status -- 255 included -- so EXPECT_STATUS could only ever see 0 or 1 here
# and would narrow nothing; passes 9-17's header makes the identical point.
# What is real evidence is the wrapper's echoed command output: with the
# existence check gone, load-program itself is handed a path that is not
# there and Chez's own file layer refuses it directly --
# "Exception in load-program: failed for .../no-such-program.so: no such
# file or directory", observed on the wrapper's echoed stdout.
byte_machine_slice5b_launcher_pass(
  test/support/launchers/chez-aot.ss
  byte-machine.harness.chez-aot-launcher-missing-program.chez.aot
  "chez-aot launcher: a missing compiled program is accepted"
  [[(if (not (file-exists? program))]]
  [[(if #f]]
  "--object-dir" "${AOT_PASS_DIR}/harness"
  "--source-guard" "${AOT_PASS_DIR}/source-guard"
  "--program" "${AOT_PASS_DIR}/no-such-program.so"
  EXPECT_OUTPUT_MATCHES "Exception in load-program")

# Run once and read, as above; no EXPECT_STATUS, for the same wrapper reason
# given above the missing-program pass. Reusing the harness object directory
# as the guard (see the rationale where this pass is called) reproduces C3's
# own scenario by a different route: the guard is the harness's object
# directory, so once the emptiness check stops blocking it, that same
# directory's library-directories pairing makes it a source directory too,
# and Chez's load-program hits the identical "different compilation
# instance" refusal C3 does -- two different deleted checks, coincident only
# in this fixture because both ultimately leave the harness object directory
# readable as a source directory.
byte_machine_slice5b_launcher_pass(
  test/support/launchers/chez-aot.ss
  byte-machine.harness.chez-aot-launcher-dirty-source-guard.chez.aot
  "chez-aot launcher: a dirty source guard is accepted"
  [[(if (not (null? (directory-list source-guard-dir)))]]
  [[(if #f]]
  "--object-dir" "${AOT_PASS_DIR}/harness"
  "--object-dir" "${AOT_PASS_DIR}/src"
  "--source-guard" "${AOT_PASS_DIR}/harness"
  "--program" "${AOT_PASS_DIR}/harness-bootstrap.so"
  EXPECT_OUTPUT_MATCHES "different compilation instance")

# Run once and read, as above; no EXPECT_STATUS, for the same wrapper reason
# given above the missing-program pass. R6RS's map requires its argument
# lists to be the same length; with the pairing-count refusal gone, (map
# cons library-roots object-dirs) is handed a 2-element and a 1-element list
# and Chez's own map refuses them directly, observed on the wrapper's echoed
# stdout as "Exception in map: lists (...) and (...) differ in length".
byte_machine_slice5b_launcher_pass(
  test/support/launchers/chez-compile.ss
  byte-machine.harness.chez-compile-launcher-unpaired-roots.chez.aot
  "chez-compile launcher: unpaired roots are accepted"
  [[(if (not (= (length library-roots) (length object-dirs)))]]
  [[(if #f]]
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-dir" "${AOT_PASS_DIR}/harness"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-bootstrap.sps"
  "--output" "${AOT_PASS_DIR}/unpaired.so"
  EXPECT_OUTPUT_MATCHES "Exception in map")

# --- Pass 30: the provenance decisions a one-source manifest cannot witness --
#
# Passes 22-25 pack their verify commands through BYTE_MACHINE_EXPECT_COMMAND,
# whose | packing forbids a multi-source manifest -- their manifests name one
# source on purpose, so the split character and the combining order have
# never had a witness. This pass runs the lane command bare: its baseline is
# a PASSING provenance run (exit 0), and each catchable mutation turns that
# into the mismatch refusal (exit 3), so no wrapper is needed and the
# two-source manifest rides in an ordinary env entry.
#
# NEITHER MANIFEST FILE IS ONE THIS PASS MUTATES
#
# An earlier version of this pass fingerprinted fingerprint.sls and
# harness.sls -- the file both mutations below edit, since
# harness-verify-provenance! lives there. Measured against the shipped
# suite: with harness.sls one of the two fingerprinted sources, editing it
# at all fails the comparison before the mutated logic is even relevant, so
# EXPECT_STATUS 3 was catching "harness.sls changed", not the decision each
# mutation names. Proven with a control, not just argued: an inert trailing
# space added to an unrelated comment at the top of the file, nowhere near
# provenance, split, or combine, tripped the identical PROVENANCE-ERROR
# refusal. A catch that catches anything discriminates nothing (AGENTS.md).
# This pass fingerprints fingerprint.sls and harness-self-tests.sps instead
# -- two real files a real lane's manifest would name, neither touched by
# any mutation below -- so a mismatch can now only come from the split or
# combine logic itself. Pass 31 needs the opposite choice for the one
# decision this manifest shape cannot reach.
byte_machine_mutation_reset()

set(W9_MANIFEST
  "${STAGE_DIR}/test/support/harness/byte-machine/test/fingerprint.sls|${STAGE_DIR}/test/support/harness/self/harness-self-tests.sps")
set(W9_EXPECT_FILE "${WORK_DIR}/w9-split-combine.fingerprint")
execute_process(
  COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}" --script
          "${STAGE_DIR}/test/support/launchers/fingerprint-manifest.ss"
          "${STAGE_DIR}/test/support/harness"
          "${GUARD_DIR}"
          "${W9_EXPECT_FILE}"
          "${STAGE_DIR}/test/support/harness/byte-machine/test/fingerprint.sls"
          "${STAGE_DIR}/test/support/harness/self/harness-self-tests.sps"
  RESULT_VARIABLE w9_expect_rc)
if(NOT w9_expect_rc EQUAL 0)
  message(FATAL_ERROR
    "byte-machine-mutation: pass 30 could not compute its two-source "
    "expectation (rc ${w9_expect_rc}). The expectation must come from the "
    "staged copies -- the stage is what the run reads -- so nothing this "
    "pass reports would mean anything without it.")
endif()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${CMAKE_COMMAND}" "-E" "env"
  "BYTE_MACHINE_FINGERPRINT_FILES=${W9_MANIFEST}"
  "BYTE_MACHINE_EXPECT_FINGERPRINT_FILE=${W9_EXPECT_FILE}"
  "--"
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-self-tests.sps")

set(RUNNER_BODY test/support/harness/byte-machine/test/harness.sls)

# The manifest arrives |-joined. Split on anything else and the whole
# two-source string is one path naming no file, so the run refuses with the
# unreadable-source diagnosis -- still 3, still caught, and the label says
# which decision died. Measured: "PROVENANCE-ERROR cannot read
# <fingerprint.sls's path>|<harness-self-tests.sps's path>, which this run
# is supposed to have executed." -- the | that should have separated two
# paths is embedded in the one bogus path the comma-split produces.
byte_machine_mutation(
  FILE ${RUNNER_BODY} SPEC byte-machine.harness.provenance.chez.source
  LABEL "runner: the manifest is split on the wrong character"
  FIND [[        (let loop ((rest (harness-split raw #\|)) (acc '()))]]
  REPLACE [[        (let loop ((rest (harness-split raw #\,)) (acc '()))]]
  EXPECT_STATUS 3
  EXPECT_OUTPUT_MATCHES "PROVENANCE-ERROR cannot read")

# Combining is order-sensitive by design (slice 5a, mutation F5), so
# accumulating in reverse computes a different digest over the same two
# fingerprints -- both individually unchanged, since neither manifest file
# is edited by this mutation, so the mismatch below can only come from the
# order they were combined in, not from either file's own bytes. Measured:
# "PROVENANCE-ERROR fingerprint mismatch: the build expected <combined
# forward> but this run computed <combined reversed>."
byte_machine_mutation(
  FILE ${RUNNER_BODY} SPEC byte-machine.harness.provenance.chez.source
  LABEL "runner: the manifest digests combine in reverse order"
  FIND [[                               (harness-fingerprint-combine (reverse acc)))))]]
  REPLACE [[                               (harness-fingerprint-combine acc))))]]
  EXPECT_STATUS 3
  EXPECT_OUTPUT_MATCHES "PROVENANCE-ERROR fingerprint mismatch")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 31: the provenance exit constant, witnessed through a deliberately
# self-referential manifest --------------------------------------------------
#
# The one decision pass 30 cannot carry: harness-provenance-failure!'s single
# shared exit line, (adapter-exit harness-status-provenance). Wrong that
# constant and a provenance failure exits indistinguishably from an
# assertion failure -- the whole reason status 3 was reserved -- but under
# pass 30's own manifest (fingerprint.sls and harness-self-tests.sps,
# neither edited by this mutation) provenance keeps succeeding, so the line
# is never reached there: a passing baseline is byte_machine_mutation_run's
# own precondition, no pass may deliberately fail provenance, and a mutation
# whose only effect follows a failure that never happens would report as an
# unwitnessed EXPECT_SURVIVES.
#
# The way to reach the line is the manifest pass 30 deliberately avoids: name
# harness.sls itself -- the file this mutation, like both of pass 30's,
# edits. That self-reference was pass 30's bug (its header records the
# control that proved it); here it is the mechanism. Any edit to harness.sls
# staled against a manifest that fingerprints harness.sls fails provenance
# on its own -- exactly a run whose own text no longer matches what the
# build measured, which is what a real stale artifact looks like, not a
# contrived path to this line. That failure calls
# harness-provenance-failure!, which reaches the mutated line and exits
# harness-status-failed (1) instead of harness-status-provenance (3) -- the
# summary text printed just above the exit call still names status 3, built
# from the untouched constant, but the process's actual exit code is 1, so a
# caller reading only the exit status draws exactly the
# indistinguishable-from-an-assertion-failure conclusion this constant
# exists to prevent.
#
# This supersedes the plan's declared survivor for this line. AGENTS.md: a
# decision that can be witnessed does not get an EXPECT_SURVIVES.
byte_machine_mutation_reset()

set(W9_EXIT_MANIFEST
  "${STAGE_DIR}/test/support/harness/byte-machine/test/fingerprint.sls|${STAGE_DIR}/test/support/harness/byte-machine/test/harness.sls")
set(W9_EXIT_EXPECT_FILE "${WORK_DIR}/w9-exit-constant.fingerprint")
execute_process(
  COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}" --script
          "${STAGE_DIR}/test/support/launchers/fingerprint-manifest.ss"
          "${STAGE_DIR}/test/support/harness"
          "${GUARD_DIR}"
          "${W9_EXIT_EXPECT_FILE}"
          "${STAGE_DIR}/test/support/harness/byte-machine/test/fingerprint.sls"
          "${STAGE_DIR}/test/support/harness/byte-machine/test/harness.sls"
  RESULT_VARIABLE w9_exit_expect_rc)
if(NOT w9_exit_expect_rc EQUAL 0)
  message(FATAL_ERROR
    "byte-machine-mutation: pass 31 could not compute its two-source "
    "expectation (rc ${w9_exit_expect_rc}). The expectation must come from "
    "the staged copies -- the stage is what the run reads -- so nothing "
    "this pass reports would mean anything without it.")
endif()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${CMAKE_COMMAND}" "-E" "env"
  "BYTE_MACHINE_FINGERPRINT_FILES=${W9_EXIT_MANIFEST}"
  "BYTE_MACHINE_EXPECT_FINGERPRINT_FILE=${W9_EXIT_EXPECT_FILE}"
  "--"
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-self-tests.sps")

set(RUNNER_BODY test/support/harness/byte-machine/test/harness.sls)

# Measured: the mutated harness.sls fails its own fingerprint comparison --
# "PROVENANCE-ERROR fingerprint mismatch: the build expected <digest of the
# pristine pair> but this run computed <digest with the mutated harness.sls>"
# -- and the process exits 1 (harness-status-failed, what the mutation put
# in the exit call), not 3 (harness-status-provenance, what the unmutated
# line calls and what the summary text printed just above it still names).
byte_machine_mutation(
  FILE ${RUNNER_BODY} SPEC byte-machine.harness.provenance.chez.source
  LABEL "runner: a provenance failure exits as an assertion failure"
  FIND [[  (adapter-exit harness-status-provenance))]]
  REPLACE [[  (adapter-exit harness-status-failed))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "PROVENANCE-ERROR fingerprint mismatch")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 32: the runtime parser loop (Milestone 1 Phase 2) ------------------
#
# runtime-tests.sps drives the parser lifecycle over a hand-built compiled-
# machine stub, checking each decision directly; this pass proves those checks
# are not vacuous by breaking the decision underneath and requiring the checks
# to notice. The verify command uses both library roots -- the harness and
# src -- an empty object guard, and the runtime program. The baseline runs
# unmutated and exits 0, so a mutation that breaks a decision turns that into
# an assertion failure (exit 1).

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/runtime-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: advance does not consume the byte"
  FIND [[(loop (+ pos 1))]]
  REPLACE [[(loop pos)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "consumed")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: need-input becomes a spurious stop"
  FIND [[(make-parser-result 'need-input pos]]
  REPLACE [[(make-parser-result 'stopped pos]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "need-input")

# The stream-offset increment is a decision distinct from the pos cursor: the
# accept case pins it to 1, the reject case to 0, so a no-op increment reddens
# only the accept case (consumed and next stay correct).
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: advance does not increment the stream offset"
  FIND [[(parser-set-offset! parser (+ 1 (parser-offset parser)))]]
  REPLACE [[(parser-set-offset! parser (parser-offset parser))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "stream offset")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: a v1 machine is driven down the op path"
  # Re-anchored for Milestone 2 Slice ②b-2: parser-feed!'s binary `if` became a
  # three-way `case` (op / v2 / else=v1) when the /v2 variant landed, so the old
  # `(if #t ...)` anchor no longer exists. The same decision -- a v1 machine must
  # NOT be driven through parser-feed-op! -- is now witnessed by redirecting the
  # v1 (else) arm to the op driver; `parser-feed-v1!` occurs only here as a call
  # (its definition reads `(define (parser-feed-v1! ...`), so this is unique. The
  # effect on the suite is identical to the former mutation (v1 stubs raise an
  # arity error inside parser-feed-op!'s `(op 'kind node)`, recorded as a "case
  # raised" failure -> exit 1, summary `status=1`), so EXPECT is unchanged.
  FIND [[(else (parser-feed-v1! parser bv start end))]]
  REPLACE [[(else (parser-feed-op! parser bv start end))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "status")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: a mismatched generated-runtime ABI version is accepted"
  FIND [[(unless (and (integer? abi-version) (= abi-version current-abi-version))]]
  REPLACE [[(unless #t]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "refused")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: the v1 result status is hard-wired to stopped"
  FIND [[(status (feed-outcome-status o))]]
  REPLACE [[(status 'stopped)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "status")

# (removed 2026-08-28, Slice ②a) "a v1 terminal result is not made sticky": the
# sticky cache was deleted; a repeat feed re-runs the executor, which is idempotent
# for stop/error, so setting-vs-not-setting a cache is now unobservable in M2's
# callback-free world. Its intent is re-witnessed by the reset mutations (Task 3),
# which distinguish current/offset/lifecycle restoration. See design §5.

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: an invalid feed slice is accepted instead of raising"
  FIND [[(unless (and (bytevector? bv) (<= 0 start end (bytevector-length bv)))]]
  REPLACE [[(unless #t]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "invalid slice")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: an accepting feed does not record the stopped lifecycle"
  # Re-anchored for Slice ③ Task 2: Step 3(c) re-nests parser-feed!'s own
  # case-dispatch under a new `else` arm behind the lifecycle guard, so the
  # old FIND at the previous indentation no longer occurs. Same decision, same
  # reason -- only the surrounding indentation moved.
  FIND [[(case (parser-result-status r)
           ((stopped) (parser-set-lifecycle! parser 'stopped))]]
  REPLACE [[(case (parser-result-status r)
           ((stopped) (parser-set-lifecycle! parser 'ready))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "stopped after accept")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: a rejecting feed does not record the error lifecycle"
  # Re-anchored for Slice ③ Task 2: the error arm now also stores the parser-
  # result's error value (D1), so the old bare `((error) (parser-set-lifecycle!
  # parser 'error))` two-line pairing with the finished arm no longer occurs.
  # Still anchored on the same error-arm-then-finished-arm adjacency that makes
  # it unique to parser-feed! (parser-finish-v2! orders its arms differently).
  FIND [[((error) (parser-set-lifecycle! parser 'error)
                    (parser-set-stored-error! parser (parser-result-error r)))
           ((finished) (parser-set-lifecycle! parser 'finished))]]
  REPLACE [[((error) (parser-set-lifecycle! parser 'ready)
                    (parser-set-stored-error! parser (parser-result-error r)))
           ((finished) (parser-set-lifecycle! parser 'finished))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "error after reject")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: reset does not restore the entry state"
  FIND [[(parser-set-current! parser (parser-entry parser))]]
  REPLACE [[(parser-set-current! parser (parser-current parser))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "re-parses from entry")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: reset does not zero the stream offset"
  FIND [[(parser-set-offset! parser 0)]]
  REPLACE [[(parser-set-offset! parser (parser-offset parser))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "offset zeroed then advanced by one")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: reset does not return the lifecycle to ready"
  # Re-anchored for Slice ③ Task 2: parser-resume!'s new paused-feed arm adds a
  # second bare `(parser-set-lifecycle! parser 'ready)` occurrence, so the old
  # single-line FIND no longer disambiguates. Widened with the preceding
  # `(parser-set-offset! parser 0)` line, which occurs only in parser-reset!.
  FIND [[(parser-set-offset! parser 0)
    (parser-set-lifecycle! parser 'ready)]]
  REPLACE [[(parser-set-offset! parser 0)
    (parser-set-lifecycle! parser 'stopped)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "ready after reset")

# Milestone 2 Slice ②b-1's Task 2 (EOF execution) adds two more decisions to
# this pass: parser-finish-op!'s eof-target routing and its default-eof
# fallback. Neither is exercised by any feed-path or reset mutation above --
# they only run inside parser-finish!, which did not exist before this task.
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: an exhausted dispatch does not take its eof-target"
  FIND [[(op 'eof-target node)]]
  REPLACE [[#f]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "finished")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: a dispatch with no eof-target does not route to the default error"
  # Re-anchored for Slice ③ Task 2: Step 3(g)'s let-bound rewrite (D1's stored-
  # error site) deletes the old single-expression
  # `(make-parser-result 'error off 0 off (op 'default-eof-value))` this FIND
  # anchored. Same routing decision, same reason; the store itself is a
  # separate decision, tested below.
  FIND [[(let ((e (op 'default-eof-value)))
                          (parser-set-stored-error! parser e)
                          (make-parser-result 'error off 0 off e))))))]]
  REPLACE [[(let ((e (op 'default-eof-value)))
                          (parser-set-stored-error! parser e)
                          (make-parser-result 'stopped off 0 off e))))))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "default-eof")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: the default-eof arm does not store its value"
  # Same FIND anchor as the routing re-anchor above, a distinct decision:
  # dropping only the store (not the status) is witnessed by the brief's own
  # ②b-2-carry case, which reads the value back through a later feed.
  # Signature review: bare "stored error value" is a substring of a DIFFERENT
  # check's own label, "feed-stored error value" (the feed-side store's
  # witness below) -- pinned to this case's own name instead.
  FIND [[(let ((e (op 'default-eof-value)))
                          (parser-set-stored-error! parser e)
                          (make-parser-result 'error off 0 off e))))))]]
  REPLACE [[(let ((e (op 'default-eof-value)))
                          (make-parser-result 'error off 0 off e))))))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "default-EOF truncation: stored error value")

# Code-review fix for Task 2 (§12.2 finished x feed!): parser-feed-op!'s own
# `finish` arm -- a parser parked at a finish node re-fed returns finished,
# consuming zero -- had a functional test (finish-feed-op in runtime-tests.sps)
# but no witnessing mutation. This FIND is textually distinct from parser-
# finish-op!'s own 'finished result (off/0/off) two mutations above.
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: a feed on a finished parser does not return finished"
  FIND [[(make-parser-result 'finished pos (- pos start) (parser-offset parser) #f)]]
  REPLACE [[(make-parser-result 'stopped pos (- pos start) (parser-offset parser) #f)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "status")

# Milestone 2 Slice ②b-2's Task 1 (the dormant /v2 runtime machinery) adds two
# more decisions to this pass, both proven by the /v2 stub group in
# runtime-tests.sps. First: parser-finish-v2! must drive exec with finish? #t,
# not #f -- with #f, the empty-slice dispatch returns need-input instead of the
# default-eof error, so the finish case's `default-eof code` check reddens. The
# FIND's `empty-bv 0 0 #t` is unique to the finish driver (parser-feed-v2! calls
# exec with `bv start end #f`).
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: a /v2 finish does not drive exec with finish? true"
  FIND [[(o (exec (parser-current parser) (parser-offset parser) empty-bv 0 0 #t)))]]
  REPLACE [[(o (exec (parser-current parser) (parser-offset parser) empty-bv 0 0 #f)))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "default-eof code")

# Second: the /v2 constructor's ABI-version guard. It checks the literal 2 (the
# emitter still emits /v1, so current-abi-version stays 1), textually distinct
# from the /v1 guard's `(= abi-version current-abi-version)` above. Accepting any
# version lets the /v2 refusal test call it with abi 1 without raising.
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: a mismatched /v2 ABI version is accepted"
  FIND [[(unless (and (integer? abi-version) (= abi-version 2))]]
  REPLACE [[(unless #t]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "refused")

# Milestone 2 Slice ③'s Task 2 (pause/resume + the full §12.2 operation
# matrix, D1-D3) adds the rest of this pass: parser-resume! (its two acks and
# its own prohibited-cell else arm), the newly-prohibited feed/finish rows,
# the feed-side stored-error read, both pause arms in parser-feed-op!, the
# EOF-pause arm in parser-finish-op!, and the sticky short-circuit's consumed
# field. See the header narrative amendment beside EXPECTED_MUTATIONS for the
# accounting; several EXPECT_OUTPUT_MATCHES values below are measured, not the
# plan's prediction -- each says so where it differs.
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: resume on paused-feed reopens feed, not finish"
  # Measured, not the plan's predicted "continues past the pause": the
  # lifecycle corruption itself fails the case's own "lifecycle" check before
  # the next parser-feed! call is even reached; that call then raises (the
  # corrupted state is now a prohibited feed row), recorded as a second,
  # cascading "case raised" failure. Both are real. Review found bare
  # "lifecycle" itself substring-vacuous under a DIFFERENT mechanism than the
  # plan's prediction being wrong: harness.sls's FAIL-CONTEXT line prints
  # unconditionally on every failure and is not the risk here, but the
  # group name "one-byte parser lifecycle" and the case name "parser-
  # lifecycle tracks ready -> terminal" elsewhere in this file both also
  # contain "lifecycle", so a bare match does not by itself prove this is
  # the check that failed -- pinned to the owning case's own words instead.
  FIND [[((paused-feed) (parser-set-lifecycle! parser 'ready) 'feed-ready)]]
  REPLACE [[((paused-feed) (parser-set-lifecycle! parser 'finish-ready) 'feed-ready)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "acks feed-ready and reopens feed: lifecycle")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: resume on paused-finish acks finish-ready"
  # Review found bare "ack" substring-vacuous: harness.sls's FAIL-CONTEXT line
  # (printed on every recorded failure, harness.sls ~:394-402) contains
  # " backend=chez", and "ack" is a substring of "backend" -- so this
  # signature was satisfied by ANY failure, not this one. Pinned to the
  # owning case's own words instead.
  FIND [[((paused-finish) (parser-set-lifecycle! parser 'finish-ready) 'finish-ready)]]
  REPLACE [[((paused-finish) (parser-set-lifecycle! parser 'finish-ready) 'feed-ready)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "EOF path and resumes to finish-ready: ack")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: resume outside the paused rows is a prohibited cell"
  FIND [[(else (byte-machine-contract-violation 'parser-resume! 'lifecycle-violation
                                             (list (parser-lifecycle parser) 'resume)))]]
  REPLACE [[(else 'feed-ready)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "resume on ready")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: feed refuses every paused/finish-ready row"
  FIND [[((paused-feed paused-finish finish-ready)
       (byte-machine-contract-violation 'parser-feed! 'lifecycle-violation]]
  REPLACE [[((paused-finish finish-ready)
       (byte-machine-contract-violation 'parser-feed! 'lifecycle-violation]]
  # Slice 3 pin re-audit: "feed on paused-feed" is the right check, but the
  # sibling "a feed pause maps to paused-feed, not paused-finish" mutation
  # breaks the SAME check -- measured. The details differ and separate them:
  # this mutation makes the prohibited call return a tuple, that one leaves
  # the refusal in place but raises with the wrong lifecycle in it.
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "feed on paused-feed -- expected a raise, but the thunk returned")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: finish refuses the paused rows"
  FIND [[((paused-feed paused-finish)
       (byte-machine-contract-violation 'parser-finish! 'lifecycle-violation]]
  REPLACE [[((paused-finish)
       (byte-machine-contract-violation 'parser-finish! 'lifecycle-violation]]
  # Slice 3 pin re-audit: same collision and same separation as the feed row
  # above -- the paused-feed/paused-finish mapping mutation breaks this check
  # too, but by raising with the wrong lifecycle rather than by returning.
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "finish on paused-feed -- expected a raise, but the thunk returned")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: the error row returns the STORED error"
  FIND [[((error) (parser-set-lifecycle! parser 'error)
                    (parser-set-stored-error! parser (parser-result-error r)))]]
  REPLACE [[((error) (parser-set-lifecycle! parser 'error))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "feed-stored error value")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: a feed pause maps to paused-feed, not paused-finish"
  # Review found bare "ack" substring-vacuous (see the resume-on-paused-
  # finish mutation above for the mechanism); pinned to the owning case. A
  # later re-review found that fix itself sound but pointed at a downstream
  # consequence ("resume from a feed pause acks feed-ready...") rather than
  # the decision this mutation actually breaks -- the earlier case "feed
  # pauses at the pause node with the first unconsumed index" has its own
  # "lifecycle" check reading `current`'s lifecycle right after THIS arm
  # runs, which fails first and more directly. Re-pinned to that, measured.
  FIND [[((paused) (parser-set-lifecycle! parser 'paused-feed))]]
  REPLACE [[((paused) (parser-set-lifecycle! parser 'paused-finish))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "unconsumed index: lifecycle")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: the feed pause arm parks current on the continuation"
  FIND [[(parser-set-current! parser (op 'pause-target node))
             (make-parser-result 'paused pos (- pos start) (parser-offset parser) #f))]]
  REPLACE [[(make-parser-result 'paused pos (- pos start) (parser-offset parser) #f))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "continues past the pause")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: an EOF pause parks paused-finish, not paused-feed"
  # Review found bare "lifecycle" substring-vacuous by group/case-name
  # collision (see the resume-on-paused-feed mutation above); pinned to the
  # owning case. A later re-review found that fix still loose: the owning
  # case has two SIBLING checks whose own labels ("lifecycle now", "lifecycle
  # final") both start with the same word, so "...finish-ready: lifecycle" is
  # a prefix of all three FAIL lines and does not by itself say which one
  # failed (the intended one does fail here, cascading into "lifecycle now"
  # as a second, real failure -- both are caught, but the pin must name only
  # its own). The detail is on the same FAIL line, so extending into it (the
  # measured expected/actual pair, unique to this one check) makes the match
  # exact instead of a prefix.
  FIND [[(parser-set-lifecycle! parser 'paused-finish)
           (make-parser-result 'paused off 0 off #f))]]
  REPLACE [[(parser-set-lifecycle! parser 'paused-feed)
           (make-parser-result 'paused off 0 off #f))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "resumes to finish-ready: lifecycle -- expected paused-finish, got paused-feed")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: the stopped row short-circuits with consumed zero"
  # Review found bare "consumed" matches eight other check labels file-wide
  # (measured: this exact mutation also legitimately reddens two PRE-existing
  # tests that now exercise the same sticky short-circuit -- real, not
  # coincidental, but still not a signature that names only this decision).
  # Pinned to the owning case's own words.
  FIND [[((stopped) (make-parser-result 'stopped start 0 (parser-offset parser) #f))]]
  REPLACE [[((stopped) (make-parser-result 'stopped start 1 (parser-offset parser) #f))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "tuple: consumed zero")

# The plan's Task 2 predicted ten mutations for this pass; the whole-pass
# review it also mandated (AGENTS.md's exit-path rule) found three more
# decisions with no witness at all -- not just narrower than intended, catches
# nothing if broken:
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: a finish reaching a named error node does not store its value"
  # parser-finish-op!'s own plain error arm was unreachable by any fixture
  # before this task (nothing drove an eof-target chain into a NAMED error
  # node); the new pause-op stub's s1 -> 'trunc closes that gap and witnesses
  # both this store and the arm's routing together.
  FIND [[(let ((e (op 'error-value node)))
             (parser-set-stored-error! parser e)
             (make-parser-result 'error off 0 off e)))]]
  REPLACE [[(let ((e (op 'error-value node)))
             (make-parser-result 'error off 0 off e)))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "finish repeats the finish-stored error")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: a /v2 finish error does not store its value"
  # parser-finish-v2!'s own error arm is a separate call site from every op-
  # path store above: no existing /v2 fixture re-read the stored value, so a
  # dropped store here was invisible until this new case chains a second
  # finish! through the sticky read.
  FIND [[((error) (parser-set-lifecycle! parser 'error)
                 (parser-set-stored-error! parser (feed-outcome-error o)))]]
  REPLACE [[((error) (parser-set-lifecycle! parser 'error))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "finish repeats the stored /v2 error")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: a /v2 finish reaching a pause state does not record paused-finish"
  # parser-finish-v2!'s own paused arm -- distinct code from both the shared
  # parser-feed! wrapper's paused arm and parser-finish-op!'s pause arm, both
  # witnessed only through the op-path stub. No /v2 fixture reached a pause
  # state before stub-exec's new state 3.
  # Review found bare "lifecycle" substring-vacuous by group/case-name
  # collision (see the resume-on-paused-feed mutation above); pinned to the
  # owning case.
  FIND [[((paused) (parser-set-lifecycle! parser 'paused-finish)))]]
  REPLACE [[((paused) (parser-set-lifecycle! parser 'paused-feed)))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "sets paused-finish: lifecycle")

# Review also found two decisions this task's own new code left with no
# witness at all (distinct from the seven signature fixes above, which all
# WERE caught, just not provably for their own reason): parser-feed!'s
# finished sticky arm (no fixture repeated a feed after lifecycle was already
# 'finished) and the error sticky arm's `next` field (both existing witnesses
# used a zero start, making `start`, the literal 0, and (parser-offset
# parser) indistinguishable). Both are closed above in runtime-tests.sps and
# witnessed here.
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: the finished row short-circuits with consumed zero"
  # Review: the only one of this pass's recently-pinned signatures not
  # case-prefixed -- unlike its siblings above, this case's own name ends in
  # the parenthesised section reference "(section 12.2)", and CMake's MATCHES
  # is a real regex: unescaped "(" ")" would open a capture group instead of
  # matching literal parentheses, and "." inside the section number would
  # match any character, so a case-name tail is not a safe anchor here.
  # Extending into the detail instead (the measured expected/actual pair)
  # reaches the same exactness the case-tail gives the other eight, without
  # putting a metacharacter in the pattern.
  FIND [[((finished) (make-parser-result 'finished start 0 (parser-offset parser) #f))]]
  REPLACE [[((finished) (make-parser-result 'finished start 1 (parser-offset parser) #f))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "sticky consumed zero -- expected 0, got 1")

# Cleanup review (Task 2 follow-up): the mutation above witnesses the finished
# arm's FIELD VALUES, but not the arm's own existence -- deleting the whole
# `((finished) ...)` clause is a different mutant, declared and measured
# separately. parser-feed!'s outer case falls through to the shared `else`
# branch on a deleted clause, which for the 'op variant runs parser-feed-op!
# fresh from `current` -- still parked on the SAME finish node a prior finish!
# or feed! left it at. That loop's own `(finish)` case never advances `pos`
# past `start` (it fires before any byte is read), so it returns the
# byte-identical tuple (status 'finished, next start, consumed 0, offset and
# error untouched) the deleted sticky arm would have returned directly. The
# claim is scoped to 'op, for a reason that is EMPIRICAL, not structural.
# parser-feed!'s inner case records lifecycle 'finished from ANY variant whose
# executor returns status 'finished, so a v1 parser is not structurally barred
# from the sticky finished row -- parser-finish!'s raising v1 else arm only
# closes the finish! route, not the feed! one. What actually excludes it is
# this SPEC lane's fixtures: runtime-tests.sps's only v1 executor, stub-feed,
# has states 1 (stopped), 2 (error) and a dispatch else (need-input), and no
# state returning 'finished, so no v1 fixture here ever parks a parser at
# lifecycle 'finished. Likewise no /v2 fixture in this file re-feeds a parser
# parked at a finished state (stub-exec never returns 'finished either), so
# neither variant's own path is exercised either way.
# Measured: the mutant below passes the whole SPEC-lane suite unchanged
# (cases=35 failed-cases=0).
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: parser-feed!'s finished sticky arm is deleted outright"
  # REPLACE is a single space, not empty: CMake's cmake_parse_arguments (under
  # this file's own cmake_minimum_required, policy CMP0174 OLD) treats an
  # empty bracket argument as "not passed" and unsets arg_REPLACE, which would
  # trip byte_machine_mutation's own required-argument check. A lone space
  # deletes the clause just as effectively -- Scheme does not care about the
  # blank line it leaves between the preceding clause and `(else`.
  FIND [[((finished) (make-parser-result 'finished start 0 (parser-offset parser) #f))]]
  REPLACE [[ ]]
  EXPECT_SURVIVES
    "whole-arm deletion (as opposed to the field-value mutation above, which IS caught) falls through to parser-feed!'s shared `else` branch; for the 'op variant, parser-feed-op! run fresh from a `current` still parked on the same finish node reaches that loop's own `(finish)` case before advancing `pos`, producing the byte-identical result tuple this arm short-circuits to. The other two variants do not witness it either, for an EMPIRICAL reason rather than a structural one: parser-feed!'s inner case records lifecycle 'finished from ANY variant whose executor returns 'finished, so v1 is not barred from the sticky finished row (parser-finish!'s raising v1 else arm closes only the finish! route) -- but this file's only v1 executor, stub-feed, has no state that returns 'finished, and its /v2 stub-exec has none either, so no v1 or /v2 fixture here ever parks a parser at lifecycle 'finished. Measured directly: this mutant passes the whole SPEC-lane suite unchanged (cases=35 failed-cases=0)")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: the error row's next mirrors the new call's start, not the offset"
  FIND [[(make-parser-result 'error start 0 (parser-offset parser)]]
  REPLACE [[(make-parser-result 'error (parser-offset parser) 0 (parser-offset parser)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "after a feed error: next is the new start")

# parser-reset!'s stored-error clear (§12.5): declared, not silently
# unmutated. parser-stored-error is unexported, and its only two read sites
# both require lifecycle = 'error -- which parser-reset! unconditionally
# overwrites to 'ready in the very same call, before any read could observe
# what this line left behind. The only way lifecycle can become 'error again
# is through one of this file's four write sites (the feed wrapper, both
# finish variants, and the default-eof arm), every one of which stores a
# fresh value before or as part of its own transition into 'error -- so
# whatever this clear left behind is always overwritten first. Measured: the
# mutant below passes the whole suite unchanged (cases=35 failed-cases=0);
# EXPECT_SURVIVES is the honest declaration of that, not silence.
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: reset's stored-error clear is skipped"
  FIND [[(parser-set-stored-error! parser #f)]]
  REPLACE [[(parser-set-stored-error! parser (parser-stored-error parser))]]
  EXPECT_SURVIVES
    "parser-stored-error is unexported, so nothing outside this library can read the slot directly; its only two read sites (the error sticky arms in parser-feed! and parser-finish!) are both guarded by lifecycle = 'error, and parser-reset! unconditionally sets lifecycle to 'ready in this same call, so neither read site is reachable immediately after a reset. Reaching 'error again requires a fresh feed or finish that re-enters one of the four write sites, and every one of them stores its own value before or alongside its own lifecycle='error transition -- so a stale value left by a skipped clear is always overwritten before anything could observe it. Measured directly: this mutant passes the whole SPEC-lane suite unchanged")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 33: the verifier's decisions (Milestone 1 Phase 2) -----------------
#
# verify-tests.sps asserts the exact diagnostic CODE emitted for each broken
# variant of the one-byte machine (never rendered text, parent §16.4); this pass
# proves those code assertions are not vacuous by suppressing the decision that
# emits each code and requiring the owning case to notice. Verify command
# uses both library roots, an empty object guard, and the verify program.
# Each FIND is a verbatim, unique substring of verify.sls.

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/verify-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: reachability never reports an unreachable node"
  FIND [[(make-diagnostic 'unreachable-node (node-name n) "node is unreachable")]]
  REPLACE [[#f]] EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "unreachable-node")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: overlap check treats every byte as distinct"
  FIND [[(if (memv b seen)]]
  REPLACE [[(if #f]] EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "overlapping-cases")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: zero-progress detection never fires"
  FIND [[(if (and (or (byte-dispatch-node? n) (pause-node? n)) (reaches-self? (node-name n)))]]
  REPLACE [[(if #f]] EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "zero-progress-cycle")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the machine-name grammar check is suppressed"
  FIND [[(if (valid-name? (machine-name m)) '()]]
  REPLACE [[(if #t '()]] EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "invalid-name")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a missing transition target is not reported"
  FIND [[(make-diagnostic 'missing-target t "no such node")]]
  REPLACE [[#f]] EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "missing-target")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a duplicate node name is not reported"
  FIND [[(cons (make-diagnostic 'duplicate-name nm "duplicate node name") out)]]
  REPLACE [[out]] EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "duplicate-name")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: an undeclared error reference is not reported"
  FIND [[(if (and (error-node? n) (not (memq (error-node-error-name n) enames)))]]
  REPLACE [[(if #f]] EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "missing-error-declaration")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the default-eof-error membership check is suppressed"
  FIND [[(if (memq (machine-default-eof-error m) (error-names m)) '()]]
  REPLACE [[(if #t '()]] EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "invalid-eof-target")

# The remaining five decisions the verifier emits but the first eight mutations
# did not reach: the schema guard, the duplicate-error-declaration branch, the
# entry-resolution site of missing-target (distinct from the transition site
# above), and the node-name and error-code sites of the name-portability check
# (distinct from the machine-name site above). Each has its own rejection case
# in verify-tests.sps; the project's own SITES-2 split precedent (harness-group
# vs with-cleanup) requires each site of a multi-site decision to be witnessed.
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the schema guard accepts a non-machine"
  FIND [[(if (machine? m) '() (list (make-diagnostic 'invalid-shape #f "not a machine")))]]
  REPLACE [[(if #t '() (list (make-diagnostic 'invalid-shape #f "not a machine")))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "invalid-shape")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a duplicate error-declaration name is not reported"
  FIND [[(if (memq (car es) seen)]]
  REPLACE [[(if #f]] EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "duplicate-error-declaration")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: an entry that names no node is not reported"
  FIND [[(if (lookup nodes (machine-entry m)) '()]]
  REPLACE [[(if #t '()]] EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "missing-target")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the node-name grammar check is suppressed"
  FIND [[(if (valid-name? (node-name n)) #f]]
  REPLACE [[(if #t #f]] EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "invalid-name")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the error-code grammar check is suppressed"
  FIND [[(valid-name? (error-declaration-code e))]]
  REPLACE [[#t]] EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "invalid-name")

# Milestone 2 Slice ②b-1's Task 1 (decision 0011) adds three more decisions to
# this pass: the §16.2 EOF-execution checks. Each FIND is a verbatim, unique
# substring of pass-eof-execution / eof-terminal in verify.sls.
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a byte edge into a finish terminal is accepted"
  FIND [[(if (and tn (finish-node? tn))]]
  REPLACE [[(if (and tn #f)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "non-eof-into-finish")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: an EOF-reachable stop terminal is accepted"
  FIND [[((stop-node? n) 'eof-reachable-stop)]]
  REPLACE [[((stop-node? n) 'finish)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "eof-reachable-stop")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: an eof-target cycle is classified as a finish terminal"
  FIND [[(if (memq name seen) 'cycle]]
  REPLACE [[(if (memq name seen) 'finish]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "eof-zero-progress-cycle")

# Milestone 2 Slice ③'s Task 1 (the pause node) adds five more decisions to
# this pass: a pause continuation is an out-target for both name resolution
# (§16.2:905's missing-target) and reachability (node-out-targets); eof-
# terminal walks through a pause continuation instead of stopping at it;
# a byte-reachable pause into a finish node is rejected (§16.2:908, D4(b));
# a pause continuation joins the reexecute zero-progress walk (a pause
# consumes no input, so a pause-only or mixed reexecute/pause cycle makes no
# progress); and a byte-reachable pause's continuation chain is itself an EOF
# path, checked the same way a dispatch node's eof-target chain already is
# (§16.2:909, D4(d)). The zero-progress-detection mutation above is re-
# anchored in place: pass-zero-progress's guard widened from
# `(byte-dispatch-node? n)` to `(or (byte-dispatch-node? n) (pause-node? n))`
# so a pause could join the walk, which moved the FIND text but not the
# decision or the count. Passes stay at 37 and 123 + 5 = 128 mutations.
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a pause continuation is an out-target (resolution + reachability)"
  # Slice 3 pin re-audit: bare "missing-target" is this file's check label in
  # TWO other cases as well (the fallback-target and the entry-target
  # rejections), and the pair-wise matrix measured it matching both of their
  # mutants' FAIL lines -- so it named a diagnostic code, not a decision.
  # "missing-target diagnostic" is the pause case's own label and occurs
  # exactly once in verify-tests.sps. The case name itself ends in
  # "(§16.2:905)", whose parentheses are CMake regex metacharacters, so the
  # unique check label is the anchor rather than a case-name tail.
  FIND [[((pause-node? n) (list (pause-node-continuation n)))
          (else '())]]
  REPLACE [[((pause-node? n) '())
          (else '())]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "missing-target diagnostic")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: eof-terminal chains through a pause continuation"
  # Slice 3 pin re-audit: bare "eof-zero-progress-cycle" is a diagnostic code,
  # not a check -- measured matching the pre-Slice-3 eof-target-cycle case's
  # own "has eof-zero-progress-cycle" check (a different decision) and this
  # pass's later "no eof-zero-progress-cycle attributed to pa" check (a
  # different check in the same case). Anchored to the case tail plus the one
  # check label; the case name carries no parentheses, so the tail is safe.
  FIND [[((pause-node? n) (loop (pause-node-continuation n) (cons name seen)))]]
  REPLACE [[((pause-node? n) 'finish)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "zero-progress EOF cycle: eof-zero-progress-cycle diagnostic")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a byte-reachable pause into finish is rejected"
  # Slice 3 pin re-audit: bare "non-eof-into-finish" is a diagnostic code and
  # was measured matching the pre-Slice-3 byte-edge-into-finish case's own
  # "has non-eof-into-finish" check -- a different decision. This case's own
  # label is "non-eof-into-finish diagnostic", which occurs exactly once in
  # verify-tests.sps; the case name ends in "(§16.2:908)", so parenthesis-free
  # anchoring means the check label rather than a case-name tail.
  FIND [[(if (and cn (finish-node? cn))]]
  REPLACE [[(if (and cn #f (finish-node? cn))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "non-eof-into-finish diagnostic")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: pause continuations join the zero-progress walk"
  # Later review: bare "zero-progress-cycle" is a substring of three other
  # check labels in this file (the pre-Slice-3 mutation above reuses it, and
  # "eof-zero-progress-cycle diagnostic"/"zero-progress-cycle diagnostic" are
  # each a distinct decision), so it does not by itself prove which one
  # failed. Measured: this mutation's own primary witness is the reexecute/
  # pause-only cycle case; pinned to it.
  FIND [[((pause-node? n) (list (pause-node-continuation n)))
              (else '())]]
  REPLACE [[((pause-node? n) '())
              (else '())]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "cycle with no advance makes no progress: zero-progress-cycle diagnostic")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a byte-reachable pause's continuation chain is an EOF path"
  # Slice 3 pin re-audit: bare "eof-reachable-stop" is a diagnostic code, and
  # "eof-reachable-stop diagnostic" is a check label THREE cases share, so
  # neither anchors this decision -- both were measured matching the
  # pre-Slice-3 eof-target-into-stop case and the EOF-chain-through-a-pause
  # case, each a different decision. The entry-pause case is the one that
  # witnesses BYTE-reachability specifically, its label "entry
  # eof-reachable-stop diagnostic" occurs once, and its case name carries no
  # parentheses, so the pin is that case's tail plus that label.
  FIND [[(case (eof-terminal m (pause-node-continuation n))]]
  REPLACE [[(case 'finish]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "so its chain is walked too: entry eof-reachable-stop diagnostic")

# Task 1's whole-branch review found two of the five decisions above were
# unwitnessed, not just uncaught -- neither test nor mutation reached them --
# and added a mutation for each rather than leaving a gap. First: the PASS 5
# filter guard's `(pause-node? n)` disjunct (line ~160) had no witness at
# all. The only existing pause-in-a-cycle fixture (the reexecute/pause-only
# cycle above) has the byte-dispatch node `e0` itself in the cycle, so
# narrowing the guard back to byte-dispatch-only still flags `e0` and the
# fixture's diagnostic-code check passes either way -- a guard shown not to
# guard. The witness was already sitting in the pa->pb->pa EOF-pause-cycle
# fixture used by the eof-zero-progress-cycle mutation above: pa/pb form a
# zero-width cycle with NO byte-dispatch node in it, so PASS 5 (a completely
# separate check from the eof-target-chain walk that fixture was built for)
# flags them only when the disjunct admits pause nodes. A second check --
# "zero-progress-cycle diagnostic" -- was added to that case in
# verify-tests.sps, confirmed by hand to fail when the guard is narrowed
# back (and only that one case fails: e0's own PASS-5 flag in the
# reexecute/pause-only fixture, and every other case, is unaffected).
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a pause-only zero-progress cycle is not flagged"
  # Later review: bare "zero-progress-cycle" is shared with three other check
  # labels in this file (see the mutation above); pinned to the specific
  # fixture the case-header comment above already names as this decision's
  # own witness (the pa->pb->pa EOF-pause cycle).
  FIND [[(if (and (or (byte-dispatch-node? n) (pause-node? n)) (reaches-self? (node-name n)))]]
  REPLACE [[(if (and (byte-dispatch-node? n) (reaches-self? (node-name n)))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "chain of pauses that cycles is a zero-progress EOF cycle: zero-progress-cycle diagnostic")

# Second: the `(memq (node-name n) br)` byte-reachability gate shared by both
# D4(b)/(d) checks above -- the entire reason `byte-reached` exists -- had a
# test witness (dropping it makes the well-formed fixture's `pe -> done`
# illegal) but no mutation. The guard text is identical at both call sites,
# so a bare FIND double-matches (confirmed: 2 occurrences) and widening to a
# two-line FIND including each site's next line (`(let ((cn ...` vs.
# `(case (eof-terminal ...`) makes each unique without restructuring the
# shared shape. Measured both candidates directly rather than assuming
# either witnessed the decision: dropping the gate at the second site (the
# eof-terminal-chain check) is NOT CAUGHT by this suite at all (exit 0) --
# every EOF-only-reachable pause fixture's continuation either resolves to
# `'finish` (no diagnostic either way) or to a stop/cycle the dispatch node's
# own, ungated :909 walk above already flags with the identical code, so the
# gate's removal there produces only a redundant duplicate diagnostic no
# check distinguishes (the whole-branch review's Minor item on duplicate
# same-code diagnostics is the same underlying gap). Dropping it at the
# first site (the non-eof-into-finish check) is cleanly caught: the
# well-formed fixture's `pe` (eof-only-reachable, continuation a finish
# node) newly and wrongly reports non-eof-into-finish, so that fixture's
# sole "accepted" check -- the only case in this file using that label --
# fails. That site is used below.
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a pause's byte-reachability gate is not checked (non-eof-into-finish)"
  # Slice 3 pin re-audit: bare "accepted" is a check label, but nothing in it
  # names the case, so any future case reusing the word would satisfy it.
  # Anchored to the case tail as well; the case name carries no parentheses.
  FIND [[(if (and (pause-node? n) (memq (node-name n) br))
                            (let ((cn (lookup nodes (pause-node-continuation n))))]]
  REPLACE [[(if (pause-node? n)
                            (let ((cn (lookup nodes (pause-node-continuation n))))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "pause machine verifies: accepted")

# Cleanup follow-up: the second site's gap above is closed here too -- not by
# VERDICT (still genuinely impossible, per the measurement above) but by
# ATTRIBUTION. diagnostic-node was already exported but unused by any test.
# Under correct code, the pa->pb->pa fixture's sole eof-zero-progress-cycle
# diagnostic is attributed to the entry dispatch node e0 (the pre-existing,
# ungated :909 walk), never to pa or pb -- neither is byte-reached, so this
# site's gate never lets them contribute one. Two new checks in that fixture
# assert this by NODE, not just by CODE: confirmed by hand that ungating this
# site (below) makes "no eof-zero-progress-cycle attributed to pa" fail --
# pa now gets its own copy of the diagnostic, redundant by code (matching the
# measurement above) but distinct by attribution, which is what the new check
# was written to see.
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a pause's byte-reachability gate is not checked (eof-terminal chain)"
  FIND [[(if (and (pause-node? n) (memq (node-name n) br))
                            (case (eof-terminal m (pause-node-continuation n))]]
  REPLACE [[(if (pause-node? n)
                            (case (eof-terminal m (pause-node-continuation n))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "chain of pauses that cycles is a zero-progress EOF cycle: no eof-zero-progress-cycle attributed to pa")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 34: the reference interpreter (Milestone 1 Phase 2) ----------------
#
# interpret-tests.sps runs the verified one-byte machine over all 256 byte
# values through the runtime and refuses an unverified machine; this pass proves
# those checks are not vacuous. The first mutation makes dispatch match every
# byte to the first case, so bytes 1..255 wrongly accept and the all-256 case
# fails; the second disarms the unverified-machine refusal, so the refuse case's
# check-raises sees a normal return. Verify command uses both library roots,
# an empty object guard, the interpret program.

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/interpret-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.interpret.chez.source
  LABEL "interpret: dispatch matches every byte to the first case"
  FIND [[((= byte (exact-byte-matcher-byte (byte-case-matcher (car cs))))]]
  REPLACE [[(#t]] EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "no byte in 1..255 misbehaved")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.interpret.chez.source
  LABEL "interpret: an unverified machine is accepted"
  FIND [[(unless (verification-ok? verification)]]
  REPLACE [[(when #f]] EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "refused")

# Milestone 2 Slice ②b-1's Task 2 (EOF execution): a finish node no longer
# reports the `finish` kind, so parser-finish! never reaches its `finish` arm
# and the idle-completion case's "finished" check fails.
byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.interpret.chez.source
  LABEL "interpret: a finish node is not reported as a finish kind"
  FIND [[((finish-node? n) 'finish)]]
  REPLACE [[((finish-node? n) 'stop)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "finished")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 35: the normalizer (Milestone 1 Phase 3 Slice A) --------------------
#
# normal-ir-tests.sps pins the IR fingerprint of the one-byte machine (a golden
# value) and the structural decisions (entry id, transition sort, error-code
# resolution). This pass proves those checks are not vacuous. Verify command
# uses both library roots, an empty object guard, the normal-ir program.

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/normal-ir-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the FNV offset basis is changed"
  FIND [[(define fnv-offset 14695981039346656037)]]
  REPLACE [[(define fnv-offset 14695981039346656038)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "4236938459847922092")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the FNV prime is changed"
  FIND [[(define fnv-prime  1099511628211)]]
  REPLACE [[(define fnv-prime  1099511628212)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "4236938459847922092")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the byte is never mixed into the hash"
  FIND [[(* (bitwise-xor h (bytevector-u8-ref bv i)) fnv-prime)]]
  REPLACE [[(* h fnv-prime)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "4236938459847922092")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the entry id is hard-wired to node 0"
  FIND [[(entry (id-of (machine-entry machine)))]]
  REPLACE [[(entry 0)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "entry")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: dispatch cases are not sorted ascending by byte"
  FIND [[(list-sort (lambda (a b) (< (car a) (car b)))]]
  REPLACE [[(list-sort (lambda (a b) (> (car a) (car b)))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "bytes")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: an error node resolves to the declaration name, not its code"
  FIND [[(error-declaration-code (car es)) (loop (cdr es))]]
  REPLACE [[(error-declaration-name (car es)) (loop (cdr es))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "unexpected-byte")

# Milestone 2 Slice ②b-2 (Task 2): the dispatch eof routing is now part of the
# canonical encoding, so a dispatch state's resolved eof (the one-byte machine
# routes to the default-eof error, code 'eof) is mixed into the fingerprint.
# Dropping the default-eof code from the encoding moves the one-byte golden, so
# normal-ir-tests.sps's fingerprint case reddens against the re-baselined value.
byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a dispatch's default-eof routing is not encoded into the fingerprint"
  FIND [[(begin (put-u8 p 1) (put-symbol p (cdr eof)))]]
  REPLACE [[(begin (put-u8 p 1))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "4236938459847922092")

# Milestone 2 whole-branch review (item d): the NODE-eof encode arm -- tag 0 +
# u32be routed node id -- had no witnessing mutation and no golden, because no
# machine in this SPEC lane routed eof to a named node. The mutation above only
# witnesses the DEFAULT arm (tag 1 + code symbol), reached by the one-byte
# machine, whose eof goes to the default-eof error. normal-ir-tests.sps now pins
# a second golden over the shared eof-machine, whose s0/s1 BOTH route eof to
# named nodes (finish 'done, error 'trunc), so dropping the routed node id from
# the canonical encoding moves ONLY that node-routing golden (the one-byte golden
# is untouched) and its fingerprint case is the sole witness. Distinct verbatim
# FIND from the default arm above (the '(cdr eof)' payload differs by encoder),
# so SITES stays 1.
byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a dispatch's node-eof routing target is not encoded into the fingerprint"
  FIND [[(begin (put-u8 p 0) (put-u32be p (cdr eof)))]]
  REPLACE [[(begin (put-u8 p 0))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "9098559711816935340")

# Milestone 2 Slice ③'s Task 4 (the pause node in the normalizer) adds three
# more mutations to this pass rather than opening a new one. normal-ir-
# tests.sps gains a "pause normalization" group over the shared pause-machine
# fixture (s0 p1 s1 pe stop done trunc reject -> ids 0-7): a structural case
# (p1/pe's kind and resolved continuation target) and a fingerprint golden
# case, measured (not guessed) through the shipped encode arm.
#
# The lower-arm mutation below stores a pause node's OWN id instead of its
# resolved continuation id. Measured: it fails "p1 target" (expected 2, got 1)
# and "pe target" (expected 5, got 3) -- the structural checks, which print
# the actual wrong id -- AND, as a side effect, "pause fingerprint" (the wrong
# id is also what gets hashed). EXPECT_OUTPUT_MATCHES pins the structural
# check, the more precise of the two witnesses.
byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a pause lowers its continuation id, not its own"
  FIND [[(cons 'node (id-of (pause-node-continuation n)))]]
  REPLACE [[(cons 'node i)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "p1 target")

# The encode-arm mutation drops the continuation id from the pause tag's
# encoded bytes (tag 4 alone, no u32be payload). Measured: it fails ONLY
# "pause fingerprint" -- no other machine in this SPEC lane has a pause node,
# so tag 4 is never encoded for the one-byte or node-routing goldens above,
# and this mutation cannot disturb them.
#
# Golden-family note, CORRECTED by the Slice ③ pin re-audit. The original
# note argued that "pause fingerprint" needs neither a numeral nor a got
# value because the check label is unique in normal-ir-tests.sps -- "a
# stronger position than the five above". Uniqueness of the LABEL is not the
# question the pin answers. The pair-wise matrix measured this label's FAIL
# line in the output of SEVEN other mutants of this same pass: every
# fingerprint-affecting mutation in the lane (FNV offset, FNV prime, byte
# mixing and error-code resolution -- the four that pin "4236938459847922092"
# -- node-eof routing, which pins "9098559711816935340", the pause lower arm,
# and the tag-value mutation below) moves the pause golden too, because the
# pause machine is hashed by the same algorithm. So the bare label said only
# "some fingerprint moved". What separates the siblings is the got value, which is
# distinct for each -- so both pause-encoding mutations below carry theirs.
# That is the same convention as the five above, applied where it is now
# measured to be necessary, and the re-baseline cost is real but bounded: a
# future IR-encoding move already re-baselines the pause golden itself
# (15725897457025557005, in normal-ir-tests.sps), and these two move with it.
byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the pause encode arm hashes tag and continuation"
  FIND [[((pause) (put-u8 p 4) (put-u32be p (normal-pause-target s)))]]
  REPLACE [[((pause) (put-u8 p 4))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "pause fingerprint -- expected 15725897457025557005, got 6626362746927380524")

# A third mutation targets the pause TAG VALUE alone (4 -> 3, colliding with
# finish's own tag byte) rather than the whole payload mutation 2 above
# already covers -- proving the tag byte itself, not just the u32be
# continuation id after it, is mixed into the fingerprint. Left unwitnessed,
# nothing would notice the two kinds' tag bytes becoming equal. (Their
# encodings as a whole stay distinguishable even then: a pause state still
# emits the 4 payload bytes a finish state does not.) Measured: it fails
# ONLY "pause fingerprint" (1 of 23 checks) -- same reasoning as mutation 2
# above: no other machine in this SPEC lane has a pause node, so this arm is
# never reached encoding the one-byte or node-routing goldens. It is witnessed
# by the same check as mutation 2 -- the Slice ③ pin re-audit's finding is
# that a SHARED pin over that check therefore named neither decision (see the
# corrected golden-family note above), so each carries its own measured got
# value instead.
byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the pause tag collides with finish's tag"
  FIND [[(put-u8 p 4)]]
  REPLACE [[(put-u8 p 3)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "pause fingerprint -- expected 15725897457025557005, got 5068390459764251309")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 36: the emitter (Milestone 1 Phase 3 Slice A) ----------------------
#
# compile-tests.sps checks the compilation contract, the binding reserved-set
# (all three members), and the rendered library structure by substring. This
# pass proves those checks are not vacuous. Verify command uses both library
# roots, an empty object guard, the compile program.

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/compile-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: a non-empty option list is accepted"
  FIND [[(unless (null? options)]]
  REPLACE [[(unless #t]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "refused")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: an invalid machine is reported as compiled ok"
  FIND [[(if (verification-ok? v)]]
  REPLACE [[(if #t]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "not ok")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: an unverified compilation is rendered anyway"
  FIND [[(unless (compilation-ok? compilation)]]
  REPLACE [[(unless #t]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "not ok")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: the binding grammar check is dropped"
  FIND [[(and (> (string-length s) 0) (lower-alpha? (string-ref s 0))]]
  REPLACE [[(and #t (lower-alpha? #\a)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "grammar")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: reserved member 1 is not checked"
  FIND [[(not (memq sym reserved-member-1))]]
  REPLACE [[#t]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "member 1")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: reserved member 2 is not checked"
  FIND [[(not (memq sym reserved-member-2))]]
  REPLACE [[#t]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "member 2")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: reserved member 3 is not checked"
  FIND [[(not (memq sym reserved-member-3))]]
  REPLACE [[#t]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "member 3")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: an advance transition is lowered as a reexecute"
  FIND [[(string-append "(loop (+ pos 1) " (number->string target) " (+ off 1))")]]
  REPLACE [[(string-append "(loop pos " (number->string target) " off)")]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "advance arm")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: the reexecute fallback is lowered as an advance"
  FIND [[(string-append "(loop pos " (number->string target) " off)")]]
  REPLACE [[(string-append "(loop (+ pos 1) " (number->string target) " (+ off 1))")]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "fallback")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: the error arm omits the resolved code"
  FIND [[(symbol->string (normal-error-code s)) ") " id " off))\n")]]
  REPLACE [["internal" ") " id " off))\n")]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "error arm")

# Milestone 2 Slice ②b-2 (Task 2): the emitter renders the /v2 unified `exec`
# with a finish? EOF branch and a distinct finish terminal arm. compile-tests.sps
# gains a finish-node fixture (eof-fin) whose entry dispatch routes eof to a
# finish node, so all three new emitter decisions have a witness in the compile
# SPEC lane. Each FIND is a unique verbatim substring.
byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: a finish node renders the stopped terminal instead of finished"
  FIND [[(quote finished) pos #f " id " off))\n"]]
  REPLACE [[(quote stopped) pos #f " id " off))\n"]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "finish arm")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: the exhausted-dispatch eof branch drops the resolved default-eof code"
  FIND [[(symbol->string (cdr eof)) ") " id " off)")]]
  REPLACE [["internal" ") " id " off)")]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "eof routes to the default-eof error")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: the exhausted dispatch does not branch on finish?"
  FIND [[(if finish?\n"]]
  REPLACE [[(if #f\n"]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "finish eof guard")

# Milestone 2 Slice ③'s Task 4 (the pause node in the emitter) adds two more
# mutations to this pass. compile-tests.sps gains a third inline fixture (the
# pause machine, following the eof-fin precedent above -- the compile lanes
# carry no fixture libraries, and (byte-machine test pause-machine) is the
# source of truth the fixture is kept in sync with by hand) whose rendered
# text pins both pause arms: p1's (continuation target 2) and pe's
# (continuation target 5).
#
# Both mutations below break the SAME two checks, "pause arm p1" and "pause
# arm pe". As shipped, those two were substring probes under `check`, whose
# failure text is content-blind ("expected a true value"), so the shared
# "pause arm" pin was measured matching BOTH mutants' FAIL lines: it proved a
# pause arm was wrong, never which of the two emitter decisions was wrong.
# The Slice ③ pin re-audit turned them into check-equal over the status token
# and the next state read out of that one rendered arm line
# (compile-tests.sps's `pause-arm`), so the detail now carries the mutant's
# own answer and each mutation pins its own measured signature. Splitting the
# substring probe in two -- the other remedy on the table -- does NOT work: a
# pause continuation is a dispatch node whose own need-input arm parks on that
# same state id, so " pos #f 2 off))" survives the next-state mutation
# elsewhere in the rendered text and a target-only probe would be vacuous.
byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: the pause arm emits paused"
  FIND [[(quote paused) pos #f "]]
  REPLACE [[(quote stopped) pos #f "]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "pause arm p1 -- expected \"paused 2\", got \"stopped 2\"")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: the pause arm's next-state is the continuation"
  FIND [[(number->string (normal-pause-target s)) " off))\n"))]]
  REPLACE [[id " off))\n"))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "pause arm p1 -- expected \"paused 2\", got \"paused 1\"")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 37: D7 identifier repertoire + LF (Slice B) -------------------------
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/identifier-repertoire-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.identifier-repertoire.chez.source
  LABEL "verify: a name with a non-lowercase first char is accepted"
  FIND [[(lower-alpha? (string-ref s 0))
           (let loop ((i 1))]]
  REPLACE [[#t
           (let loop ((i 1))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "reject")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.identifier-repertoire.chez.source
  LABEL "verify: any interior character is accepted"
  FIND [[(or (lower-alpha? c) (and (char>=? c #\0) (char<=? c #\9)) (char=? c #\-)))
  (define (valid-name? sym)]]
  REPLACE [[#t)
  (define (valid-name? sym)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "reject")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.verify.identifier-repertoire.chez.source
  LABEL "compile: any interior binding character is accepted"
  FIND [[(or (lower-alpha? c) (and (char>=? c #\0) (char<=? c #\9)) (char=? c #\-)))
  (define (valid-binding? sym)]]
  REPLACE [[#t)
  (define (valid-binding? sym)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "reject")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.verify.identifier-repertoire.chez.source
  LABEL "compile: the final newline is emitted as CRLF"
  FIND [[" exec)))\n"))))]]
  REPLACE [[" exec)))\r\n"))))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "carriage return")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 38: D6 determinism vs golden (Slice B) -----------------------------
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/determinism-one-byte-tests.sps"
  # the golden lives in the source tree; the staged program reads it via env
  # (BYTE_MACHINE_GOLDEN_FILE, supplied by this suite's own ctest registration
  # and inherited unmodified through execute_process -- see "WHAT THIS SUITE
  # NEEDS FROM ITS ENVIRONMENT" above)
  )

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.determinism.one-byte.chez.source
  LABEL "compile: the writer's export line spacing changes"
  FIND [["  (export " bstr ")\n"]]
  REPLACE [["  (export  " bstr ")\n"]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "golden")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 39: property differential is non-vacuous (Slice B; Slice ③ Task 6
# joined three more mutations here rather than opening a new pass -- see the
# EXPECTED_PASSES/EXPECTED_MUTATIONS header above) ---------------------------
#
# Slice A's Pass 36 already witnesses the advance-arm lowering against one
# fixed machine; this re-anchors the same lowering mutation against the
# *property* lane, so the generated-machine differential is proven to notice
# divergence too, not just the fixed one-byte example. Verify command modelled
# on the differential/determinism passes above.
#
# Slice ③ Task 6 adds three more mutations under the same verify command,
# since all three run this same property-differential-tests.sps program: the
# driver's own resume handling (property-differential-tests.sps), and the
# eof and pause draws' probability lines (machine-gen.sls) -- see the header
# comment above EXPECTED_PASSES/EXPECTED_MUTATIONS for why each is
# witnessable only via a new anti-vacuity assertion, not the lane's
# pre-existing checks.
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/property-differential-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.property.differential.chez.source
  LABEL "compile: the dispatch byte test is inverted, diverging from the oracle"
  FIND [[(number->string (car tr)) ") "]]
  # The brief's own draft used `modulo`; compile.sls imports only (rnrs),
  # which exports `mod` (not the Chez/R5RS `modulo`), so `modulo` here is an
  # unbound identifier -- confirmed by reproducing by hand: the mutated
  # library raised "unbound identifier modulo" at load time and the verify
  # command exited 255, not the deliberate status-1 harness failure this
  # mutation is supposed to witness (MutationRunner.cmake's "wrong reason"
  # check catches exactly this). `mod` is what (rnrs base) actually exports,
  # confirmed the same way: the same repro then failed cleanly on all 40
  # generated machines with "byte agreement" in the output and status 1.
  REPLACE [[(number->string (mod (+ 1 (car tr)) 256)) ") "]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "byte agreement")

byte_machine_mutation(
  FILE test/common/property-differential-tests.sps
  SPEC byte-machine.property.differential.chez.source
  LABEL "property-differential: resume-pair! stops calling parser-resume!"
  FIND [[(list (parser-resume! pr) (parser-resume! pg))]]
  REPLACE [[(list 'feed-ready 'feed-ready)]]
  # Measured: skipping the real resume leaves both parsers at paused-feed;
  # the driver's own next feed call (feed-loop!'s post-resume re-feed) then
  # trips runtime.sls's own lifecycle-violation guard, which the driver does
  # not catch, so harness-case's guard records it as "case raised" with the
  # condition's own description:
  #   code: lifecycle-violation who*: parser-feed! detail: (paused-feed feed)
  # Pinned to the measured detail tuple, not the bare code: "paused-feed
  # feed" is metacharacter-free (a literal substring under CMake MATCHES)
  # and specific to this one lifecycle/op pair, whereas the code alone would
  # also match a lifecycle-violation raised for any other reason. Printed by
  # nothing else in this program's output.
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "paused-feed feed")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-gen.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "machine-gen: the pause draw's coin is hard-wired to false"
  FIND [[(pause-drawn? (= pausei 0))]]
  REPLACE [[(pause-drawn? #f)]]
  # No case ever offers pausep as a target, so no generated machine ever
  # includes one; property-differential-tests.sps's paused-count assertion
  # (added alongside the pause/resume/finish schedule, Task 6) fails at 0.
  # Pinned to the assertion's own words, unique to this one check.
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "observes a pause")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-gen.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "machine-gen: the eof draw's coin is hard-wired to false"
  FIND [[(eof? (= eofi 0))]]
  REPLACE [[(eof? #f)]]
  # No dispatch node's eof-target is ever `done`, so no generated machine
  # ever reaches `finished`; property-differential-tests.sps's
  # finished-count assertion (added by Task 6's review-fix round, mirroring
  # paused-count) fails at 0. Pinned to the assertion's own words, unique to
  # this one check.
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "idle-completion finish")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 40: member-2 drift guard (Slice B) ---------------------------------
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/reserved-drift-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.reserved-drift.chez.source
  LABEL "compile: reserved-member-2 drops a runtime export (silent drift)"
  FIND [[make-parser parser? parser-feed!]]
  REPLACE [[make-parser parser?]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "no drift between reserved-member-2")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 41: the interpreter's pause kind and pause-target message (Slice ③,
# Task 3) -------------------------------------------------------------------
#
# pause-interpret-tests.sps drives the shared pause-machine (byte-machine test
# pause-machine) end-to-end through the interpreter's pause arms and the
# runtime's paused-feed/paused-finish/finish-ready lifecycle. This pass proves
# that coverage is not vacuous. The first mutation makes a pause node report
# kind 'stop instead of 'pause -- no node in any earlier SPEC lane's fixture
# was ever a pause-node?, so this decision was unreachable before this task's
# fixture existed -- and the feed-pause case's own "paused" check (byte 1
# pausing) fails first. The second mutation makes pause-target resolve to the
# pause node's own name instead of its continuation, so `current` never
# advances past the pause (D3) and the resumed feed re-enters the same pause
# node instead of consuming byte 2; the same case's "stopped" check (byte 2
# stopping after resume) fails. Both signatures are the exact case-name tail
# ("byte 2 stops") plus the one check label each mutation breaks first, unique
# in this program's own check vocabulary -- neither collides with the other
# mutation's own pin, a group name, or a `-- <detail>` tail. Verify command
# uses both library roots, an empty object guard, the pause-interpret program.

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/pause-interpret-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.pause-interpret.chez.source
  LABEL "interpret: a pause node has its own kind"
  FIND [[((pause-node? n) 'pause)]]
  REPLACE [[((pause-node? n) 'stop)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "byte 2 stops: paused")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.pause-interpret.chez.source
  LABEL "interpret: pause-target resolves the continuation, not the pause itself"
  FIND [[((pause-target) (pause-node-continuation (lookup nodes (car args))))]]
  REPLACE [[((pause-target) (car args))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "byte 2 stops: stopped")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# Every pass above has now run exactly once, so the accumulated total is
# final. Compared against the numbers declared at the top of this file --
# see EXPECTED_PASSES and EXPECTED_MUTATIONS, and the "THIRTY-ONE PASSES"
# header comment they restate -- so a whole pass, or a single mutation inside
# one, silently going missing is a build failure here rather than a stale
# comment nobody rereads.
byte_machine_mutation_totals(actual_passes actual_mutations)
if(NOT actual_passes EQUAL EXPECTED_PASSES OR NOT actual_mutations EQUAL EXPECTED_MUTATIONS)
  message(FATAL_ERROR
    "byte-machine-mutation: expected ${EXPECTED_PASSES} passes / "
    "${EXPECTED_MUTATIONS} mutations, got ${actual_passes} "
    "passes / ${actual_mutations} mutations. A byte_machine_mutation_run call -- "
    "a whole pass -- or a byte_machine_mutation() declaration within one was "
    "deleted, or one was added without updating the expected count at the top "
    "of this file. This is what notices a deleted pass group when every "
    "individual specification still reports green.")
endif()

message(STATUS
  "byte-machine-spec: scheme mutation suite complete (${actual_passes} passes, "
  "${actual_mutations} mutations)")
