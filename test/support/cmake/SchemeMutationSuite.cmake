# Proof that the Scheme harness's self-tests are not vacuous.
#
# The harness is the instrument every later milestone is measured with. If
# `check-equal` silently always returned true, the whole project would go green
# and stay green, and no test written with `check-equal` could notice. So each
# decision in the runner is broken in turn on a staged copy, and the self-tests
# must fail.
#
# FIFTY-EIGHT PASSES, BECAUSE FIFTY-EIGHT DIFFERENT WITNESSES ARE NEEDED
# (46 through Milestone 3; Milestone 4 Slice ①a adds the member-3 drift
# guard and the position-kind lane, and Slice ①b the field-access lane -- since
# renamed byte-machine.differential.field, the only lane in which the field
# declarations are observable at all. The count in prose and the count the
# constants enforce are kept in step deliberately -- a banner left at the
# old number is the one surface no test can check.
#
# *** Which it demonstrated. *** Slice ①b's Important fix wave RECORDED this
# banner as corrected to FORTY-NINE and it was not: the edit was in a batch that
# aborted on an earlier assertion, and nothing failed, because nothing can. The
# claim sat in a merged commit message for a slice and a half. Corrected by
# Slice ② task 10, which found it by running the check the commit claimed to
# have run. Milestone 5 Slice ② adds the FIFTY-THIRD: the differential lane over
# the callback node, which is the only program in the tree that loads a
# generated library containing a callback state. Slice ③ adds the FIFTY-FOURTH
# on the same argument one kind later -- the differential lane over the two span
# kinds, the only program that loads a generated library containing a span
# state, and the only one that can see a span FRAGMENT at all, since no parser
# result carries one. Slice ④ adds the FIFTY-FIFTH, and this one IS a separate
# witness rather than a second reading of an existing lane: it is the only
# program in the tree that observes what a parser still REACHES after
# `parser-feed!` returns, which no result, no trace and no diagnostic can show.
# It is NOT a fifty-sixth: Slice ③'s verifier mutations run
# against that same lane, because its topology table is where §25:1590's set is
# written down -- one witness read two ways, and a pass count that called it two
# would be the banner claiming a witness the tree does not have.)
#
# Milestone 6 adds the FIFTY-SIXTH through FIFTY-EIGHTH: the counted-consume
# differential and the counted body inside a span, the lanes that load a
# generated library containing a counted-consume state and observe a counted
# fragment. (This banner sat at FIFTY-FIVE through Milestone 6; corrected to
# FIFTY-EIGHT by Milestone 7 Slice ②, which found it the way the FORTY-NINE claim
# above was found — by reading the constant it enforces, EXPECTED_PASSES = 58.)
# Milestone 7's slices ⓪, ① and ② add NO pass: ⓪ and ① re-anchor and widen
# existing passes, and Slice ②'s new mutations join the existing Pass 39 (the
# property differential), so the property generator and its three comparison
# layers are witnessed there rather than by a fifty-ninth. Slice ③ DOES add the
# FIFTY-NINTH: the fixture lane (property-fixture-tests.sps), whose printer,
# saver and minimizer are a distinct witness -- three caught mutations and one
# declared survivor (the 64-emission bound, F10) -- so EXPECTED_PASSES = 59.
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
# to that pass's own verify command. Pass 49's baseline needs
# BYTE_MACHINE_HTTP_VERSION_GOLDEN_FILE (naming
# test/fixtures/generated-http-version.golden.sls) by the same mechanism, for
# the same reason.

cmake_minimum_required(VERSION 3.26)

# See "FIFTY-FOUR PASSES..." above. Declared here, rather than only in prose,
# so the count enforced at the bottom of this file is the same text a reader
# checks by eye at the top -- one number to keep in sync, not two that can
# quietly disagree. 25 passes / 60 mutations before the aot task; pass 26 adds
# two (C3, C3b) and passes 27 to 29 add one each, so 25 + 4 = 29 passes and
# 60 + 2 + 1 + 1 + 1 = 65 mutations before this task; W9 adds three mutations
# across two passes, not one -- pass 30 (the split character, the combining
# order) and pass 31 (the exit constant, which turned out witnessable after all
# once its manifest was allowed to be self-referential on purpose, superseding
# the declared survivor the plan first carried for it) -- so 29 + 2 = 31 passes
# and 65 + 3 = 68 mutations. Milestone 1 Phase 1's adapter os-table mapping
# mutation joins the existing self-test batch (pass 31, already declared)
# rather than opening a new pass, so passes stay at 31 and 68 + 1 = 69
# mutations.
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
# mutations. [Milestone 6 Slice ⓪: the shared text became ONE body in
# names.sls; the two verify-site pins moved there and the compile-site twin was
# retired -- see the note at the pass.]
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
# mutated. Pinned to the assertion's own words. (Slice ② correction: the phrase
# "observes a pause" is no longer unique -- the driver now carries BOTH an
# "agreed trial observes a pause" and an "interpreter alone observes a pause"
# label, so this pin is re-anchored, LABEL 3 below, on the full interpreter-only
# label plus its detail, not the bare substring.)
#
# The third new mutation targets the eof draw's own probability line, the
# same way: eof? is hard-wired to #f, so no dispatch node's eof-target is
# ever `done` and no generated machine ever reaches `finished`.
# finished-count's own assertion fails, at 0, exactly when this line is
# mutated. Pinned to the assertion's own words. (Slice ② correction: as with the
# pause phrase above, "idle-completion finish" now appears in both an "agreed
# trial" and an "interpreter alone" label, so this pin is re-anchored, LABEL 4
# below, on the full interpreter-only label plus its detail.)
#
# So passes stay at 38 and 156 + 3 = 159 mutations.
#
# Task 7 close-out review found the operation-matrix group's error/finished x
# resume! cells (§12.2:696-697) untested -- closed by two check-raises cases
# (runtime-tests.sps) and one mutation joining this same Pass 32 SPEC lane
# (see its own comment, just above "runtime: resume admits error/finished
# instead of refusing them"). Passes stay at 38 (an existing lane, not a new
# one); mutations become 159 + 1 = 160.
#
# Self-review of the same criterion then found finished x finish! (parser-
# finish!'s own sticky arm) also untested -- closed by one more check
# (runtime-tests.sps) and one more mutation joining this same lane (see
# "runtime: a re-finish on a finished parser does not return finished").
# Mutations become 160 + 1 = 161.
#
# The final whole-branch review (pre-merge) found two more Critical gaps in
# this same pass -- the feed-path and finish-path pause arms each collapse
# next/consumed/stream-offset to numerically-indistinguishable values on
# every existing zero-start fixture, the identical defect class the sticky
# error arm's `next` field closed above -- plus one Minor gap, finish-ready's
# own membership in parser-feed!'s prohibited clause. Three mutations join
# this same Pass 32 SPEC lane (see "runtime: the feed pause arm's consumed
# and stream offset collapse to next", "runtime: an EOF pause after
# consuming bytes reports zero instead of the persisted offset", and
# "runtime: feed admits finish-ready instead of refusing it"). Passes stay
# at 38; mutations become 161 + 3 = 164.
#
# A T8 re-review of that fix found the nonzero-start case still insufficient:
# it separates `next` from the other two fields, but not `consumed` from
# `stream-offset` -- those two are equal by construction on any single feed
# call from a fresh parser, so only a second feed call can separate them.
# One more mutation joins this same pass (see "runtime: the feed pause arm
# swaps consumed and stream offset"). Passes stay at 38; mutations become
# 164 + 1 = 165.
# Milestone 3 Slice ① Task 1 adds Pass 42 (matcher canonicalization and the
# tag-guarded accessor) with two mutations, and re-anchors two existing pins
# without adding either. Passes become 38 + 1 = 39; mutations 165 + 2 = 167.
# Slice ① Task 2 adds five constructor and canonicalization mutations to
# Pass 42. Passes stay at 39; mutations become 167 + 5 = 172.
# Slice ① Task 2's review fix wave 1 adds six more to the same pass: one per
# remaining tag-guarded class-matcher accessor (four -- byte-set-matcher-
# bytes, byte-range-matcher-low, byte-range-matcher-high, byte-complement-
# matcher-matcher), decision 0014's ordering half, and matcher-bytes' else
# arm. The predicted-count cap that stopped Task 2 from closing these is
# withdrawn; every count here is measured. Passes stay at 39; mutations
# become 172 + 6 = 178.
# Slice ① Task 3 adds three pair-enumeration mutations to Pass 33.
# Passes stay at 39; mutations become 178 + 3 = 181.
# Slice ① Task 4 adds two per-byte-expansion mutations to Pass 35.
# Passes stay at 39; mutations become 181 + 2 = 183.
# Slice ① Task 5 adds Pass 43 (class membership and recursive canonicalization)
# with two mutations. Passes become 39 + 1 = 40; mutations 183 + 2 = 185.
# Slice ① Task 6 adds Pass 44 (byte-class differential non-vacuity) with one
# mutation. Passes become 40 + 1 = 41; mutations 185 + 1 = 186.
# Slice ② Task 1 adds no new pass -- the sixth node kind and all seven
# verifier arms land in the two existing passes that already mutate ir.sls
# (Pass 42) and verify.sls (Pass 33). Pass 33 gains seven mutations, one per
# verifier arm; Pass 42 gains four (node?, node-name, the empty-sequence
# guard, and the bytes-accessor copy). Passes stay at 41; mutations become
# 186 + 7 + 4 = 197.
# Slice ② Task 1's review fix wave 1 adds three more to Pass 42:
# make-sequence-dispatch-node's remaining three constructor guards (empty
# cases, non-edge? mismatch, malformed eof-target), previously proven only by
# a green check-raises with no mutation behind it. No pin count changes in
# Pass 33 -- four pins were re-anchored in place (arm 1, re-classified from
# subsumed to under-anchored and fixed; arms 2, 4 and 7, whose FIND text
# moved onto the new node-eof-target helper), not added or removed. Passes
# stay at 41; mutations become 197 + 3 = 200.
# Slice ② Task 2 (decisions 0015, 0016) adds seven mutations to Pass 35 (the
# normalizer): the trie's merge and ascending-order arms, depth-first vs
# breadth-first id allocation, the declared/internal id split, a terminal
# child consuming no id, and the two internal guards (duplicate, ambiguous).
# One pre-existing Pass 35 pin ("unexpected-byte") was re-anchored to its full
# check line -- Task 2's own check-raises cases print their whole returned
# machine on failure, which carries the SAME resolved error code the bare
# substring matched, so the old pin now also matched two unrelated mutants;
# tightened to the (case, check) text it actually witnesses, not added or
# removed. Passes stay at 41; mutations become 200 + 7 = 207.
# Slice ② Task 2's review fix wave 1 adds two more to Pass 35: Important 2
# (an internal prefix state's own `id` field, previously unwitnessed) and
# Minor 3 (trie-insert's bs-null-branch trie-interior? guard, previously
# witnessed only by a green check-raises with no mutation behind it). Passes
# stay at 41; mutations become 207 + 2 = 209.
# Slice ② Task 3 (decision 0015 points 3-5) adds nine mutations to the
# existing Pass 34 (the interpreter): kind and dispatch's handling of a
# compound (name . path) current (2), seq-step's path-vs-position-index
# filter -- the corrected §0 D1 design defect (1), the mismatch edge and the
# completed-alternative-target decisions (2), eof-target-of's compound
# dereference (1), the interpreter's own copies of the two internal trie
# guards (2), and kind/dispatch's recognition of a bare not-yet-entered
# sequence node -- a value-audit finding distinct from the compound branches,
# confirmed separable by two different condition signatures (2). No pin
# collisions in Pass 34 (pre-existing or new) survived measurement; one
# pairwise collision found during the sweep (the position-index mutation and
# the mismatch-edge mutation share their "at offset 1" line) was resolved by
# a two-substring spanning pin, not by declaring it subsumed. Passes stay at
# 41; mutations become 209 + 9 = 218.
# Slice ② Task 4 adds Pass 45 (the sequence-node absolute interpreter lane,
# byte-machine.unit.sequence-node.chez.source) with three mutations: the
# mismatch edge's mode decision, in both directions -- hardcoding
# `(edge-mode mm)` to 'advance is caught only by the reexecute fixture
# (seqnode), hardcoding it to 'reexecute is caught only by the advance fixture
# (advseq), together proving the interpreter reads the declared mode rather
# than assuming one -- and the completed-alternative-target decision,
# re-witnessed through this lane's own single-alternative fixture (the same
# code Pass 34's Task 3 mutation already covers, but that pass's witness runs
# through interpret-tests.sps's multi-alternative trie fixtures, a different
# SPEC; per AGENTS.md a mutation's witness lives in its own SPEC lane). All
# three are comparison-caught, pins measured against a scratch stage (not the
# committed tree) and cross-checked pairwise so no two of the three share a
# FAIL line. Passes become 41 + 1 = 42; mutations 218 + 3 = 221.
# Slice ② Task 5 adds Pass 46 (the sequence-node differential's own
# non-vacuity, byte-machine.differential.sequence-node.chez.source) with one
# mutation: render-transition-arm's byte shift, the same decision Pass 44
# (byte-class) and Pass 39 (property) already carry, re-anchored under this
# lane's own SPEC because a mutation's witness lives in its own SPEC lane's
# program (AGENTS.md) -- both executors read the same source IR here, so the
# emitter is the only place a mutation can make them disagree at all.
# Comparison-caught. A measured sweep against the other passes that also
# mutate compile.sls found the FIRST tuple failure is not this mutation's own:
# Pass 36's "advance transition lowered as reexecute" mutation reaches the
# identical "(error 0 0 0 unexpected-byte)" line by a different mechanism when
# re-measured against this same program. Pinned instead to the all-256-bytes
# check, whose "got" value this sweep confirmed differs from every Pass 36
# variant checked; Pass 39's mod-256 mutation reproduces this pin exactly, which
# is expected -- for bytes 1-4 it is arithmetically the same shift, so it is
# the same decision re-witnessed under a different lane, not a collision. See
# the mutation's own comment for the full measurement. Passes become
# 42 + 1 = 43; mutations 221 + 1 = 222.
# Re-review, Task 5 fix wave 2 (an Important finding against fix wave 1) adds
# one more mutation to this same Pass 46: parser-feed!'s sticky-stopped arm's
# `next` field, hardcoded to a literal 0. Fix wave 1's own new "a trailing
# empty feed after the sequence completes stays stopped" case feeds from
# start 0, so it cannot separate that decision from a literal-0 hardcode --
# the same trap already closed for the sticky ERROR and PAUSE arms' `next`
# fields (both in Pass 32), never for the STOPPED arm's. Closed with a new
# nonzero-start companion case in differential-sequence-node-tests.sps
# (padded's [1,5) then [5,5), so start=5 and the persisted offset=4 are
# pairwise distinct from each other and from 0) plus this mutation, declared
# here rather than in Pass 32 because this lane's own new case -- not
# runtime-tests.sps -- is what reddens for it under Pass 46's verify command
# (AGENTS.md: a mutation's witness lives in its own SPEC lane's program). See
# the mutation's own comment for the full measurement, including why a
# sibling mutation swapping `start` for `(parser-offset parser)` on the same
# arm was NOT added: it was already caught incidentally by two pre-existing
# fixtures. Passes stay at 43; mutations become 222 + 1 = 223.
# Milestone 3 Slice ③ Task 1 (§16.2:894, the sequence-ambiguity verifier pass)
# adds six mutations to the existing Pass 33 (the verifier): the pass never
# being wired into verify-machine (1), the terminal-prefix test asking only one
# direction (1), the prefix relation collapsing to a first-byte test -- the
# OVER-rejection direction, which nothing else here reaches (1), and the three
# ways a pairwise walk can visit the wrong pairs (3), the sequence twins of
# pass-overlap's own three enumeration mutations. All six are
# comparison-caught, each pinned to a count no sibling produces. Pass 33 was
# re-swept whole in both directions at 40 mutations, and Pass 34 -- whose
# SPEC-lane program this task also edits -- at 12; see Pass 33's own audit
# block for the result. Passes stay at 43; mutations become 223 + 6 = 229.
# Milestone 3 Slice ③ Task 2 (§25:1533, extending pass-zero-progress's REPORT
# set to the sixth node kind) adds ONE mutation to Pass 33 -- the report guard
# losing its sequence disjunct -- and re-anchors three existing declarations
# the one-line source edit moved: two byte-identical FINDs onto the reflowed
# guard (one of them needing its REPLACE narrowed too, or it would have become
# a duplicate of the new mutation), and arm 3's pin onto the renamed
# count-not-witness case whose correct value moved 2 -> 3. Pass 33 was re-swept
# whole in both directions at 41 mutations; see Pass 33's own audit block.
# Passes stay at 43; mutations become 229 + 1 = 230.
# Milestone 3 Slice ③ Task 3 (the multi-alternative fixture and its absolute
# interpreter lane) opens Pass 47 with two mutations -- seq-step's
# live-alternative filter truncated to the first declared alternative and to
# the last -- declared under the new lane's own SPEC because a mutation is
# witnessed only by the tests that run in the lane its SPEC names, and measured
# to leave the single-alternative lane (sequence-interpret-tests.sps) passing
# unchanged. NOT because this is the only lane that drives a branching sequence
# node: interpret-tests.sps has driven AB/AC and AB/XY alternatives through the
# interpreter since Slice ② and catches both of these mutations. Pass 47
# carries the measured counts for all three programs: its header block for
# sequence-interpret-tests.sps and interpret-tests.sps, its two mutation bodies
# for http-version-interpret-tests.sps itself. The same task adds a group to
# normal-ir-tests.sps, so Pass 35 (whose SPEC lane runs that program) was
# re-swept whole in both directions at 22 mutations; see Pass 35's own audit
# block. Passes become 43 + 1 = 44; mutations become 230 + 2 = 232.
# Milestone 3 Slice ③ Task 4 (the interpreter≡generated differential over the
# same two alternatives) opens Pass 48 with two mutations -- the emitter's
# per-state transition-arm list truncated to its FIRST arm and to its LAST --
# declared under the new differential lane's own SPEC. They are the generated-
# side twin of Pass 47's interpreter-side pair: the branch state is the only
# state in this fixture with more than one arm, so truncating renders one
# alternative unreachable in the emitted library while the interpreter still
# accepts it, and the two executors disagree. Measured to leave the
# SINGLE-alternative differential (differential-sequence-node-tests.sps) and
# the same fixture's interpreter-only lane (http-version-interpret-tests.sps)
# passing unchanged; see Pass 48's own header for the numbers and for the two
# lanes that do redden. Passes become 44 + 1 = 45; mutations become
# 232 + 2 = 234.
# Milestone 3 Slice ③ Task 5 (the sequence determinism golden) opens Pass 49
# with one mutation -- trie-put's insert-before-if-less arm flipped, so a trie
# node's children come out DESCENDING by byte -- declared under the new
# determinism lane's own SPEC. It is the same one-line edit Pass 35 already
# carries as "normal-ir: trie children are not kept ascending by byte", and it
# is re-anchored here for the reason Pass 46 re-anchors Pass 44's byte shift: a
# mutation is witnessed only by the tests that run in the lane its SPEC names,
# and no golden in the tree contained a BRANCH before this task. Measured to
# leave the other two determinism programs passing unchanged; see Pass 49's own
# header for those numbers and for the lanes that do redden.
# Passes become 45 + 1 = 46; mutations become 234 + 1 = 235.
#
# Whole-branch review fix wave (Important 3): Pass 33 gains one mutation --
# "verify: the sequence mismatch edge's MODE is not tested (arm 3,
# reexec-targets)" -- for the one decision in reexec-targets' sequence arm that
# had no mutation, the `eq? ... 'reexecute` test itself. No pass is added, so
# passes stay at 46 and mutations become 235 + 1 = 236.
#
# *** The entries below close a GAP in this narrative, not a new bump. The first
# version of this block was written from a guess and got four things wrong; it is
# replaced, not appended to, and the corrections are named so the method is
# visible. Every number here is measured, by
#   git cat-file -p <rev>:test/support/cmake/SchemeMutationSuite.cmake | grep EXPECTED_
# and by a per-SPEC census of the mutation blocks at each end. ***
#
# The running total above stops at 46/236, which is correct at `c3ceec2`. That is
# NOT the merge base -- three commits sit between it and `main` -- and the
# constants at the merge base stand at 48/**249**, not the 48/255 the first
# version claimed. 255 is reached by this branch's own task 3, which the block
# then went on to record separately: it was double-counted.
#
# Slice ①a (`c3ceec2` -> `d89899b`, its merge): 46/236 -> 48/**249**. Two passes
# join -- the position-kind differential and the member-3 drift check, both new
# lanes -- and THIRTEEN mutations: +6 position-kind, +3 normal-ir (the encoding
# format's three reserved slots), +2 verify (the reason repertoire), +1 runtime,
# +1 member-3 drift. The first version said fourteen and included a determinism
# mutation; that one is not ①a's, see the next paragraph.
#
# `51fd5f3` (this branch's FIRST commit, and not ①b's work): 249 -> 250. It
# resolves decision 0022's item 7 open question and adds one determinism mutation,
# "compile: the errs table carries declarations the graph never reaches". A
# per-SPEC census places it exactly: `byte-machine.determinism.one-byte` goes
# 1 -> 2 between the merge base and here.
#
# Slice ①b tasks 1 to 3: 250 -> 255. Task 1 adds three to the ir pass for the
# uint field descriptor and the machine guard that makes it load-bearing; task 2
# adds none, the facade being two export lists with no decision of its own; task 3
# adds two, BOTH to Pass 33. The first version put one of them "in the ir pass":
# that mutation's FILE is `ir.sls` but its SPEC is
# `byte-machine.verify.rejections.chez.source`, and it is the SPEC that decides
# which pass witnesses a mutation. FILE and pass are not the same axis.
#
# Slice ①b task 4: 255 -> 260. FIVE join Pass 33 for pass-fields, the declaration
# half of §16.3:924 item 6 -- one permissive per check, the restrictive direction
# on the portable-name check, the pass-fields join, and the restrictive direction
# on the duplicate check. The last two were first declined as SUBSUMED and the
# whole-branch review found that declination unsound; the reasoning and the
# retraction are at the mutations' own site. No pass is added.
#
# Slice ①b task 5: 260 -> 265. The normal-ir pass gains five, one per remaining
# decision in the field record -- name, width, initial, record order, and the slot
# number the table carries. A sixth, the field count, is not new: it is ①a's
# reserved-count pin RE-ANCHORED, killed by construction when the literal zero
# became the real count.
#
# Slice ①b tasks 6 and 7: 265 -> 273, and passes 48 -> 49. One joins the compile
# pass (member 0 rendered empty regardless of the declarations); a NEW pass --
# headed **Pass 50**, because header numbers run ahead of the run count and 49 was
# taken -- carries seven for parser-field-ref, the only lane in which the field
# declarations are observable at all. Six are pinned; one carries an
# EXPECT_SURVIVES with its measurement and its reopening condition, taking the
# suite's declared survivors from nine to TEN. Three further mutations were
# measured and deliberately not written, each because its record set is identical
# -- not a subset, the same set -- to one that is.
#
# Slice ①b's Critical fix wave: 271 -> 273. Two join Pass 33, both recovered from
# task 4's unsound subsumption call.
#
# *** WHOLE-PASS SWEEP of the differential.field pass, Slice ② task 10: 20 pins,
# 380 ordered pairs, 14 collisions -- EIGHT by-construction nestings and SIX that
# are not nested in either direction. The six are recorded here rather than
# closed, with the attempt. ***
#
# What they are: this is a DIFFERENTIAL lane, and most of its checks compare the
# interpreter to the generated library. That comparison is symmetric, so breaking
# either implementation of the same decision produces the same disagreement, and
# a mutation of the interpreter's bound check and one of the emitter's are told
# apart only by which side of a per-lane check moves.
#
# The attempt, measured: the check labels originally named only the first byte of
# each schedule, so `(0)` and `(0 0)` produced byte-identical FAIL records.
# Labelling every check with the WHOLE schedule took collisions from 18 to 14 and
# gave two of the eight pins a lane-unique record. An exhaustive search for a
# unique ORDERED PAIR of records then found none for the remaining six.
#
# What is NOT wrong here: every one of the six is CAUGHT, each by a record its
# own decision produces. What they lack is unique ATTRIBUTION -- break one and
# more than one pin reports. Closing it needs per-lane assertions against
# EXPECTED values everywhere the lane currently asserts only that the two lanes
# agree, which is a fixture redesign rather than a re-anchoring.
#
# *** OWED BY: the next slice that adds a mutation to this pass, which on the
# current plan is Slice ③ (integer accumulate). *** Named rather than left as
# "owed", because a deferral with no receiver is how this project once shipped an
# unwitnessed function. ③ adds per-kind arms to both executors and so hits
# exactly this: its new pins collide the same way unless the lane's cross-lane
# checks are split into per-lane assertions first. The coverage group ②'s review
# added is the shape to copy -- it asserts EXPECTED values per lane, and its two
# pins do not collide.
#
# Milestone 5 Slice ①b's final review: ONE more, on the ABI-4 metadata length
# guard, which shipped with neither a test nor a pin. Mutations 380 + 1 = 381.
#
# Milestone 5 Slice ② tasks 1-2, the TENTH node kind: TEN more, 381 + 10 = 391,
# in two existing passes and no new one. SIX in the `unit.ir` pass -- `node?`
# and `node-name`, the two census sites every kind must join; the swap pair over
# the mandatory continue target and pause continuation; §9.1:318's two-element
# branch entries; and the branch list's copy, witnessed by identity. FOUR in the
# kind x position matrix pass, one per verifier decision the kind adds: its three
# edges joining `zero-width-edges`, its three OUTCOME role labels, the
# zero-progress REPORT set, and `parked-eof-start` -- the first time in this
# project that "a state an execution can be parked on" and "the name the EOF walk
# starts at" have been different questions.
#
# Milestone 5 Slice ② tasks 3+5, the callback node EXECUTING: FIFTEEN more,
# 391 + 15 = 406, and one new pass (52 -> 53). THREE in the normal-ir pass, for
# decision 0019 item 2 over the callback state's encoding -- the wire tag,
# pinned on a golden because a tag change moves every callback fingerprint
# together, and the two parts whose loss the separability group can name. FIVE
# in the verify pass, one per arm of §16.2:901's node half including the
# resolution short circuit, whose absence makes the verifier RAISE on a machine
# it is meant to reject with one finding. SEVEN in the new pass, whose SPEC is
# the differential lane because the emitted callback arm exists nowhere else --
# and two of those seven edit code BOTH lanes share, so the cross-lane
# comparison cannot see them and the program's by-value assertions are what
# catch them.
#
# Milestone 5 Slice ② task 4, `parser-state-name` and the ABI bump 4 -> 5: FIVE
# more, 406 + 5 = 411, in two existing passes. THREE in the sequence-node
# differential, whose lowered prefix states are the one shape where the two
# lanes hold structurally different things at a parked position -- the compound
# and an integer id -- which is exactly why Slice ①b could not ship the
# accessor. TWO in the callback pass, for §13:819-820's committed state, and
# each is false in ONE lane only: the interpreted arm is already parked where
# the callback should see it, and the emitted `exec` owns its own locals until
# it returns.
#
# *** One mutation was RETIRED here rather than re-anchored, and the reason
# generalises. *** "an ABI 4 payload with no member 1 is accepted" went UNCAUGHT
# the moment member 2's guard landed: the payload length guards were a CHAIN,
# one minimum per ABI version, and a later minimum subsumes every earlier one --
# so the ①b guard's removal changed nothing any input could observe. The three
# guards collapsed into one reading `current-abi-members`, and the mutation was
# re-anchored onto it under a version-free LABEL. Only the LAST guard in a
# chain of widening minimums discriminates anything.
#
# Milestone 5 Slice ② tasks 6 and 7, `busy` and `poisoned`: FIVE more,
# 411 + 5 = 416, all in the callback pass, because those are the first two
# lifecycle states anything in the tree can REACH -- `busy` needs something
# running inside the parser and `poisoned` needs a callback to escape from one.
#
# *** A SURVIVOR WAS CLOSED HERE WITHOUT ANYONE TRYING TO. *** "runtime:
# parser-feed!'s finished sticky arm is deleted outright" had a written,
# twice-re-measured reason that rested entirely on `parser-feed!`'s `else`
# meaning "ready": the deleted arm fell through and the op path re-derived the
# identical tuple. Slice ② had to make that else LOUD -- otherwise adding `busy`
# and `poisoned` to the lifecycle vocabulary would have made a poisoned parser
# silently re-execute -- and the mutant now raises. The suite said so itself
# ("The recorded limitation is stale"). A survivor whose argument depends on a
# permissive fall-through stops being a survivor when that fall-through closes;
# a written reason is only as durable as the control-flow shape it names.
#
# Four other pins moved for the same reason and are re-anchored at their sites:
# three that used to read "expected a raise, but the thunk returned" now read
# "raised object did not satisfy the predicate", because the mutants raise the
# wrong condition instead of executing.
#
# Milestone 5 Slice ② task 8, the callback-order oracle: TWO more,
# 416 + 2 = 418, one per lane, for §11.4:652's "callback invocations ... do not
# consume input". Their records are mirror images -- each mutant advances its
# own lane and the other stands still -- which is what makes two mutations
# necessary rather than one: a lane that agreed with a mutated sibling would be
# the defect neither alone can show.
#
# Milestone 5 Slice ③ task 1, the ELEVENTH and TWELFTH node kinds: NINE more,
# 418 + 9 = 427, in two existing passes. SIX in `unit.ir` -- `node?` per kind
# (separable, because the case names the kind that failed), `node-name` for the
# pair (NOT separable: its else raises, so dropping either arm stops the
# table-driven case at the same point, and the pair is one decision anyway), the
# mandatory `next` per kind, and the shared-tag mutation that is the only thing
# a predicate-driven table cannot see. THREE in the kind x position matrix, one
# per span arm of `zero-width-edges` plus the zero-progress REPORT set.
#
# Milestone 5 Slice ③ task 2, PASS 7 (the span-state lattice): ELEVEN more,
# 427 + 11 = 438. One per rejection §16.2:899 names, one for :900's callback
# half, one for the pass never running, and THREE structural -- `top` not
# flowing onward, the EOF half of the edge relation, and the error-versus-
# successful terminal split that consumes decision 0023 item 5.
#
# *** ONE OF THEM SHIPPED UNCAUGHT AND WAS RE-TARGETED RATHER THAN WEAKENED. ***
# "pass 7 runs over every node, not the occupiable ones" removed a `(memq to
# live)` filter, and the filter turned out to be VACUOUS: `live` is the closure
# of the pass's own edge relation, so every edge's target is in it by
# construction. The filter was deleted rather than documented, and the decision
# it was meant to witness -- 0029 item 3's relation, which is 0027's -- is now
# witnessed where the two relations actually differ: an eof half that keeps
# taking byte edges, against the machine 0027's Context derives.
#
# Milestone 5 Slice ③ task 3, §16.2:898's gate: ONE more, 438 + 1 = 439. It is a
# RELAXATION, so its fixture asserts both directions and the second half is the
# one that matters -- `unreachable-node` does NOT catch the machine the gate now
# accepts, which is the ground design §3.2 item 4 gave for calling the gate
# benign and which decision 0027 records as false. Two shipped fixtures moved
# with it, and one of them now asserts the OPPOSITE of what it did: an EOF-only
# pause cycle is `eof-zero-progress-cycle` and NOT `zero-progress-cycle`, which
# is the non-overlap 0027 item 3 gates on `byte-reached` alone to get.
#
# Milestone 5 Slice ③ task 4, lowering and encoding: FOUR more, 439 + 4 = 443.
# The wire tag (pinned on a golden, because a tag change moves every span
# fingerprint together), the slot RESOLUTION (anchored there rather than on one
# arm's write, so it stays distinguishable from the tag), the fused-state
# rejection decision 0026 item 2 makes -- caught by a raise that is the
# decision's own consequence, since a span end with no allocated continuation
# cannot answer -- and the debug map's totality over the SECOND internal family,
# which Slice ② turned from a missing debug string into an index error in the
# generated lane.
#
# Milestone 5 Slice ③ task 5, execution in both lanes: TWELVE more in a NEW pass
# (54), 443 + 12 = 455. The differential lane over the span kinds, and the first
# pass in the tree whose pins are anchored on something no parser result carries
# -- a span FRAGMENT. Two lanes can agree on every §22.4 tuple while handing the
# application different bytes, so SIX of the twelve edit shared code and are
# pinned on recorded values rather than on agreement, and THREE of the emitter's
# would otherwise resolve to the same "the lanes agree" line. The fixture asserts
# the GENERATED lane's trace and active span as values for exactly that reason.
#
# *** TWO SHIPPED LINES WERE DELETED HERE, both measured rather than argued. ***
# The mark advance inside the fragment step (§14:841) SURVIVED its mutation:
# every path out of a delivery either closes the span or crosses a feed boundary,
# where §14:833's re-anchor overwrites the mark, and no public accessor reads a
# mark -- a nesting by construction, not a coverage gap. The finish path's
# re-anchor to 0 was inert for a different reason: an EOF-side fragment is
# `[mark,0)` and `from >= to` holds for every mark, so §14:834 suppresses it
# whatever the mark says. Both rules now live in one place each.
#   [2026-09-13, Milestone 10, decision 0042: the finish re-anchor to 0 was
#   RE-ADDED and is no longer inert -- once an empty span END delivers, that
#   re-anchor is what makes a carried empty span reach `from == to` and be
#   announced uniformly rather than by the last feed's slice start. It now has its
#   own pin ("parser-finish! does not re-anchor the span mark to 0"). The M5
#   record above is left as it was measured then.]
#
# FOUR shipped pins moved. Two because the F1 split re-indented the classifier
# and relocated the `busy` write, and TWO because a span arm became a second site
# for a line the callback arm owned -- both `goto` arms are zero-width, which is
# the point, so the FIND now carries the invocation above it.
#
# Milestone 5 Slice ③ task 6, the oracle: FOUR more, 455 + 4 = 459, in pass 54
# rather than a new one. They break one arm of `span-node-diagnostics` each and
# every one turns a REJECTED row of the topology table green rather than a green
# row red -- a direction the verify-lane passes cannot reach, since those drive
# machines that verify CLEAN. They run against the SAME lane as task 5's, and a
# pass count calling that two witnesses would be the banner claiming a witness
# the tree does not have.
#
# Milestone 5 Slice ③ task 8, the census reconciliation's own findings: THREE
# more, 459 + 3 = 462, in the verify-rejections pass. Both holes were Slice ③'s
# -- it made a span end a PARKED state and a span node a DECLARATION-REFERENCING
# one, and shipped neither check -- and both were REACHABLE: one machine verified
# clean and then answered `stopped` from `parser-finish!`, the other verified
# clean and then raised out of `normalize-machine`, which §9.2:368 forbids.
#
# *** A THIRD LINE WAS WRITTEN AND DELETED, the third this slice. *** An arm in
# `parked-eof-start` answering `(span-end-node-next n)` SURVIVED its mutation: a
# span end is pure flow-through, so `classify` joins over its `next` and starting
# the walk at the node gives the same verdict as starting at the successor. The
# whole of that fix is the parked-set MEMBERSHIP.
#
# One shipped pin was RE-MEASURED rather than re-anchored, and the difference
# matters: "a span-end node's successor is not an edge" used to lose two findings
# from an axis-C cell, and now RAISES out of `eof-terminal` -- the span end is a
# walk start with no out-edge, so the zero-width join is empty. Its span-start
# sibling raises too, but only on axis A, so the axis-C raise is what still
# separates them. The span fixture's golden fingerprint moved for the same
# reason: its tail had to route through a dispatch, because its span end
# continued straight into a stop.
#
# Milestone 5 Slice ③ task 8, §12.7:770's row: FOUR more, 462 + 4 = 466, in the
# position-kind pass. THE TREE DID NOT IMPLEMENT THAT ROW. "Zero-width machine
# action or callback failure | `boundary` at the current stream offset" -- every
# site building a callback-domain error passed the loop's `pk`, and Slice ②'s own
# comment said the carried-through `pk` "is the rule the carried-through `pk`
# already implements", which is true only over an ADVANCE edge. Over a REEXECUTE
# edge `pk` is `byte`, and BOTH LANES REPORTED IT -- so the differential could
# not see it, a lane-to-lane projection being satisfied by two lanes agreeing on
# a wrong value. Found by adding the row §12.7:770 had never had.
#
# Four sites, four mutations: one named constant serving the runtime's six arms,
# and three rendered literals, one per emitted arm that calls out. Two of the
# lane's fixtures had to change shape for the defect to be reachable at all --
# the callback row's node is now reached by a REEXECUTE edge, because over an
# advance the literal and the variable agree and the row proves nothing.
#
# One shipped pin was re-anchored: the edge-role census case is "every other
# kind" now, the table having grown a callback row and two span rows.
#
# Milestone 5 Slice ④ and the close-out audit took the count from 466 to 476 at
# their pins' own sites, with no entry here: Slice ④'s nine (466 + 9 = 475) are
# the verify-rejections pass's four label pins, three in the retention pass and
# two in the span-oracle pass; the audit's one makes 476.
#
# Milestone 6 Slice ⓪ tasks 2 and 3, §16.2:886's label clause made TOTAL: SEVEN
# more, 476 + 7 = 483. Five in the verify-rejections pass, one per conjunct the
# fold added -- the machine's label, a node's own label, a node's case labels,
# an error declaration's label, a field's label -- each pinned on the carrier
# row it stops rejecting, with a wrong-SHAPE label because every one of them is
# otherwise nested inside the shipped permissive-`reason-char?` mutant. Two for
# `node-source-label`, ir.sls's second per-kind census: an arm answering `#f`
# (the ir pass, by comparison) and an arm DELETED (the census pass, by the
# derived S2b row's count). Two shipped pins were re-anchored, the machine-name
# and node-name grammar pins, whose `if` tests grew a conjunct; their REPLACEs
# now drop the name check alone. No pass is added.
#
# Milestone 7 Slice ⓪, decision 0031 (reachability is the occupiable relation):
# FIVE re-anchored, ONE re-shaped, THREE re-pinned, THREE added and THREE
# shipped INCUMBENTS re-anchored, 522 + 3 = 525, and no pass is added (58 stays
# 58). Nothing is retired: the first draft retired one and the whole-branch
# review measured its reason false.
#
# The fifth re-anchor is "a sequence node's eof-target does not feed
# reachability", whose FIND was `all-out-targets`' definition. That procedure is
# deleted, but its decision is RELOCATED and not subsumed: `eof-step` is what
# reads `node-eof-target` for the walk now, and the mutation moves onto it. The
# tombstone this slice first wrote in its place claimed the new group's
# sequence-dispatch pair witnessed the decision; measured, that pair answers the
# same with or without `node-eof-target`'s sequence arm, because `T`'s own
# eof-target there is already byte-reached. The full reason is at the site.
#
# The four re-anchored ones are the §16.2:909 membership's -- the entry
# disjunct, the byte-reachability gate, the derived EOF-route test and the span
# end -- which move onto the ONE `parked?` the slice unifies. Each mutant now
# reaches three consumers instead of one, so each was re-measured; all four are
# still caught by their shipped pins, with the failing-case counts re-confirmed.
#
# The re-shaped one is "pass 7's EOF half keeps taking byte edges", whose
# REPLACE named `all-out-targets`. An unbound identifier is a raise, not a
# comparison, so the retired walk is reproduced inline.
#
# THREE pins moved without their FIND moving, which a census by FIND location
# cannot see: the narrowing changed what those mutants PRODUCE. "a zero-width
# node's targets are not out-targets" (its fixture's zero-width node is the
# ENTRY, hence parked, so the EOF walk rescues it -- a second machine was added
# where the node is byte-reached instead); "the :908 check is not gated on
# byte-reachability" (its pin read a case label this slice renames); and "a
# counted consume's next is not an out-edge" (its pin read an entry-stop record
# the narrowing emptied). Each is re-pinned on a whole measured record.
#
# The three added: `occupiable` mutated back to the retired walk, and the two
# `parked?` disjuncts that had NO pin before the unification. The pause disjunct
# is pinned in this pass on a CONJUNCTION of two records (neither is unique
# alone; the intersection of their containing sets is empty). The CALLBACK
# disjunct is declared in the kind-position-census pass instead, because
# `verify-tests.sps` passes with that disjunct gone -- measured on both the
# pre-0031 tree and the unified one -- and a mutation is witnessed only by its
# own SPEC lane's program.
#
# THREE SHIPPED INCUMBENTS were re-anchored by the other direction of the pin
# sweep -- an existing pin that a CHANGED mutant newly satisfies. All three were
# bare prefixes: two case- or check-label prefixes ("...AT A PAUSE NODE: at
# least one, at a pause" and "a `default-error` sibling does not mask the stop")
# and one a fragment of a `got` VALUE in the census ("callback-pause-continuation
# advance want"). Each is re-anchored on whole measured records at its own site;
# the sweep report records the collision counts.
#
# *** ONE OF THE THREE IS SUBSUMED EXCEPT ON ONE FIXTURE, and the fixture is the
# finding. *** "pass 4 walks the retired relation" removes a SUBSET of what
# "reachability never reports an unreachable node" removes, on every machine --
# whole-set containment, so every family-only check they share is satisfied by
# both. The separating case is `an orphan beside the family`, which carries a
# node dead under both relations beside one dead only under the narrowing: the
# walk mutant leaves the orphan reported and the emission mutant leaves nothing.
# Count, don't witness.
#
# Milestone 6 Slice ② task 3, the counted-span differential: TWO more in ONE new
# pass, 520 + 2 = 522 and 57 + 1 = 58. The slice adds no mechanism, so its lane
# witnesses one decision no other lane does -- decision 0030 item 2's placement
# of the completion event -- and the two count-completion-order mutants Slice ①
# declared elsewhere are declared again here, pinned per lane on the per-feed
# placement record. The retention lane's body-shaped arm adds no pin: the shipped
# stored-bytevector MUTANT reddens it (measured by the sweep), and the arm's labels
# share no run of words with the shipped pin's regex, so that pin still resolves to
# exactly one (case, check) pair -- the review caught a first draft whose label
# "counted: gone in both lanes" made it resolve to two.
#
# Milestone 6 Slice ① task 3, the differential, the fifth golden and the two
# structural witnesses: NINE more in TWO new passes plus one, 511 + 9 = 520, and
# 55 + 2 = 57 passes. Seven in the counted differential pass (the reached walk
# ignoring the kind, the emitted arm's min, subtraction, completion order and
# exhaustion order -- each on the GENERATED lane's expected value -- the
# runtime re-asking the op after a partial commit, caught only by the
# count-step counter, and the finish arm asking the EOF route first, caught by
# the entry-zero machine); one in unit.compile (the per-byte self-loop render,
# which every behavioural lane passes -- the datum walk catches it here, and the
# counted golden would too, being bytes); one in the counted determinism pass (a quote
# mark for `(quote …)`, caught only by the golden).
#
# Milestone 6 Slice ① task 2, the kind lowered, encoded and executed in both
# lanes: FOURTEEN more, 497 + 14 = 511. Six in the normal-ir pass (the tag, the
# field name, the successor and the EOF routing each dropped from the encoding,
# a second successor lowered, the EOF edge read as absent), four in the
# interpret pass driving `count-step` directly (exhaustion before the zero
# count, `(- end pos)` for the min, no subtraction, the count-completion-wins
# order), three in the position-kind pass for the runtime's arm (the offset
# advance, `current` parked on the EOF route, exhaustion asked before the op --
# the emitted arm's twin of that last one is pinned in the counted differential
# pass, because this pass's labels carry no lane prefix), and one for the local
# `n` in reserved-member-3. Three shipped pins re-anchored: the two member-3
# pins and the reached-declaration walk's kind list.
#
# Milestone 6 Slice ① task 1, the thirteenth kind and its two answers in the
# verifier: FOURTEEN more, 483 + 14 = 497. Five in the ir pass (the mandatory
# `next`, the eof-target check, `node?`'s disjunct, `node-name`'s arm,
# `node-source-label`'s arm) and nine in the verify-rejections pass, one per
# verifier decision 0030 names: `node-out-edges`' arm, `node-eof-target`'s arm,
# the §16.2:903 field check, the zero-progress WALK arm and the REPORT-set
# predicate (separated by the value-terminated loop's `got`), `eof-successors`'
# arm (a raise), both halves of `classify`'s join, and `parked-eof-start`'s arm.
# Fifteen shipped pins were re-anchored in the same commit -- six on `node?`'s
# tail, seven on the REPORT set's predicate list, `parked-eof-start`'s, and the
# two census ratchets whose expectations read thirteen now. Two of the
# REPORT-set REPLACEs were narrowed to the one predicate their LABELs name.
#
# Milestone 6 Slice ⓪ task 4, one name grammar: ONE added and ONE retired,
# 483 + 1 - 1 = 483. Added: the runtime's callback-code grammar check (Pass 32),
# the §9.3:423 deferral Milestone 5's completeness check named a receiver for.
# Retired: "compile: any interior binding character is accepted", whose text
# (compile.sls's copy of `name-char?`) no longer exists -- its observation is
# the re-homed interior-character pin's, one file over. Two verify-site grammar
# pins RE-HOMED from verify.sls to names.sls and one unit.compile pin re-anchored
# from the inline loop onto the `portable-name?` call. No pass is added.
#
# Milestone 5 Slice ①b: TWO. `pass-declarations` never run -- eight census
# fixtures then find nothing, caught by a comparison naming a missing code. And
# the span section reusing the callback section's tag, which pins the section
# discriminator decision 0025's ①b-planning note added, caught by the fixture
# naming both declarations `x` so that only the tag separates them.
# Mutations 378 + 2 = 380.
#
# Milestone 5 Slice ①a's final review: ONE more, on a zero-width edge role's
# label. The position drift row's own comment claimed it was BLIND under this
# suite; the review measured that backwards -- the derived set meets a mapping
# DECLARED in the test, so a mutated verifier disagrees with it. Mutations
# 377 + 1 = 378.
#
# Milestone 5 Slice ①a: ONE, on the emitted `exec` parameter list. The slice's
# own planning measured that no FIND anywhere anchored on that line, so widening
# the signature was invisible here; the pin drops the last reserved parameter and
# is caught by compile-tests.sps's signature assertion, the only witness to that
# line in the tree. Mutations 376 + 1 = 377. Passes unchanged at 52: the compile
# unit pass already existed.
#
# Whole-branch review: the verify pass gains TWO -- `unresolved`'s tier, which
# was load-bearing and unwitnessed, and the zero-width kinds' edge roles, nine
# of thirteen of which had no witness. Mutations 374 + 2 = 376.
#
# Milestone 5 Slice ⓪ task 5: the verdict lattice joins pass 52. Mutations
# 373 + 1 = 374.
#
# Milestone 5 Slice ⓪ task 2: a NEW pass (52) for the kind x position matrix,
# carrying the closed-set ratchet. Passes 51 + 1 = 52; mutations 372 + 1 = 373.
#
# Milestone 5 Slice ⓪b task 6: the EOF verdict tiers. Mutations 370 + 2 = 372.
#
# Milestone 5 Slice ⓪b task 5: §16.4:940's edge label. Mutations 368 + 2 = 370.
#
# Milestone 5 Slice ⓪b task 4: §16.2:909 walks the PARKED set. FIVE removed
# (per-kind sites that no longer exist; residue at the site), FOUR added --
# one of them Slice ⓪ task 1's pin re-anchored. Mutations 369 - 5 + 4 = 368.
#
# Milestone 5 Slice ⓪b task 3: the zero-hop entry clause. Mutations 368 + 1 = 369.
#
# Milestone 5 Slice ⓪b task 2: §16.2:908's three hand-written sites collapse
# into one derived block. SEVEN mutations removed (their decisions no longer
# exist separately; residue recorded at the site), THREE added. Mutations
# become 372 - 7 + 3 = 368.
#
# Milestone 5 Slice ⓪ task 6: a NEW pass (51) for the diagnostic census -- the
# operand-table drift row, the per-code site counts, and the ratchet itself.
# Passes become 50 + 1 = 51; mutations 369 + 3 = 372.
#
# Milestone 5 Slice ⓪ task 1: the verify pass gains ONE for the pause-continuation
# EOF cycle site, which was live code with no witness. Mutations become
# 368 + 1 = 369.
#
# Whole-branch review: the differential.field pass gains SEVEN for the four
# accumulate operands no executing fixture reached. Mutations become
# 361 + 7 = 368.
#
# Whole-branch review: the verify pass gains THREE for the kind filters Slice
# ③ did not widen -- two Criticals and one Important. Mutations become
# 358 + 3 = 361.
#
# Slice ③ task 10: the member3-drift pass gains ONE -- the accumulate arm's
# digit local, which the list reserved and nothing exercised. Mutations become
# 357 + 1 = 358.
#
# Slice ③ task 9: a NEW pass (50) for the accumulate determinism lane and its
# fourth golden, carrying ONE mutation no behavioural lane can catch.
# Passes become 49 + 1 = 50; mutations 356 + 1 = 357.
#
# Slice ③ task 8: the property pass gains TWO for the accumulate draw, and the
# differential.field pass ONE for the emitter defect that draw uncovered.
# Mutations become 353 + 3 = 356.
#
# Slice ③ task 7: the position-kind pass gains ONE for that lane's fourth row --
# the offset the field lane cannot assert. Passes stay at 49; it joins the
# existing position-kind pass because that is the pass whose verify command runs
# position-kind-tests.sps. Mutations become 352 + 1 = 353.
#
# Slice ③ task 6: the differential.field pass gains TWO for the digit-range
# bounds, one per lane. Mutations become 350 + 2 = 352.
#
# Slice ③ task 5: the differential.field pass gains ONE for the accumulate
# arm's end-of-slice guard. The rest of the task is tests for INHERITED
# behaviour -- see that mutation's own note. Mutations become 349 + 1 = 350.
#
# Slice ③ task 4: the differential.field pass gains FIVE pinned and TWO
# EXPECT_SURVIVES for the checked multiply-add. The survivors are the pre-check
# form itself, in both lanes, and their reason is §15:856: the form is mandated
# for a host that WRAPS, and Chez does not, so no fixture on this host can
# distinguish it from a compute-then-check. Declared survivors go from ten to
# TWELVE. Mutations become 342 + 7 = 349.
#
# Slice ③ task 3: the normal-ir pass gains SIX for integer accumulate's
# lowering and encoding at tag 7 -- the tag, the base, the nondigit mode, the
# overflow target, the EOF accessor, and the state's layout length. The dispatch
# and accumulate arms' identical EOF routing was FACTORED into `put-eof-routing`
# (SITES trap, sixth time) and the shipped default-eof pin re-anchored onto it.
# Mutations become 336 + 6 = 342.
#
# Slice ③ task 2: Pass 33 gains SIX for the input-reading kind's census --
# both zero-progress disjuncts separately, the digit edge's exclusion, the
# REPORT set, out-targets, and the field reference. FOUR shipped report-guard
# pins were re-anchored for the sixth disjunct. Mutations become 330 + 6 = 336.
#
# Slice ③ task 1: the ir pass gains SEVEN for the integer-accumulate node --
# the base set, the nondigit edge's shape, the mandatory overflow target, the
# eof-target's shape, both census sites, and the constructor/verifier boundary in
# the restrictive direction. Mutations become 323 + 7 = 330.
#
# Slice ②'s whole-branch review, second finding: the normal-ir pass gains ONE for
# the sequence-dispatch state's layout length -- see that mutation's own note.
# There are EIGHT `(vector ns-tag ...)` literals in this normalizer, not the six
# task 5 recorded, and the eighth is the one it missed. Mutations become
# 322 + 1 = 323.
#
# Slice ②'s whole-branch review, first finding: the differential.field pass gains
# TWO for the operation/predicate coverage group -- see that group's own header.
# Passes stay at 49 and mutations become 320 + 2 = 322.
#
# Slice ② task 9: the differential.field pass gains THREE for the operation
# matrix -- both lanes' lower bound, and the decrement itself. Four widths, four
# schedules each, driven through BOTH executors with sentinels over the widths
# and over the schedules. Passes stay at 49 and mutations become 317 + 3 = 320.
#
# Slice ② task 8: the differential.field pass gains SIX for the EMITTER's field
# arms -- the bound check and its boundary, the no-write-on-failure rule, one
# operation, the zero-width jump, and the branch predicate. `v` and `r` join
# reserved-member-3, and its drift guard's fixture gains field nodes, which it
# needed: the pause machine it rendered declares none, so both locals would have
# been reservations nothing exercises. Passes stay at 49 and mutations become
# 311 + 6 = 317.
#
# Slice ② tasks 6 and 7: the field-access (now differential.field) pass gains
# FIVE -- three for the interpreter's checked arithmetic and two for the runtime's
# zero-width arms -- and Slice ①b's `parser-reset!` EXPECT_SURVIVES is CLOSED and
# re-declared as a pin, which is the reopening condition it wrote for itself.
# Declared survivors go back to TEN. Passes stay at 49 and mutations become
# 306 + 5 = 311.
#
# Slice ② task 5: the normal-ir pass gains SIX for the two zero-width kinds'
# encoding -- the tag, the selector, the operand count, the operand kind tag, the
# error-target presence tag, and the branch's false target. Each on its own
# measured golden. The state vector was WIDENED in the same commit (design §0
# D3) and no existing fingerprint moved, because the new slots are #f for every
# shipped kind and none of them is written. Passes stay at 49 and mutations
# become 300 + 6 = 306.
#
# Slice ② task 4: Pass 33 gains EIGHT for pass-fields' operand half -- arity,
# the declared-field reference, the per-field width lookup, the width bound and
# its off-by-one, both directions of `low <= high`, and the join. Passes stay at
# 49 and mutations become 292 + 8 = 300.
#
# Slice ② task 3: Pass 33 gains FIVE for the zero-width census -- out-targets,
# the zero-progress walk and its REPORT set (the pair the M3 precedent warns
# about, separable only after a fixture was added for it), and both directions of
# the :908 gate. FIVE shipped pins were re-anchored in the same commit, three of
# them for the same reflowed report guard. Passes stay at 49 and mutations become
# 287 + 5 = 292.
#
# Slice ② task 2: Pass 33 gains FIVE for the multi-successor eof-terminal
# rewrite -- four pinned and one EXPECT_SURVIVES for the completed-set, whose job
# is complexity rather than correctness. Three shipped eof-terminal pins were
# RE-ANCHORED in the same commit (the `seen` list became the DFS path stack, the
# pause arm moved into `eof-successors`, and the arm-5 anchor ended on the
# `(else 'unknown)` decision 0021 item 3 deletes). Passes stay at 49 and
# mutations become 282 + 5 = 287.
#
# Slice ② task 1: the ir pass gains SEVEN for the two zero-width node kinds --
# the two closed sets, the proper-list check, both directions of the error-slot
# rule, and one per census site (`node?`, `node-name`). No pass is added and
# graph.sls gets none, for the reason recorded at those mutations' site.
# Passes stay at 49 and mutations become 275 + 7 = 282.
#
# Slice ①b's Important fix wave: 273 -> 275. Two more join Pass 33, for the field
# name each diagnostic carries in its `node` slot -- a decision stated in §0 D2
# and in verify.sls's own comment, and asserted nowhere until the whole-branch
# review found verify-tests.sps reading every diagnostic through a `codes` helper
# that is blind to that slot.
#
# Whole-branch total for this branch: the merge base's 249 to 275, **+26**, which
# a per-SPEC census independently confirms (240 -> 266 mutation BLOCKS; the two
# counts differ because a one-line block is lexed but not counted the same way,
# and it is the DELTA that has to agree).

# Milestone 11 Slice ① (the fourteenth node kind, keyword-table): 65/606 -> 68/619.
# Milestone 10 (65/602 -> 65/606, the empty-span fragment work) landed on main
# first, so this slice's base is 606, not the 602 it was measured against; the
# arithmetic is +3 passes and +13 mutations over whichever base, and the merge
# reconciles to 619.
# THREE new passes, one per new lane -- 66 the interpreter walk
# (unit.keyword-table, 4 mutations: the fold, the delimiter reexecute, the
# eof-target-of arm, the terminal-vs-proper-prefix test), 67 the generated
# compact-table walk (differential.keyword-table, 8 mutations: the op's own fold
# and delimiter and terminal test, a matched keyword routed to no-match, the
# normalizer dropping the case-insensitive flag -- pinned on the fingerprint
# group it alone reddens -- and three from the Slice ① adversarial review: the
# no-match position-kind, the advance no-match consume, and the keyword-table
# entry in the reached-declaration credit list), and 68 the emitted ABI literal
# (determinism.keyword-table, 1 mutation, caught by the v6 runtime refusing the
# v5-stamped library). The closed-set FORMS are carried by ir.sls's "fourteen
# kinds" census ratchets, re-anchored in place; seventeen shipped pins were
# re-anchored to the keyword-table arms this slice inserted (twelve FINDs, two
# draw-table got-lists, two census-count literals, and the Layer-3 row-6 pin
# re-homed onto the deterministic fixture the draw-table growth left as its only
# witness).
#
# Milestone 11 Slice ② (per-table case-insensitivity): 68/619 -> 69/622. ONE new
# pass -- 69 the folded-collision rejection (differential.keyword-header, 3
# mutations: the collision arm never firing, the per-table guard dropped so a
# case-sensitive table is wrongly refused, and the verifier's own fold going the
# wrong direction), each caught absolutely by the header lane's collision verify
# group. No node kind, ABI, or golden moves; no shipped pin re-anchored (nothing
# was pinned on node-keyword-defects).
set(EXPECTED_PASSES 69)
set(EXPECTED_MUTATIONS 622)
# Sixty-two is sixty-one plus one: Milestone 8 Slice ① adds one pass over the
# request-line fixture (http-machine.sls) with three mutations (590 -> 593),
# each caught by byte-machine.unit.http-request-line with a measured signature.
# Sixty-three is sixty-two plus one: Slice ② adds a second pass over the same
# fixture's header section with three mutations (593 -> 596), each caught by
# byte-machine.unit.http-message with a measured signature.
# Sixty-four is sixty-three plus one: Slice ③ adds a third pass over the fixture's
# framing recognition with three mutations (596 -> 599), each caught by
# byte-machine.unit.http-framing with a measured signature.
# Sixty-five is sixty-four plus one: Slice ④ adds a fourth pass over the fixture's
# chunked body and trailers with three mutations (599 -> 602), each caught by
# byte-machine.unit.http-chunked with a measured signature.
# Milestone 10 Slice ① (empty-span observability, decision 0042) adds no pass but
# four mutations (602 -> 606): three in the span differential lane -- the
# `from == to` empty-delivery guard, the deliver! flag-set, and the parser-finish!
# mark re-anchor to 0 (item 4's uniform EOF delivery) -- and one in the property
# lane -- the span-close flag reset, witnessed by the coverage machine's
# covx->covy two-span run. The pre-existing suppression pin was RE-AUTHORED in
# place (net 0): its `from >= to` FIND now sits in span-fragment-suppress-empty
# (the flush), and its witness moved to the flush's own empty case.

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
# Twelve pairs of mutations in these lanes still cross-match, and they are NOT
# all the same thing. Classified by the only test that separates them -- do the
# two mutants' FAIL-record sets actually DIFFER? -- they fall in two groups.
#
# (a) SUBSUMED -- ten pairs. The narrow mutation's ENTIRE failure set is a
# subset of the broader one's, with byte-identical details: a decision killed
# again by a switch above it. No pin can separate these, and that sentence is
# the complete record -- there is no text in the narrow mutant's output that is
# not also in the broad one's.
#   p32 resume-on-paused-feed   < feed-pause maps to paused-feed
#   p32 resume-on-paused-finish < EOF pause parks paused-finish
#   p32 /v2 finish error stored < /v2 finish drives exec with finish? true
#   p33 pause joins zero-progress walk    < zero-progress never fires
#   p33 pause-only zero-progress cycle    < zero-progress never fires, AND
#                                         < pause joins the walk (two pairs)
#   p33 byte-reachable pause chain is EOF < EOF-reachable stop accepted
#   p33 byte-reachability gate (:908)     < pause continuation out-target
#   p39 pause draw, eof draw              < inverted dispatch byte test (two)
#
# (b) SEPARABLE, DECLINED -- two pairs. The sets DIFFER, so a pin separating
# that pair does exist. Measured against the whole lane, each one only moves
# the collision to a different sibling, and moves the pin off the check that
# states the decision. Calling these "unfixable" would be false:
#   p33 pause continuation out-target  vs  missing-target never reported.
#     They differ: the narrow mutant also fails "a well-formed pause machine
#     verifies: accepted". Pinning that excludes the broad mutant -- and
#     matches the byte-reachability-gate mutation instead, whose sole witness
#     that check is -- while moving this pin off "missing-target diagnostic",
#     the check that states this decision. One collision traded for another.
#   p33 eof-terminal chains through pause  vs  eof-target cycle is a finish.
#     They differ: the narrow mutant also fails the ":909 EOF chain through a
#     pause into a stop" case. Pinning that (parentheses escaped) excludes the
#     broad mutant and matches "EOF-reachable stop accepted" instead, while
#     moving the pin off the eof-cycle case that states this decision.
#
# Proved by exhaustion rather than argued: for every one of the eleven narrow
# mutations, EVERY FAIL record it emits is also emitted by some sibling in its
# own lane, so no collision-free pin exists for any of them. None is an
# under-anchored pin with a strictly better anchor going unused. The one
# genuinely separable family this slice owns -- Pass 35's two pause-fingerprint
# mutations -- WAS separated, by putting each mutant's distinct "got" digest in
# its pin.
#
# AMENDED by Milestone 3 Slice ① Task 3's whole-pass audit of Pass 33. Four of
# the six p33 entries above no longer hold, and the reason is worth keeping:
# "no collision-free pin exists" was measured correctly and read too widely.
# It is a statement about the pins available against the SPEC AS IT STOOD, not
# about the decisions -- and the two that were filed under (b) as separable
# but declined were, on re-measurement, not merely declined but closable, by
# adding the assertion whose absence made them look unfixable. Now closed, by
# three new cases/checks in verify-tests.sps (see Pass 33's own header):
#   p33 byte-reachability gate (:908)     -- was subsumed; the "accepted"
#     verdict it shared with two siblings is now backed by per-code
#     attribution checks, and each of the three fails its own.
#   p33 pause continuation out-target     -- was (b); pinned on its
#     reachability half, which no sibling touches, instead of its resolution
#     half, which "missing-target never reported" shares entirely.
#   p33 eof-terminal chains through pause -- was (b); a fixture carrying BOTH
#     EOF terminal kinds gives it a count no sibling produces.
# Still subsumed, and re-measured as such: p33 pause joins the zero-progress
# walk, p33 pause-only zero-progress cycle (two pairs), p33 byte-reachable
# pause chain is EOF. Nothing here re-measures the p32/p39 lanes, whose
# entries above stand as written.
#
# That paragraph originally continued "the same trade the four pre-existing
# one-byte-fingerprint pins in that pass decline". The count and its qualifier
# were both right -- exactly four pins carried the one-byte golden -- and only
# the tense has gone stale: they TAKE that trade now, each carrying its own
# measured "got" digest, for the reason this slice found first.
#
# The cross-matching family is five, which is a different number from a
# different question: the four one-byte-fingerprint pins, plus the node-eof pin
# on the node-routing golden, which the same FNV change moves. All five were
# category 3 -- separable, because each mutant hashes to a distinct digest, but
# pinned on a shared EXPECTED golden that every fingerprint-affecting mutation
# in the lane prints. Closing all five takes this lane's residual cross-matches
# to zero.
#
# THE COST, STATED SO IT IS NOT REDISCOVERED. An IR-encoding change moves the
# expected goldens; there are now ~15 sites carrying one, not ten. The five
# "got" digests are different in kind from the rest: an expected golden is
# RECOMPUTED by re-running the lane, but a "got" digest can only be
# RE-MEASURED, by applying that one mutation to a staged copy and reading what
# it printed. That is mechanical -- it is what this pass's own audit did -- but
# it is a step the ordinary re-baseline flow does not perform, so a re-baseline
# that only recomputes the expected values will leave five pins pointing at
# digests no mutant produces any more, and the suite will say so as
# wrong-reason rather than silently.
#
# On a different axis, and still declined: the p39 pair has a SPEC-level
# remedy. property-differential-tests.sps counts a pause only when BOTH sides
# agree they paused, so a compile.sls divergence zeroes the same two
# anti-vacuity counters the generator mutations zero. Counting the oracle's own
# pause instead would separate them, but it would weaken what the guard asserts
# (that the LANE drove a real agreeing pause) for a pin-specificity gain, and
# both mutations are already caught at their own checks.

include("${CMAKE_CURRENT_LIST_DIR}/MutationRunner.cmake")

get_filename_component(SOURCE_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)

if(DEFINED ENV{BYTE_MACHINE_TEST_TMPDIR})
  set(WORK_DIR "$ENV{BYTE_MACHINE_TEST_TMPDIR}")
else()
  set(WORK_DIR "${SOURCE_ROOT}/build/scheme-mutation")
endif()
set(STAGE_DIR "${WORK_DIR}/stage")

# Milestone 5 Slice ⓪ task 6: the diagnostic census READS verify.sls and ir.sls
# as data, and under this suite it must read the STAGED tree -- the one the
# mutation was applied to. Set once, here, rather than per pass: every
# execute_process launched from this script inherits it, so the census sees the
# same text the lane is executing. Reading ${CMAKE_SOURCE_DIR} instead would make
# every source-side mutation report as caught while the census compared the
# pristine file against itself.
set(ENV{BYTE_MACHINE_SOURCE_ROOT} "${STAGE_DIR}/src")

# Milestone 7 Slice ④: the rejections program reads verify-oracle.sls as a datum
# (the matcher-bytes prohibition) under BYTE_MACHINE_HARNESS_ROOT, for the same
# reason -- under this suite it must read the STAGED harness tree, so the
# matcher-bytes-in-the-oracle mutation (Pass 60) is seen. Set once here.
set(ENV{BYTE_MACHINE_HARNESS_ROOT} "${STAGE_DIR}/test/support/harness")

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
  EXPECT_OUTPUT_MATCHES "hex digits render lowercase: 255")

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
  # Re-anchored in Slice ①a task 5: the interpreter's feed loop gained the
  # position-kind variable, so both tails carry it. FIND and REPLACE move in
  # LOCKSTEP -- this is a swap pair with the reexecute tail, and updating only
  # the FIND would leave the mutant replacing a two-argument tail with a
  # one-argument one, failing as an arity error rather than as the
  # consumed-count defect the pin names.
  # Re-anchored by Slice ③ task 4: the accumulate arm's digit tail is the same
  # two-argument shape, so a bare FIND matches twice. Anchored on the DISPATCH
  # arm's own preceding line, which the accumulate arm does not share.
  # Re-anchored AGAIN by Slice ③ task 4: the dispatch and accumulate arms were
  # textually identical once the op had answered, so this tail was factored into
  # `route-byte-step!`. The pin now covers BOTH arms, which is correct -- it is
  # one decision, and each arm's CALL stays separately mutable.
  FIND [[              (parser-set-offset! parser (+ 1 (parser-offset parser)))
              (loop (+ pos 1) 'boundary))]]
  REPLACE [[              (parser-set-offset! parser (+ 1 (parser-offset parser)))
              (loop pos 'byte))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "one-byte parser lifecycle\\.the accepted byte stops after consuming one byte: consumed")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: need-input becomes a spurious stop"
  # Re-anchored by Slice ③ task 4: the accumulate arm yields need-input at the end
  # of a slice exactly as the dispatch arm does, so a bare FIND matches twice.
  # Anchored on the DISPATCH arm specifically: Slice ③'s accumulate arm yields
  # need-input at the end of a slice in the same shape, so a bare FIND matches
  # twice. That duplication is NOT factored -- the two guards are separate
  # decisions about two kinds, and only their tails coincided.
  FIND [[            ((dispatch)
             (if (>= pos end)
                 (make-parser-result 'need-input pos]]
  REPLACE [[            ((dispatch)
             (if (>= pos end)
                 (make-parser-result 'stopped pos]]
  EXPECT_STATUS 1
  # Not bare "need-input": that word also appears in the DETAIL of unrelated
  # runtime mutants ("expected need-input, got stopped"), so it was satisfied
  # by failures it does not name. Measured: this case and check.
  EXPECT_OUTPUT_MATCHES "an empty slice needs input and reports no result yet: status")

# The stream-offset increment is a decision distinct from the pos cursor: the
# accept case pins it to 1, the reject case to 0, so a no-op increment reddens
# only the accept case (consumed and next stay correct).
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: advance does not increment the stream offset"
  # Re-anchored by Slice ③ task 4 onto `route-byte-step!`, where the increment
  # now lives once for both byte-consuming kinds.
  FIND [[              (parser-set-offset! parser (+ 1 (parser-offset parser)))
              (loop (+ pos 1) 'boundary))]]
  REPLACE [[              (parser-set-offset! parser (parser-offset parser))
              (loop (+ pos 1) 'boundary))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "one-byte parser lifecycle\\.the accepted byte stops after consuming one byte: stream offset")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: a mismatched generated-runtime ABI version is accepted"
  # Re-anchored for Milestone 4 Slice ①a task 3. This FIND was the /v1
  # constructor's guard until decision 0018 retired the versioned NAME and kept
  # the version CHECK; the same decision now lives in the ONE unversioned
  # constructor, whose first action it is. The witness is unchanged -- the live
  # guard still refuses a mismatched number -- so this is
  # MutationRunner.cmake's "update the mutation rather than deleting it" case,
  # never an EXPECT_SURVIVES.
  FIND [[    (unless (and (integer? abi-version) (= abi-version current-abi-version))
      (assertion-violation 'byte-machine-make-compiled-machine]]
  REPLACE [[    (unless #t
      (assertion-violation 'byte-machine-make-compiled-machine]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "a mismatched ABI version is refused: refused")

# (removed 2026-09-02, Milestone 4 Slice ①a) "runtime: a v1 machine is driven
# down the op path" and "runtime: the v1 result status is hard-wired to
# stopped": both witnessed the 'v1 feed-only executor path, which decision 0018
# made unconstructable and this slice deleted -- make-parser's 'v1 arm,
# parser-feed!'s v1 else, parser-feed-v1! and parser-finish!'s raising v1 arm are
# all gone. Their REPLACEs change nothing in the surviving tree and no input can
# reach what they mutated, so they were deleted WITH the code rather than left to
# report UNCAUGHT. Recorded here because the obligation is to say so beside the
# pass: decision 0018's Consequences names both LABELs and delegates the
# disposition to the slice that lands it.
#
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
  # Re-anchored again by Milestone 5 Slice ②: the result-status case is now
  # inside `dynamic-wind`'s thunk (§12.6:749), so every line moved four columns
  # right. Same decision, same reason -- only the indentation moved.
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
  #
  # 2026-09-02: an earlier version of this note justified the detail anchor by
  # reference to "runtime: the v1 result status is hard-wired to stopped", which
  # Milestone 4 Slice ①a deleted with the 'v1 executor path. The uniqueness
  # argument above stands on its own and does not depend on that sibling; the
  # reference is removed rather than left pointing at a mutation no maintainer
  # can find.
  # Re-anchored again by Milestone 5 Slice ②: the same four-column shift, for
  # the same reason as its sibling above.
  FIND [[((error) (parser-set-lifecycle! parser 'error)
                          (parser-set-stored-error! parser (parser-result-error r)))
                 ((finished) (parser-set-lifecycle! parser 'finished))]]
  REPLACE [[((error) (parser-set-lifecycle! parser 'ready)
                          (parser-set-stored-error! parser (parser-result-error r)))
                 ((finished) (parser-set-lifecycle! parser 'finished))]]
  # The detail is part of the pin: the v1-status mutation breaks this same
  # case and check, but reports "got stopped" where this one reports "got
  # ready". Measured from both.
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "error after reject -- expected error, got ready")

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
  # The detail is part of the pin: the entry-state mutation above trips this
  # same check with "expected 1, got 0"; zeroing the offset fails it with
  # "got 2". Measured from both.
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "offset zeroed then advanced by one -- expected 1, got 2")

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
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "a truthy eof-target continues to it -> finished: finished")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: a dispatch with no eof-target does not route to the default error"
  # Re-anchored for Slice ③ Task 2: Step 3(g)'s let-bound rewrite (D1's stored-
  # error site) deletes the old single-expression
  # `(make-parser-result 'error off 0 off (op 'default-eof-value))` this FIND
  # anchored. Same routing decision, same reason; the store itself is a
  # separate decision, tested below.
  # Re-anchored again in Slice ①a task 5: default-eof-value gained the exhausted
  # dispatch node (decision 0022 item 9 -- a default-EOF error has no error node,
  # so its node-name is the dispatch node's), and the record is built here from
  # the parts it returns.
  # Re-anchored by Milestone 6 Slice ①, which factored this body into
  # `take-eof-route!` (three columns left); the mutant is unchanged.
  FIND [[(let ((e (parts->parser-error (op 'default-eof-value node) off 'eof)))
                       (parser-set-stored-error! parser e)
                       (make-parser-result 'error off 0 off e))))))]]
  REPLACE [[(let ((e (parts->parser-error (op 'default-eof-value node) off 'eof)))
                       (parser-set-stored-error! parser e)
                       (make-parser-result 'stopped off 0 off e))))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "no eof-target routes to the default-eof error: default-eof status")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: the default-eof arm does not store its value"
  # Same FIND anchor as the routing re-anchor above, a distinct decision:
  # dropping only the store (not the status) is witnessed by the brief's own
  # ②b-2-carry case, which reads the value back through a later feed.
  # Signature review: bare "stored error value" is a substring of a DIFFERENT
  # check's own label, "feed-stored error value" (the feed-side store's
  # witness below) -- pinned to this case's own name instead.
  # Re-anchored by Milestone 6 Slice ①, which factored this body into
  # `take-eof-route!` (three columns left); the mutant is unchanged.
  FIND [[(let ((e (parts->parser-error (op 'default-eof-value node) off 'eof)))
                       (parser-set-stored-error! parser e)
                       (make-parser-result 'error off 0 off e))))))]]
  REPLACE [[(let ((e (parts->parser-error (op 'default-eof-value node) off 'eof)))
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
  #
  # Pinned on the check and its detail rather than on the usual `<case>: <what>`
  # shape: this case's name ends in "(§12.2)", and a pin cannot carry the
  # parentheses unescaped. The detail is measured from a real run of this
  # mutation and states the decision directly -- a feed on a parser parked at a
  # finish node reports finished, not stopped. The bare "status" it replaces was
  # a substring of the summary line's own `status=`.
  #
  # The leading ": " is load-bearing, and Slice 3 is why. That slice's re-finish
  # mutation emits the same detail on the same case's OTHER check -- "sticky
  # status -- expected finished, got stopped" -- so without the colon this pin
  # matched that mutation too. The colon binds the pin to a check named exactly
  # "status": in the sibling's line the two characters before "status" are
  # "y ", not ": ". Measured against both mutants post-merge, and a worked
  # example of the rule that a pin is only verified against the mutants that
  # existed when it was measured.
  FIND [[(make-parser-result 'finished pos (- pos start) (parser-offset parser) #f)]]
  REPLACE [[(make-parser-result 'stopped pos (- pos start) (parser-offset parser) #f)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES ": status -- expected finished, got stopped")

# Milestone 2 Slice ②b-2's Task 1 (the dormant /v2 runtime machinery) adds two
# more decisions to this pass, both proven by the /v2 stub group in
# runtime-tests.sps. First: parser-finish-v2! must drive exec with finish? #t,
# not #f -- with #f, the empty-slice dispatch returns need-input instead of the
# default-eof error, so the finish case's `default-eof code` check reddens. The
# FIND's `empty-bv 0 0 #t` is unique to the finish driver (parser-feed-v2! calls
# exec with `bv start end #f`).
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: a payload short of the current ABI's members is accepted"
  # Milestone 5 Slice ①b's final review: the guard shipped with no test and no
  # pin. Without it the runtime reads a member out of a payload that has none
  # and fails with an index error deep in make-parser instead of a named
  # refusal at construction.
  #
  # *** RE-ANCHORED and RE-LABELLED by Milestone 5 Slice ②, which found the
  # guard chain undiscriminating. *** The shipped shape was two length guards,
  # one per ABI version; adding member 2's made it three and the ①b guard's
  # mutation went UNCAUGHT, because a later minimum subsumes every earlier one
  # and the mutant simply fell through to the next guard. The three collapsed
  # into one guard reading `current-abi-members`, which is what this now
  # witnesses -- deleting it exposes `(vector-ref metadata 2)`, whose `who` is
  # not the constructor's.
  FIND [[    (unless (and (vector? metadata)
                 (>= (vector-length metadata) current-abi-members))]]
  REPLACE [[    (unless (vector? metadata)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "a payload short of the current minimum is refused")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: a /v2 finish does not drive exec with finish? true"
  # Re-anchored in Slice ①a task 3: emitted `exec` gained its reserved seventh
  # parameter, so both call sites gained an argument.
  # Re-anchored by Slice ② task 8: the seventh argument stopped being the shared
  # `empty-fields` sentinel and became the parser's own vector, which is what
  # the reservation was FOR. The `finish?` flag this pin names is unchanged.
  # Re-anchored by Milestone 5 Slice ①a task 2: both call sites gained `psr` and
  # `cbv` (decision 0025 point 3). The `finish?` flag is STILL what this pin
  # names, and it is still the sixth argument -- only the tail grew. (Counted:
  # current-state, offset, empty-bv, 0, 0, #t.)
  # Re-anchored AGAIN by Milestone 5 Slice ② task 3: the ninth argument stopped
  # being the shared `empty-callbacks` sentinel and became the parser's own slot
  # vector, which is what ①a reserved it for -- the same correction Milestone 4
  # Slice ② made to `empty-fields` one parameter earlier. FIND and REPLACE move
  # together; the flag this pin names is still the sixth argument and still the
  # only difference between them.
  FIND [[(o (exec (parser-current parser) (parser-offset parser) empty-bv 0 0 #t
                    (parser-field-values parser) parser (parser-callbacks parser))))]]
  REPLACE [[(o (exec (parser-current parser) (parser-offset parser) empty-bv 0 0 #f
                    (parser-field-values parser) parser (parser-callbacks parser))))]]
  # Re-pinned by Milestone 5 Slice ②, onto a STRICTLY BETTER record. Driving
  # `exec` with finish? #f makes it answer `need-input`, and the finish path's
  # own invariant -- every EOF outcome is terminal or paused, so the `busy` it
  # writes is always overwritten before it returns -- now catches that by name
  # and irritant. The old pin was the default-eof code, which is a downstream
  # consequence; this one names the thing the mutation actually breaks.
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "the finish path left the parser busy with irritant need-input")

# Second: the /v2 TOMBSTONE. Milestone 4 Slice ①a task 3 rewrote both retired
# constructors to refuse EVERY version rather than the one they are named for,
# because the moment current-abi-version moved to 3 the old literal-2 guard
# would have accepted exactly the stale files it was added to refuse -- a hole,
# not a tombstone. What this mutation now witnesses is that the tombstone still
# raises. (The comment this replaces was already false at HEAD before the slice:
# it said "the emitter still emits /v1, so current-abi-version stays 1".)
# The superseded text read: the /v2 constructor's ABI-version guard checks the literal 2 (the
# emitter still emits /v1, so current-abi-version stays 1), textually distinct
# from the /v1 guard's `(= abi-version current-abi-version)` above. Accepting any
# version lets the /v2 refusal test call it with abi 1 without raising.
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: the /v2 tombstone accepts a version"
  # Three textually distinct guard forms is a hard constraint, not style: every
  # mutation runs at the default SITES of 1, asserted exactly, so writing any two
  # of the live guard and the two tombstones alike takes one FIND from one site
  # to two and fails the suite at declaration.
  FIND [[    (assertion-violation 'byte-machine-make-compiled-machine/v2
                         "retired generated-runtime ABI (superseded by the unversioned constructor)"]]
  REPLACE [[    (list 'accepted
                         "retired generated-runtime ABI (superseded by the unversioned constructor)"]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "the retired constructors refuse every version: none accepted")

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

# Task 7 close-out review: the whole-arm mutation above is caught by "resume
# on ready", but a narrower mutant admitting ONLY error/finished (leaving
# ready/stopped/finish-ready correctly refused) would have survived -- those
# two cells (§12.2:696-697) had no direct witness. Closed by adding two
# check-raises cases (runtime-tests.sps, "resume is prohibited outside the
# paused rows") plus this mutation. Measured: the thunk returns the mutant's
# own 'ok literal instead of raising, on both new checks; pinned to the
# first ("resume on error"), a label unique in this file, with the literal
# returned value making the pin specific to this exact mutant.
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: resume admits error/finished instead of refusing them"
  FIND [[(else (byte-machine-contract-violation 'parser-resume! 'lifecycle-violation
                                             (list (parser-lifecycle parser) 'resume)))]]
  REPLACE [[((error finished) 'ok)
      (else (byte-machine-contract-violation 'parser-resume! 'lifecycle-violation
                                             (list (parser-lifecycle parser) 'resume)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "resume on error -- expected a raise, but the thunk returned ok")

# Self-review, same close-out pass: auditing criterion 4's "every reachable
# cell" claim by hand (the same check the review above applied to resume!)
# found a second unwitnessed cell -- finished x finish!, parser-finish!'s OWN
# sticky arm (distinct from parser-feed!'s sticky-finished arm, LABEL
# "runtime: a feed on a finished parser does not return finished" above,
# which this file's Slice ③ pin re-audit already found pins bare "status").
# Closed the same way: one more check in the existing "eof-target continues
# to it -> finished" case (runtime-tests.sps) plus this mutation.
#
# Measured: a single FAIL, on the new check only (the first finish! call, via
# the executor's own finish arm, is untouched by this REPLACE and still
# passes). The naive pin "sticky status -- expected finished, got stopped"
# does NOT discriminate -- hand-measured against that sibling mutation
# above: it ALSO fails a check named "sticky status" with the SAME "expected
# finished, got stopped" text, as a cascading effect (its mutant corrupts
# lifecycle to 'stopped after the FIRST feed, so the second feed's own
# sticky-status check reports the identical wrong value). The case-name tail
# is what separates them -- "continues to it -> finished" occurs only in
# this mutation's own case.
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: a re-finish on a finished parser does not return finished"
  FIND [[((finished) (make-parser-result 'finished (parser-offset parser) 0
                                      (parser-offset parser) #f))]]
  REPLACE [[((finished) (make-parser-result 'stopped (parser-offset parser) 0
                                      (parser-offset parser) #f))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "continues to it -> finished: sticky status -- expected finished, got stopped")

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
  # Re-pinned by Milestone 5 Slice ②. The mutant used to fall into `parser-feed!`'s
  # `else`, which meant "ready" and EXECUTED, so the case failed with "expected a
  # raise, but the thunk returned". That else is now LOUD -- it had to be, or
  # adding `busy` and `poisoned` to the lifecycle vocabulary would have made a
  # poisoned parser re-execute -- so the mutant raises the wrong condition
  # instead of none. Measured: the predicate rejects it by `who`/`code`.
  EXPECT_OUTPUT_MATCHES
    "feed on paused-feed -- raised object did not satisfy the predicate: Exception in parser-feed!: unknown lifecycle")

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
  # Re-pinned by Milestone 5 Slice ② for the same reason as its feed sibling:
  # `parser-finish!`'s else is loud now, so the mutant raises the wrong
  # condition rather than executing.
  EXPECT_OUTPUT_MATCHES
    "finish on paused-feed -- raised object did not satisfy the predicate: Exception in parser-finish!: unknown lifecycle")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: the error row returns the STORED error"
  # Re-anchored by Milestone 5 Slice ②: the arm moved four columns right under
  # `dynamic-wind` (§12.6:749). The edit -- drop the store -- is unchanged.
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
  # Re-anchored in Slice ①a task 5: the arm builds the record from the parts the
  # executor returns plus the loop's own offset and position kind.
  FIND [[(let ((e (parts->parser-error (op 'error-value node) off pk)))
             (parser-set-stored-error! parser e)
             (make-parser-result 'error off 0 off e)))]]
  # The REPLACE drops ONLY the store. An earlier re-anchor updated the FIND to
  # the post-slice text but left the REPLACE at the pre-slice one, so the mutant
  # made two changes at once -- dropping the store AND reverting `e` to the raw
  # parts list -- and the pinned line could have come from either. One mutation,
  # one decision.
  REPLACE [[(let ((e (parts->parser-error (op 'error-value node) off pk)))
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
  # *** THE SURVIVOR IS CLOSED, and Milestone 5 Slice ② closed it without
  # trying to. *** Its recorded reason -- twice re-measured, and true every
  # time -- was that whole-arm deletion "falls through to parser-feed!'s shared
  # `else` branch", where the op path re-derived the identical result tuple. So
  # the survivor rested entirely on that else meaning "ready". Slice ② had to
  # make the else LOUD: `busy` and `poisoned` joined the lifecycle vocabulary,
  # and an else that executes every unnamed value would have made a poisoned
  # parser silently re-execute. With the else loud, the deleted arm's lifecycle
  # reaches it and raises, and the specification catches this mutant by name and
  # irritant.
  #
  # The general point, recorded because it cost two re-measurements to keep the
  # old reason honest: a survivor whose argument depends on a permissive
  # fall-through stops being a survivor the moment that fall-through is closed.
  # A written reason is only as durable as the control-flow shape it names.
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "re-feeds to finished, consuming zero .*: case raised -- Exception in parser-feed!: unknown lifecycle with irritant finished")

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

# Final whole-branch review of Slice ③ (pre-merge) found two Critical gaps in
# this pass, both the same defect class the sticky error arm's `next` field
# closed above: every existing pause fixture feeds from start 0 / a fresh
# offset 0, so a field that should read a computed position is
# indistinguishable from one that reads a coincidentally-equal constant.
# Both were measured on a copy of the tree before being closed: the
# unmodified suite stayed green (cases=35 failed-cases=0) with the mutant
# REPLACE below already in place.
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: the feed pause arm's consumed and stream offset collapse to next"
  # Critical 1. parser-feed-op!'s pause arm reads `pos` for next, `(- pos
  # start)` for consumed, and `(parser-offset parser)` for stream-offset --
  # three DIFFERENT expressions that every existing pause fixture feeds from
  # start 0 with exactly one byte consumed, where all three evaluate to 1.
  # Closed by a new nonzero-start case in runtime-tests.sps ("a nonzero-start
  # feed pause separates next, consumed, and stream offset"), which feeds
  # #vu8(9 1 2)[1,3) so next (2) separates from the other two (both still 1).
  FIND [[(make-parser-result 'paused pos (- pos start) (parser-offset parser) #f))]]
  REPLACE [[(make-parser-result 'paused pos pos pos #f))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "separates next, consumed, and stream offset: consumed -- expected 1, got 2")

# T8 re-review residual: the nonzero-start case above separates `next` from
# the pair, but NOT `consumed` from `stream-offset` -- on any single feed
# call from a fresh parser those two are equal by construction (the offset
# starts at 0, so the cross-call total equals this call's own count), so a
# mutant that only SWAPS the two expressions (rather than collapsing all
# three) is invisible to it. Measured on a copy of the tree before being
# closed: the swap below, re-anchored on the SAME FIND the mutation above
# uses, left the whole release preset green (72/72) with only the
# nonzero-start case in place. Closed by a second feed call in
# runtime-tests.sps ("a second feed call separates consumed from stream
# offset"): finish-pause-op's s1 now also advances on byte 2 into a second,
# byte-reachable pause, so the first call's advance (offset 0->1) makes the
# second call's own consumed (1) and the persisted stream-offset (2) diverge.
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: the feed pause arm swaps consumed and stream offset"
  FIND [[(make-parser-result 'paused pos (- pos start) (parser-offset parser) #f))]]
  REPLACE [[(make-parser-result 'paused pos (parser-offset parser) (- pos start) #f))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "separates consumed from stream offset: consumed -- expected 1, got 2")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: an EOF pause after consuming bytes reports zero instead of the persisted offset"
  # Critical 2. parser-finish-op!'s pause arm reads `off` -- (parser-offset
  # parser), snapshotted at the top of the call -- into both the next and
  # stream-offset slots. No fixture before this task reached an EOF pause
  # after consuming any bytes (pause-op's own s1 routes its eof-target to
  # the error node 'trunc, not a pause), so `off` was always already 0 and a
  # hard-coded 0 was indistinguishable. Closed by a fourth op stub in
  # runtime-tests.sps, finish-pause-op (s0 --1/advance--> s1, s1's eof-target
  # a pause continuing to a finish), and its own case.
  #
  # Measured collision: this mutation's failure set is a SUBSET of the
  # pre-existing "runtime: advance does not increment the stream offset"
  # mutation's, on the SAME two checks ("next", "stream offset" in the new
  # case both read 0 instead of 1) -- that mutation breaks the one write
  # site that would make `off` become 1 in the first place, this one
  # discards a correctly-computed `off` at the read site, and this fixture
  # cannot tell them apart because proving `off` is nonzero here has no
  # route that avoids the shared increment statement (the 'op variant's
  # only write site for parser-offset). No pin can separate them -- the
  # SUBSUMED pattern this file's pin re-audit already documents for ten
  # other pairs above.
  # Re-anchored by Milestone 5 Slice ②: `parser-finish-op!` gained a callback
  # arm whose pause branch parks and reports identically, so the bare result
  # form now occurs twice. Widened to include the PAUSE NODE's own
  # `pause-target` line, which is what makes this the pause node's decision and
  # not the callback node's; the callback arm's copy has its own mutation in
  # Slice ②'s pass at the foot of this file.
  FIND [[(parser-set-current! parser (op 'pause-target node))
           (parser-set-lifecycle! parser 'paused-finish)
           (make-parser-result 'paused off 0 off #f))]]
  REPLACE [[(parser-set-current! parser (op 'pause-target node))
           (parser-set-lifecycle! parser 'paused-finish)
           (make-parser-result 'paused 0 0 0 #f))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the persisted offset, not zero: next -- expected 1, got 0")

# Minor finding, same review: finish-ready's own membership in parser-feed!'s
# prohibited clause had a test (runtime-tests.sps's "feed on finish-ready"
# case) but no mutation -- the pre-existing "runtime: feed refuses every
# paused/finish-ready row" mutation above drops paused-feed instead, and is a
# separate decision (measured: dropping finish-ready does not also un-refuse
# paused-feed, and vice versa). finish-ready is the row that closes the
# resume-then-feed-into-finish route, so it is its own decision.
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: feed admits finish-ready instead of refusing it"
  FIND [[((paused-feed paused-finish finish-ready)
       (byte-machine-contract-violation 'parser-feed! 'lifecycle-violation]]
  REPLACE [[((paused-feed paused-finish)
       (byte-machine-contract-violation 'parser-feed! 'lifecycle-violation]]
  EXPECT_STATUS 1
  # Re-pinned by Milestone 5 Slice ②: `parser-feed!`'s else is loud now, so the
  # mutant raises the wrong condition rather than executing. Same decision.
  EXPECT_OUTPUT_MATCHES
    "feed on finish-ready -- raised object did not satisfy the predicate: Exception in parser-feed!: unknown lifecycle")

# Milestone 4 Slice ①a task 2: the parser-error record's two construction
# decisions (decision 0022 items 1 and 2). Nothing outside runtime-tests.sps
# builds one until task 5, so these are witnessed by that file's own cases --
# which is the point: the shape is pinned BEFORE anything depends on it.
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: the ABI version check does not come first"
  # Decision 0018 item 1: the check precedes every other guard, so a mismatch is
  # reported before any part of the payload is interpreted -- which is what makes
  # the payload safe to grow. Witnessable only by a predicate that names WHICH
  # guard fired: every guard here raises assertion-violation with the same `who`,
  # so the case's original bare assertion-violation? predicate passed whichever
  # one fired and could not observe the ordering it is named for. The irritant is
  # the only thing that differs between them.
  FIND [[    (unless (and (integer? abi-version) (= abi-version current-abi-version))
      (assertion-violation 'byte-machine-make-compiled-machine
                           "generated-runtime ABI mismatch" abi-version))
    (unless (procedure? exec)
      (assertion-violation 'byte-machine-make-compiled-machine "exec must be a procedure" exec))]]
  REPLACE [[    (unless (procedure? exec)
      (assertion-violation 'byte-machine-make-compiled-machine "exec must be a procedure" exec))
    (unless (and (integer? abi-version) (= abi-version current-abi-version))
      (assertion-violation 'byte-machine-make-compiled-machine
                           "generated-runtime ABI mismatch" abi-version))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the VERSION is named, not the payload")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: a machine error is constructed in the callback domain"
  # §9.3:398's domain is `machine | callback`, and `callback` has exactly one
  # producer in the whole plan -- §13:808's callback failure, Milestone 5. A
  # constructor that hard-wires the wrong member of a two-member enumeration is
  # invisible to every M4 test that does not read the slot, which is why the
  # accessor case reads it rather than assuming it.
  FIND [[    (vector parser-error-tag 'machine (vector-ref entry 0) (vector-ref entry 1) #f]]
  REPLACE [[    (vector parser-error-tag 'callback (vector-ref entry 0) (vector-ref entry 1) #f]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "domain and detail are fixed by the constructor: domain")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: the errs entry is unpacked reason-first"
  # The entry packs (code . reason) positionally and both are read from the same
  # two-element vector, so transposing them type-checks and survives anything
  # that reads only one of the pair. Caught by a failed comparison on the code,
  # not by a raise.
  FIND [[    (vector parser-error-tag 'machine (vector-ref entry 0) (vector-ref entry 1) #f]]
  REPLACE [[    (vector parser-error-tag 'machine (vector-ref entry 1) (vector-ref entry 0) #f]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the five call-site members read back: code")

# Milestone 6 Slice ⓪: §9.3:423's grammar half at the runtime, the deferral
# Milestone 5's completeness check left with a named receiver. The mutant is
# the Milestone 5 constructor exactly -- `symbol?` alone -- and the lane's new
# case refuses `BadCode` under the grammar it shares with verify.sls.
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: a callback failure code is not checked against the portable grammar"
  FIND [[(unless (and (symbol? code) (portable-name? code))]]
  REPLACE [[(unless (symbol? code)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "portable name grammar .§9.3:423.: BadCode refused -- expected a raise")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 33: the verifier's decisions (Milestone 1 Phase 2) -----------------
#
# verify-tests.sps asserts the exact diagnostic CODE emitted for each broken
# variant of the one-byte machine (never rendered text, parent §16.4); this pass
# proves those code assertions are not vacuous by suppressing the decision that
# emits each code and requiring the owning case to notice. Verify command
# uses both library roots, an empty object guard, and the verify program.
# Each FIND is a verbatim, unique substring of verify.sls.
#
# WHOLE-PASS PIN AUDIT (Milestone 3 Slice ① Task 3 review). Task 3 added three
# mutations to this pass, and AGENTS.md's rule is that adding a mutation to a
# lane widens every existing pin's collision set silently -- so the whole pass
# was re-measured, not just the new arrivals. Method, the same one Pass 42's
# audit used: apply each mutation to a staged copy, capture the SPEC lane's
# full stdout+stderr, then re-judge every pin through
# byte_machine_mutation_verdict against every OTHER mutant's captured output.
# 27 mutations, 702 ordered pairs. Fifteen collided.
#
# Sorted by the test AGENTS.md names -- do the two mutants' FAIL RECORD sets
# actually differ, and does the narrow one own a record no sibling emits? --
# they were three kinds, and only the third was left unclosed:
#
# (1) UNDER-ANCHORED, five pairs, fixed by re-anchoring alone. The three
# pre-pause EOF mutations were pinned on a bare diagnostic CODE
# ("non-eof-into-finish", "eof-reachable-stop", "eof-zero-progress-cycle"),
# which the Slice ③ audit had already found and fixed for this pass's PAUSE
# group while leaving the group above it bare. Each owns a "has <code>" check
# no sibling fails; each pin now names that case and that check.
#
# (2) SEPARABLE, and NOT declined -- six pairs, fixed by giving the SPEC a
# check the collision could not survive. Five mutations here had no record of
# their own at all: everything they broke, some sibling also broke, so no pin
# existed to be found and the fix had to be a new assertion. Three additions,
# all in verify-tests.sps, all measured rather than predicted:
#   * two ATTRIBUTION checks on "a well-formed pause machine verifies", whose
#     single "accepted" boolean three different mutants reddened. Naming the
#     diagnostic that must be ABSENT ("no unreachable-node", "no
#     non-eof-into-finish") splits them. This is the shape the eof-terminal-
#     chain gate below already uses: attribution, not verdict.
#   * "an EOF walk crosses a pause for both terminal kinds (§16.2:909)", which
#     counts BOTH terminal kinds an EOF walk can reach through a pause in one
#     machine. Stopping AT the pause (0), losing stop classification (1) and
#     losing cycle classification (1) had been indistinguishable case by case.
#   * "an asymmetric collision graph counts every pair, once", whose collision
#     graph is not symmetric under the two ways the pair enumeration can be
#     truncated -- the mutually-colliding triple made both truncations report 2.
#
# (3) SUBSUMED, four pairs. Recorded at each pin below, named by the LABEL of
# the mutation that subsumes it, because AGENTS.md requires the residue to live
# in the tree beside the pin. All four are a decision killed again by a switch
# above it, so the narrow mutant's whole FAIL-record set is a subset of the
# broad one's:
#   "pause continuations join the zero-progress walk" < "zero-progress
#   detection never fires"; "a pause-only zero-progress cycle is not flagged" <
#   both of those; "a byte-reachable pause's continuation chain is an EOF path"
#   < "an EOF-reachable stop terminal is accepted".
# Proved by exhaustion, not by argument: no FAIL record any of the three emits
# is absent from the subsuming mutant's output.
#
# *** RETRACTED 2026-09-03, by Slice ①b's whole-branch review. *** A note here
# claimed this file's residue count was "one short", that a FIFTH pair
# (arm 6 :908 < arm 1 node-out-targets) had been "missed, not created", and that
# "the separating attempt has NOT been made" for it. All three were false about
# the file they were written into:
#
#   * `:3418` already reads "the four subsumed pairs listed above, plus arm 6 <
#     arm 1", and `:3432` lists all five by name. The "four pairs" heading above
#     counts the SUBSUMED bucket at that audit moment; arm 6 < arm 1 is
#     reconciled six lines later. Nothing was short.
#   * `:3415-3416` records that arm 6 "is matched by arm 1, which Slice ②
#     MEASURED and recorded as genuinely subsumed at arm 6's own pin" -- the
#     attempt exists, at the pin, with its measurement, exactly where AGENTS.md
#     asks for it.
#
# Slice ①b's own sweep did measure five pairs at c3ceec2, 2302ffd and its HEAD,
# which is right and agrees with this file. What it then did was compare that
# five against the "four pairs" heading alone, without reading the six lines
# under it or arm 6's pin, and write the difference up as a discovery. The
# retraction is kept rather than deleted because the failure is the instructive
# part: a count read out of one heading, checked against nothing else in the
# same block, produced a confident correction to a record that was already
# right.
#
# ONE thing in that note survives and is not about this file. Slice ①a's PLAN
# (.plans/milestone-4-slice-1a-implementation-plan.md) records "Merge base:
# 4 collisions" and "HEAD now carries exactly the merge base's four collisions".
# Measured at c3ceec2 with this suite's own judgment semantics -- the pin regex
# compiled the way CMake compiles it, matched against whole captured output --
# that number is FIVE, the same five this file names. That plan is annotated at
# its own site.
#
# AMENDED, whole-branch review fix wave (2026-08-30), to the taxonomy commit
# 49c8cc4 wrote into AGENTS.md after this paragraph was measured. What this
# paragraph called "genuinely unfixable by any pin" is not a property any
# exhaustion test can establish. Zero unique FAIL records across the lane is a
# signal that the SPECIFICATION is under-specified here -- the lane has no
# check that separates these decisions -- not that no pin exists; only what
# survives an actual separating attempt may be called subsumed, and the attempt
# must be recorded with its measurement. Two of the three narrow mutants above
# ("pause continuations join the zero-progress walk", and "a byte-reachable
# pause's continuation chain is an EOF path") are nested by construction, which
# is the closed case. The third, "a pause-only zero-progress cycle is not
# flagged", is NOT closed: no separating fix has been attempted for it, in this
# cycle or any earlier one, and the obligation is recorded beside that
# mutation's own pin below, named by LABEL. Both remedies this pass already
# ships -- attribution checks, and count-don't-witness fixtures -- were reached
# for by other mutations here and neither has been tried on it.
#
# Residual cross-matches in this pass after the fixes: those four pairs, and
# nothing else. Re-measured after every edit above, since a new check changes
# every mutant's record set, not only the ones it was written for -- and that
# re-measurement earned its keep: the "no unreachable-node" attribution check
# added for (2) contains the whole of "verify: reachability never reports an
# unreachable node"'s bare-code pin as a substring, so a fix in the pause group
# broke a pin sixteen mutations above it. That pin is re-anchored too; see it.
#
# Five bare-code pins remain in this pass -- duplicate-name,
# missing-error-declaration, invalid-eof-target, invalid-shape,
# duplicate-error-declaration. They are not oversights: each was judged against
# all 26 siblings and matched none, because each names a decision only one
# mutation here can break. Left as measured, not as read.
#
# WHOLE-PASS PIN AUDIT, Milestone 3 Slice ③ Task 1 (§16.2:894). Six mutations
# joined this pass and six CASES joined verify-tests.sps -- and adding a check
# widens every existing pin exactly as adding a mutation does -- so the whole
# pass was re-measured by the method above, in BOTH directions: every pin
# re-judged through byte_machine_mutation_verdict against every OTHER mutant's
# captured output, plus a self-check that each pin still catches its own.
# 40 mutations, 1560 ordered pairs. The same sweep was run on the merge base
# (49c8cc4, 34 mutations) as a control, so an introduced collision could be
# told from inherited debt; before the re-anchoring described below, both
# sides reported the identical eight ordered pairs, so this task introduced
# none of them.
#
# None of the six new §16.2:894 pins collided in either direction. What the
# sweep did find was inherited: the "residual cross-matches ... and nothing
# else" sentence above was measured at 27 mutations, and Slice ② has since
# added both a mutation and a CASE that outrun it.
#   * "verify: a byte-reachable pause into finish is rejected" was matched by
#     three siblings, because Slice ② added a case whose NAME contains that
#     pin as a substring. UNDER-ANCHORED -- the mutant owns a record none of
#     the three emits -- and fixed here by re-anchoring alone; the
#     measurement is at that mutation's own pin.
#   * "verify: a sequence case's byte edge into a finish terminal is not
#     flagged (arm 6, :908)" is matched by arm 1, which Slice ② measured and
#     recorded as genuinely subsumed at arm 6's own pin.
# Residual cross-matches at 40 mutations, re-measured after that fix: the four
# subsumed pairs listed above, plus arm 6 < arm 1. Nothing else.
#
# WHOLE-PASS PIN AUDIT, Milestone 3 Slice ③ Task 2 (§25:1533). One mutation
# joined this pass, two FINDs were re-anchored onto the reflowed report guard,
# one pin was re-anchored, and a CASE WAS RENAMED -- which rewrites the FAIL
# text every pin in the pass is judged against, so this sweep was the least
# optional of the three. Same method, both directions. 41 mutations, 1640
# ordered pairs, five colliding. The control was the pre-task tree (8fc2680,
# 40 mutations, 1560 pairs): it reports the identical five, so this task
# introduced none and closed none.
#   pause continuations < zero-progress detection never fires
#   a byte-reachable pause's continuation chain is an EOF path
#       < an EOF-reachable stop terminal is accepted
#   a pause-only zero-progress cycle is not flagged < both of the first two
#   arm 6 (:908) < arm 1 (node-out-targets)
# All five are the pairs the paragraphs above already record, in the same
# direction, and by the exhaustion test rather than the subset test alone:
# exactly four mutants in the pass own no FAIL record that no sibling emits,
# and they are the four narrow sides listed here -- unchanged from the control.
# The three mutations this task touched each own one: "zero-progress detection
# never fires" and arm 3 keep theirs through the rename, and the new mutation's
# is the renamed case's "got 2". The count check that separates them is now
# four-way and every value was measured, not predicted -- correct 3, new
# mutation 2, arm 3 1, never-fires 0. Two other mutants (arm 5 and arm 7)
# print "got 1" and "got 2" on the neighbouring combined5 case, whose check
# label is `eof-zero-progress-cycle count` -- a superstring of this one's, and
# the reason all three pins carry the case-name tail rather than the check
# label alone.
#
# WHOLE-PASS PIN AUDIT, whole-branch review fix wave (Important 3). One
# mutation joined this pass ("verify: the sequence mismatch edge's MODE is not
# tested (arm 3, reexec-targets)") and ONE CHECK joined verify-tests.sps -- the
# advance case's "no zero-progress-cycle" attribution check, which that
# mutation's pin needed and which the sweep is what found necessary. A check
# widens pins exactly as a mutation does, so the whole pass was re-measured by
# the method the blocks above describe, in BOTH directions: 42 mutations,
# 1722 ordered pairs, every pin re-judged through byte_machine_mutation_verdict
# against every OTHER mutant's captured output, plus a self-check that each pin
# still catches its own. All 42 pins catch their own mutant. FIVE colliding
# pairs -- and they are the same five, in the same direction, that the Task 2
# block above records:
#   pause continuations < zero-progress detection never fires
#   a byte-reachable pause's continuation chain is an EOF path
#       < an EOF-reachable stop terminal is accepted
#   a pause-only zero-progress cycle is not flagged < both of the first two
#   arm 6 (:908) < arm 1 (node-out-targets)
# Control, run because inherited debt has to be told from introduced debt: the
# identical sweep against the pre-fix-wave tree -- this branch's tip before the
# fix wave, named that way rather than by commit hash because the branch is
# squash-merged and deleted; 41 mutations, 1640 ordered pairs -- reports the
# identical five. This fix wave introduced none and
# closed none of them; four of the five are also the exhaustion result --
# exactly four mutants in the pass own no FAIL record no sibling emits, and
# they are the four narrow sides above. See the amendment to bucket (3) in the
# Task 3 audit block at the top of this pass for how the fourth, "a pause-only
# zero-progress cycle is not flagged", is now classified, and its own pin for
# the open obligation that goes with it.
#
# The new mutation is NOT among the residue: measured at 42, it emits three
# FAIL records, one of which is unique lane-wide, and that is what its pin
# names. Before the attribution check it emitted two and owned neither -- see
# its own comment.

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
  # Re-anchored by Task 3's whole-pass audit, and it was the audit's own fix
  # that made this necessary -- the two-directional rule in the flesh. Bare
  # "unreachable-node" was collision-free when measured against the 26 other
  # mutants, and stopped being so the moment "a well-formed pause machine
  # verifies" gained a "no unreachable-node" attribution check: the pin is an
  # unanchored regex, and the new check's LABEL contains the old pin as a
  # substring, so this pin began matching "a pause continuation is an
  # out-target (resolution + reachability)". Anchored to its own case and
  # check, which no sibling reddens.
  REPLACE [[#f]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "an unreachable node is rejected: unreachable-node")

# Re-anchored in Milestone 3 Slice ① Task 1: pass-overlap now compares canonical
# matcher BYTE SETS, so the old `(if (memv b seen)` line no longer exists. The
# decision is unchanged -- two cases matching the same byte must be reported --
# and it is pinned on the helper's body rather than on the loop, so Slice ①
# Task 3's per-colliding-pair rewrite of the loop leaves this pin standing.
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: two cases sharing a byte are never found to overlap"
  FIND [[(and (pair? a) (or (and (memv (car a) b) #t) (byte-sets-overlap? (cdr a) b)))]]
  REPLACE [[#f]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "same byte overlap: overlapping-cases")

# Slice ① Task 3: the pair enumeration itself. The helper pin above proves the
# disjointness TEST fires; these three prove the pass reaches every pair, reports
# each once, and does not stop at the first collision it finds.
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: only the first case is compared against the others"
  FIND [[(outer (cdr ss)]]
  REPLACE [[(outer '()]]
  # Fix wave 1 pinned this on the second-and-third fixture's own measured
  # "got 0", which cut the collision set from two to one but not to zero:
  # "two cases sharing a byte are never found to overlap" disables
  # byte-sets-overlap? outright and produces the identical got 0 on that
  # fixture, so the two were indistinguishable there.
  #
  # Task 3 review, re-anchored on a measurement: every fixture this pass had
  # was SYMMETRIC under the two ways the enumeration can be truncated -- on a
  # mutually colliding triple, "only the first case is compared" and "each
  # case is compared only against its successor" both report 2 -- so the pin
  # had no unshared detail to reach for. "an asymmetric collision graph
  # counts every pair, once" (verify-tests.sps) breaks that symmetry by
  # construction: its colliding pairs are (1,2), (2,3), (2,4), on which the
  # four ways of breaking the enumeration report four DIFFERENT counts
  # (1 here, 2 for the sibling below, 0 for the helper mutant, 7 for the
  # self-comparison mutant) against the correct 3. Measured against all 26
  # other mutants' captured output: this pin matches no other.
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "an asymmetric collision graph counts every pair, once: three pairs -- expected 3, got 1")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a case's collisions after the first are dropped"
  FIND [[(inner (cdr rest)]]
  REPLACE [[(inner '()]]
  # Task 3 review: same fix as the mutation above, same measured fixture. On
  # the asymmetric collision graph this edit reports 2 where the sibling
  # above reports 1, the helper mutant 0, and the self-comparison mutant 7;
  # the mirror fixture it used to be pinned on could not separate it from the
  # helper mutant, which produced the identical got 0 there.
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "an asymmetric collision graph counts every pair, once: three pairs -- expected 3, got 2")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a case is compared against itself"
  FIND [[(let inner ((rest (cdr ss)) (out out))]]
  REPLACE [[(let inner ((rest ss) (out out))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "do not overlap: none")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: zero-progress detection never fires"
  # FIND re-anchored by Milestone 3 Slice ③ Task 2: PASS 5's report guard gained
  # a `(sequence-dispatch-node? n)` disjunct (§25:1533) and was reflowed onto
  # two lines. The decision, the REPLACE and the pin are unchanged.
  # RE-ANCHORED AGAIN by Slice ② task 2's census: the guard gained the two
  # zero-width kinds and reflowed onto three lines. Third re-anchor of the same
  # decision; the REPLACE and the pin are still unchanged, which is what says the
  # decision has not moved even though its text keeps doing so.
  FIND [[(and (memq (node-name n) br898)
                                     (or (byte-dispatch-node? n) (pause-node? n)
                                         (sequence-dispatch-node? n)
                                         (keyword-table-node? n)
                                         (field-action-node? n) (field-branch-node? n)
                                         (integer-accumulate-node? n)
                                         (callback-node? n)
                                         (span-start-node? n) (span-end-node? n)
                                         (counted-consume-node? n))
                                     (self-cycle (node-name n)))]]
  REPLACE [[#f]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "a reexecute self-loop is a zero-progress cycle: zero-progress-cycle")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the machine-name grammar check is suppressed"
  # Re-anchored by Milestone 6 Slice ⓪, which folded the label conjunct into this
  # arm's test: the FIND is the name conjunct alone, so the mutant drops the name
  # check and nothing else.
  FIND [[(valid-name? (machine-name m))]]
  REPLACE [[#t]] EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "an uppercase machine name is invalid-name: invalid-name")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a missing transition target is not reported"
  FIND [[(make-diagnostic 'missing-target t "no such node")]]
  REPLACE [[#f]] EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "a fallback target that names no node is missing-target: missing-target")

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
  REPLACE [[(if #t '()]] EXPECT_STATUS 1
  # Re-anchored in M3 Slice ② Task 1's pin sweep: the bare code name
  # "invalid-eof-target" is shared with a second, unrelated decision (a
  # per-node eof-target resolution failure) -- measured to ALSO match this
  # task's new arm-4 sequence mutant's captured output. Anchored to this
  # mutation's own originating case.
  EXPECT_OUTPUT_MATCHES
    "a default-eof-error naming no declared error is invalid-eof-target: invalid-eof-target")

# The remaining five decisions the verifier emits but the first eight mutations
# did not reach: the schema guard, the duplicate-error-declaration branch, the
# entry-resolution site of missing-target (distinct from the transition site
# above), and the node-name and error-code sites of the name-portability check
# (distinct from the machine-name site above). Each has its own rejection case
# in verify-tests.sps; the project's own SITES-2 split precedent (harness-group
# vs with-cleanup) requires each site of a multi-site decision to be witnessed.
# Milestone 4 Slice ①b task 3: §16.2:884's unsupported-IR-version half, listed
# since Milestone 1 and unimplemented until this slice.
#
# BOTH directions are declared and BOTH are caught. The design (§6 task 3) said
# the permissive direction was unwitnessable -- "a test cannot forge a machine?
# object" -- and told the implementer to declare it EXPECT_SURVIVES. Measured
# false: descriptors are bare R6RS vectors, so a test copies the tag with
# (vector-ref m 0), an (rnrs) primitive needing no private import, and builds a
# machine carrying any version it likes. AGENTS.md reserves EXPECT_SURVIVES for
# the genuinely unwitnessable, and "this cannot be tested" is a claim to
# demonstrate; here the demonstration goes the other way.
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: an unsupported IR version is accepted"
  FIND [[          ((not (= (machine-ir-version-of m) supported-ir-version))]]
  REPLACE [[          ((and #f (not (= (machine-ir-version-of m) supported-ir-version)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "a machine carrying an unsupported IR version is invalid-shape: unsupported version is reported")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "ir: the supported IR version is not the one machines are stamped with"
  # The restrictive direction, and the reason supported-ir-version is a second
  # constant rather than a reuse of the stamp: forcing the STAMP changes what is
  # built, forcing THIS changes what is accepted, and only the second is a
  # verifier decision. Every shipped fixture becomes unsupported at once.
  FIND [[  (define supported-ir-version 1)]]
  REPLACE [[  (define supported-ir-version 2)]]
  # RE-ANCHORED by task 4's Pass 33 sweep, which is what found it. This pin was
  # written as a bare CHECK NAME carrying no value -- "...: no diagnostics", with
  # neither the expected count nor the got -- so it matched ANY mutant that
  # reddened that case at all, and two others do: "verify: a case is compared
  # against itself" (got 1) and "verify: the reason repertoire rejects every
  # reason" (got 2). The ①a audit's finding was that a COUNT is a weaker anchor
  # than a named check; this is the degenerate case of it, an anchor with no
  # value at all, and it is weaker still.
  #
  # It is re-anchored off its own on-point case, because that case expects ZERO
  # diagnostics and so has no code to compare -- every mutant that reddens it
  # produces the same shape of record, and the only thing separating them is a
  # count that two of them share. The record below was computed as a SET
  # DIFFERENCE against all 48 other Pass 33 mutants: `got invalid-shape` where
  # another code was expected is produced by this mutation alone, because it is
  # the only one that makes pass-schema fire on a WELL-FORMED machine.
  #
  # The uniqueness is EMPIRICAL, from that set difference, and the first version
  # of this note gave it a false MECHANISM: it said pass-schema's firing
  # "short-circuits verify-machine before any later pass runs". It does not.
  # verify-machine appends pass-schema's diagnostics to the other nine passes and
  # gates those only on `(machine? machine)`, which a version-mismatched machine
  # still satisfies -- every later pass runs and its diagnostics follow. What
  # makes the record unique is narrower: pass-schema is FIRST in that append, so
  # its diagnostic is the one `codes` reports at the head, and no other mutant in
  # this pass makes a well-formed machine emit `invalid-shape` at all. Recorded
  # because a stated mechanism that does not exist is the harder kind of false
  # record -- the pin it justifies is correct, so nothing fails to warn you.
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "two fields sharing a name is invalid-field-declaration: invalid-field-declaration -- expected invalid-field-declaration, got invalid-shape")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the schema guard reports a non-machine under the wrong code"
  # Re-anchored in Milestone 4 Slice ①b task 3: pass-schema became a cond when
  # §16.2:884's unsupported-IR-version half landed beside the shape half. The pin
  # was also RE-ANCHORED ON ITS SIGNATURE, not only its FIND: bare "invalid-shape"
  # is now emitted by two arms of the same pass, so it no longer resolves to one
  # (case, check) pair. It names its own case now.
  # Mutates the CODE the arm reports, not the guard that reaches it. Suppressing
  # the guard was tried first and rejected on measurement: with pass-schema now a
  # cond, skipping the shape arm lets the version arm call an accessor on a
  # non-vector, so the mutant dies by a RAISE rather than by the failed
  # comparison this pin names -- AGENTS.md's "try the opposite constant first".
  # The FIND carries the message string because 'invalid-shape alone now occurs
  # twice in this pass.
  FIND [[           (list (make-diagnostic 'invalid-shape #f "not a machine")))]]
  REPLACE [[           (list (make-diagnostic 'invalid-name #f "not a machine")))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "a non-machine handed to verify-machine is invalid-shape: invalid-shape")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a duplicate error-declaration name is not reported"
  FIND [[(if (memq (car es) seen)]]
  REPLACE [[(if #f]] EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "duplicate-error-declaration")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: an entry that names no node is not reported"
  FIND [[(if (lookup nodes (machine-entry m)) '()]]
  REPLACE [[(if #t '()]] EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "an entry that names no node is missing-target: missing-target")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the node-name grammar check is suppressed"
  # Re-anchored by Milestone 6 Slice ⓪ for the same reason as the machine arm's.
  FIND [[(valid-name? (node-name n))]]
  REPLACE [[#t]] EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "an uppercase node name is invalid-name: invalid-name")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the error-code grammar check is suppressed"
  FIND [[(valid-name? (error-declaration-code e))]]
  REPLACE [[#t]] EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "an uppercase error code is invalid-name: invalid-name")

# Milestone 4 Slice ①a task 1 adds the reason-repertoire decision (§16.2:886,
# §10.1:480). Two mutations, one per direction, because the repertoire can be
# wrong permissively (accept a control character, which is what ships an
# unparseable generated library) or restrictively (reject a legal reason, which
# fails every shipped fixture). Both are caught by a failed COMPARISON rather
# than by a raise: the permissive one lands on a count check that reads 0 where
# the case expects 1, and the restrictive one on the clean machine's own
# diagnostic-count assertion. The pins name a case tail plus a check label, so
# each resolves to one (case, check) pair -- neither fragment appears in the
# banner, the FAIL-CONTEXT line or the summary line.
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the reason repertoire accepts every character"
  FIND [[(or (and (char>=? c #\space) (char<=? c #\~)) (char=? c #\newline)))]]
  REPLACE [[#t)]]
  EXPECT_STATUS 1
  # Anchored on the DETAIL, not just the (case, check) pair: the whole-pass
  # audit found the bare pair matched by two siblings, because any mutation
  # that suppresses the reason clause reaches this same check. The two
  # directions differ in what the count becomes -- 0 when the repertoire
  # accepts everything, 2 when it rejects everything -- so the detail is what
  # separates them.
  EXPECT_OUTPUT_MATCHES "a reason outside printable ASCII is rejected: one finding -- expected 1, got 0")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the reason repertoire rejects every reason"
  FIND [[          (and (reason-char? (string-ref s i)) (loop (+ i 1))))))]]
  REPLACE [[          (and #f (loop (+ i 1))))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "a reason may carry quote backslash and newline: no diagnostics -- expected 0, got 2")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: an EOF-reachable stop terminal is accepted"
  FIND [[((stop-node? n) (verdict 'eof-reachable-stop path))]]
  REPLACE [[((stop-node? n) (verdict 'finish path))]]
  # Task 3 whole-pass audit: bare "eof-reachable-stop" is a diagnostic CODE and
  # was measured matching TWO other mutants -- "eof-terminal chains through a
  # pause continuation" and "a byte-reachable pause's continuation chain is an
  # EOF path", both of which redden pause cases whose labels carry the same
  # code. This mutation breaks the classification for EVERY stop terminal, so
  # it is the only mutant to fail the pre-pause eof-target case's own "has
  # eof-reachable-stop" check; anchored there, parentheses escaped. (Since
  # eof-terminal's stop-classification is shared code, this mutant's own
  # captured output ALSO contains this task's new arm-7 sequence case's
  # record; that reverse direction is genuine and documented beside arm 7's
  # own pin below.)
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "an eof-target reaching a stop terminal is rejected \\(eof-reachable-stop\\): has eof-reachable-stop")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: an eof-target cycle is classified as a finish terminal"
  # RE-ANCHORED by Slice ② task 2's multi-successor rewrite. `seen` became the
  # DFS `path` stack (decision 0021 item 2's two structures), so the shipped FIND
  # went to zero sites. The decision is unchanged -- re-entering the current path
  # is a cycle -- and so is its signature.
  FIND [[(cond ((memq name path) (verdict 'cycle (cons name path)))]]
  REPLACE [[(cond ((memq name path) (verdict 'finish (cons name path)))]]
  # Task 3 whole-pass audit: bare "eof-zero-progress-cycle" is a diagnostic
  # CODE and was measured matching "eof-terminal chains through a pause
  # continuation" and "a pause's byte-reachability gate is not checked
  # (eof-terminal chain)", each of which reddens a pause case labelled with
  # the same code. Anchored to the pre-pause eof-cycle case's own "has
  # eof-zero-progress-cycle" check, parentheses escaped. (eof-terminal's
  # cycle-detection guard is shared code, so this mutant's own captured
  # output ALSO contains BOTH of this task's new arm-5 sequence fixtures'
  # records; that reverse direction is genuine and documented beside arm 5's
  # own pin below.)
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "an eof-target cycle is rejected \\(eof-zero-progress-cycle\\): has eof-zero-progress-cycle")

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
  # Slice ③ moved this off the bare "missing-target" code onto the pause
  # case's own "missing-target diagnostic" label. Task 3's whole-pass audit
  # (done on main, without this branch's sequence node) measured that label
  # still colliding with "a missing transition target is not reported":
  # suppressing the missing-target DIAGNOSTIC and dropping the pause
  # continuation from the list of things checked for resolution redden the
  # same case with the same two records, byte for byte. Nothing on this
  # mutation's resolution half could separate them -- both halves of that case
  # were shared.
  #
  # Fixed on the mutation's OTHER half instead. The label names two decisions
  # ("resolution + reachability") and only the resolution one was pinned; the
  # reachability one is this mutation's alone, because node-out-targets' pause
  # arm is what keeps a pause's continuation on the reachability walk.
  # "a well-formed pause machine verifies" now asserts that fixture emits no
  # 'unreachable-node (attribution, not the "accepted" verdict three mutants
  # shared), and this mutant is the only one of the 27 that fails it.
  #
  # Merge integration (M3 Slice ② vs main #32): main's FIND assumed the
  # pause-node? arm was immediately followed by `(else '())`. This branch's
  # Task 1 pin sweep had already re-anchored that adjacency, because
  # node-out-targets grew a new sequence-dispatch-node? cond clause between
  # the pause-node? arm and its `(else '())` -- so main's two-line FIND does
  # not occur in the merged src/byte-machine/verify.sls (confirmed: 0
  # occurrences) and the REPLACE below keeps this branch's anchor, on the
  # arm's own preceding comment line, which no other cond clause in this file
  # shares. Only the EXPECT_OUTPUT_MATCHES pin -- main's attribution check,
  # which is what let main's audit close this collision at all -- moved over
  # from main's side.
  #
  # *** Re-anchored a THIRD time, 2026-09-03, and this time OFF the prose. ***
  # The anchor above was the arm's preceding COMMENT line, chosen because the
  # bare pause arm occurs three times in this file. That comment stated a reason
  # that had gone stale -- it named one predicate where the §16.2:908 filter now
  # names three -- and correcting it broke this FIND (0 occurrences, the suite
  # hard-failed at declaration). An anchor on prose breaks every time the prose
  # is corrected, which is the opposite of what an anchor is for.
  #
  # The anchor is now the pause arm plus the FOLLOWING clause's first comment
  # line: measured unique (1 occurrence, against 3 for the bare arm), code-side,
  # and insensitive to edits of the paragraph above it -- which is the paragraph
  # that keeps needing them.
  # Re-anchored at Slice ⓪b task 5: node-out-targets is now a derived view of
  # node-out-edges, whose arms yield (role . target) pairs.
  FIND [[          ((pause-node? n) (zero-width-edges n))]]
  REPLACE [[          ((pause-node? n) '())]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "a well-formed pause machine verifies: no unreachable-node")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: eof-terminal chains through a pause continuation"
  # Slice ③ anchored this on the pa->pb->pa case; Task 3's whole-pass audit
  # measured that anchor still matching "an eof-target cycle is classified as
  # a finish terminal", and found the reason is structural, not a bad choice
  # of anchor. eof-terminal's pause arm returning 'finish suppresses a
  # diagnostic only where the walk PAST the pause would have found a stop
  # ('eof-reachable-stop) or a cycle ('cycle) -- and every fixture in this
  # file reaches exactly one of those, so each one is also broken by the
  # mutation that kills that one classification. Not a subset either way, but
  # no single record was this mutant's own: category (2), separable, and here
  # NOT declined.
  #
  # Closed by putting both terminal kinds in ONE machine and counting them:
  # "an EOF walk crosses a pause for both terminal kinds (§16.2:909)" expects
  # 2, and the three edits report three different numbers -- 0 here (the walk
  # stops at the pause, so neither is found), 1 for losing stop
  # classification, 1 for losing cycle classification. Measured: "got 0" on
  # that check is this mutation's alone among the 27.
  # RE-ANCHORED by Slice ② task 2: the pause arm moved out of eof-terminal's
  # own cond into `eof-successors`, which is where every multi-successor kind's
  # continuation set is now computed. A pause contributes exactly one successor,
  # which is what this mutation removes.
  FIND [[    (cond ((pause-node? n) (list (cons 'continuation (pause-node-continuation n))))]]
  REPLACE [[    (cond ((pause-node? n) '())]]
  EXPECT_STATUS 1
  # Re-measured at Slice ⓪b task 6. This mutant used to report "expected 2, got
  # 0" because an empty zero-width join answered `'unresolved`; that arm is now a
  # loud raise, so the same mutation is caught at the same site by the raise the
  # arm exists to make. AGENTS.md prefers a comparison to a raise because a raise
  # usually depends on where the mutant happens to crash -- here it crashes at
  # exactly the decision's own site, which is the case that preference exempts.
  EXPECT_OUTPUT_MATCHES "case raised -- Exception in eof-terminal: empty zero-width join")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: pause continuations join the zero-progress walk"
  # Later review: bare "zero-progress-cycle" is a substring of three other
  # check labels in this file (the pre-Slice-3 mutation above reuses it, and
  # "eof-zero-progress-cycle diagnostic"/"zero-progress-cycle diagnostic" are
  # each a distinct decision), so it does not by itself prove which one
  # failed. Measured: this mutation's own primary witness is the reexecute/
  # pause-only cycle case; pinned to it.
  #
  # Re-anchored in M3 Slice ② Task 1: reexec-targets grew a new
  # sequence-dispatch-node? cond clause between the pause-node? arm and its
  # `(else '())`, so the old two-line adjacency stopped matching (0
  # occurrences, SITES=1 asserted exactly). Anchored to the arm's own
  # preceding comment line, unique to this site (node-out-targets' pause
  # comment above reads differently).
  #
  # Merge integration (M3 Slice ② vs main #32): main's FIND assumed the same
  # stale pause-node?-then-else adjacency as the node-out-targets mutation
  # above, and it does not occur in the merged tree either (0 occurrences,
  # confirmed the same way), so this branch's re-anchored FIND/REPLACE is
  # kept. Main's SUBSUMED RESIDUE finding carries over unchanged, since it
  # concerns a different mutation's (broader) effect, not this pin's own
  # anchor: every FAIL record this mutant emits is also emitted by "verify:
  # zero-progress detection never fires". Dropping the pause arm from PASS
  # 5's reexec-targets can only REMOVE zero-progress-cycle diagnostics, and
  # that mutation removes all of them, so this mutant's failure set is a
  # strict subset.
  #
  # Re-measured at 34 mutations (Milestone 3 Slice ② re-measurement
  # obligation): main's own count -- "3 records of that one's 4" -- is now
  # stale, not wrong when written. This branch's arm 3 gave "verify:
  # zero-progress detection never fires" a fifth record (the sequence node's
  # reexecute-mismatch cycle entered from a byte-dispatch node, see arm 3's
  # own pin below), so the subset is now 3 of 5, and this mutant lacks TWO
  # records, not one: the pure byte-dispatch self-loop (main's original
  # finding) and arm 3's new sequence-mismatch-edge cycle, neither of which
  # needs a pause arm to be found. Re-swept over all 34 mutations, not just
  # the two named here: still a clean subset both before and after this
  # comment's count correction. Left pinned to the check that states this
  # decision.
  FIND [[((pause-node? n) (list (pause-node-continuation n)))]]
  REPLACE [[((pause-node? n) '())]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "cycle with no advance makes no progress: zero-progress-cycle diagnostic")

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
  #
  # SUBSUMED RESIDUE, twice over, and no pin can close either: this mutant's
  # single FAIL record is also emitted by "verify: zero-progress detection
  # never fires" and by "verify: pause continuations join the zero-progress
  # walk". The three edits are nested by construction -- narrowing PASS 5's
  # FILTER back to byte-dispatch nodes stops pause nodes being flagged;
  # narrowing its WALK (the mutation above) stops pause nodes AND the dispatch
  # nodes whose cycle runs through one; disabling the check stops everything.
  # Each removes a superset of the last, so there is no record the narrowest
  # of them owns. Measured by exhaustion over the whole pass.
  #
  # Re-swept at 34 mutations post-merge (2e5a1ab), review fix wave: still a
  # single FAIL record, still a full-set subset of both "verify: zero-progress
  # detection never fires" and "verify: pause continuations join the
  # zero-progress walk" -- re-run against all 34 mutants' captured output
  # (including the three new count-not-witness fixtures this task added),
  # with no change to this record either before or after.
  #
  # Re-anchored by Milestone 3 Slice ③ Task 2, FIND *and* REPLACE. The guard
  # gained a `(sequence-dispatch-node? n)` disjunct (§25:1533), and the shipped
  # REPLACE -- which named byte-dispatch alone -- would now drop the sequence
  # clause as well as the pause one, making this a second copy of "verify: a
  # self-targeting sequence node is not reported as a zero-progress cycle
  # (§25:1533)" below and destroying both pins' uniqueness. Narrowed to drop
  # only the pause clause, which is what this LABEL claims; the paragraph
  # above says "back to byte-dispatch nodes" because that was the whole filter
  # when it was written, and the kinds this edit now leaves in are
  # byte-dispatch AND sequence. The nesting it records is unchanged -- this
  # edit still removes a strict subset of what the WALK mutation removes.
  # Re-swept whole at 41 mutations: still exactly ONE FAIL record, its own
  # pinned EOF-pause one, still a full-set subset of both siblings named above
  # and owning nothing unique lane-wide, and the zero-progress-cycle count
  # case still reports 3 -- so this mutant does not reach the four-way check
  # the new mutation below is pinned to.
  #
  # OPEN OBLIGATION, whole-branch review fix wave (2026-08-30). Amending the
  # two paragraphs above rather than rewording them: "no pin can close either"
  # and "there is no record the narrowest of them owns" state a conclusion the
  # measurement does not support. Under the taxonomy 49c8cc4 put in AGENTS.md,
  # a mutant owning ZERO unique FAIL records lane-wide is a signal that this
  # SPEC is under-specified -- verify-tests.sps has no case on which dropping
  # the pause clause of PASS 5's report guard produces a number, or a
  # diagnostic set, that dropping the walk or the whole check does not -- and
  # a subsumption claim may only be made about what survived an actual
  # separating attempt, recorded with its measurement. NO SUCH ATTEMPT HAS
  # BEEN MADE, here or in any earlier cycle: every re-sweep above re-ran the
  # exhaustion test and none tried to add a separating check. This is
  # therefore recorded as an open specification gap against THIS LABEL, not as
  # a closed residue.
  #
  # Where an attempt would start, for whoever takes it. The likely remedy is
  # count-don't-witness, the one this pass already uses two mutations below,
  # and the ONE thing measured about it here is negative: the existing
  # three-cycle case cannot serve, because it contains no pause cycle at all,
  # which is why this mutant leaves it at the correct 3 (measured at 42
  # mutations, recorded above). A fixture that counted a pause cycle beside
  # the sequence ones would have to separate this edit from BOTH siblings, and
  # the second is the harder half: dropping the pause clause of the REPORT
  # guard and narrowing the WALK's pause arm remove overlapping sets of
  # reported nodes, so a fixture holding only self-cycles will not tell them
  # apart -- it needs a cycle that runs THROUGH a pause without being one,
  # which the walk mutation kills and this one does not. No arithmetic for any
  # candidate fixture is asserted here, because none has been run; that is
  # precisely the attempt still owed. It is a design task carrying its own new
  # fixture rather than a re-anchoring, and the whole-branch review scoped it
  # out of this fix wave deliberately; the pin below is unchanged and still
  # catches its own mutant.
  # Re-anchored AGAIN by Slice ② task 3's census, FIND and REPLACE, same reflow
  # as the two sibling pins: the guard gained the two zero-width kinds. The edit
  # this LABEL claims is unchanged -- drop only the pause clause -- and so is the
  # nesting it records.
  FIND [[(and (memq (node-name n) br898)
                                     (or (byte-dispatch-node? n) (pause-node? n)
                                         (sequence-dispatch-node? n)
                                         (keyword-table-node? n)
                                         (field-action-node? n) (field-branch-node? n)
                                         (integer-accumulate-node? n)
                                         (callback-node? n)
                                         (span-start-node? n) (span-end-node? n)
                                         (counted-consume-node? n))
                                     (self-cycle (node-name n)))]]
  REPLACE [[(and (or (byte-dispatch-node? n)
                                         (sequence-dispatch-node? n)
                                         (keyword-table-node? n)
                                         (field-action-node? n) (field-branch-node? n)
                                         (integer-accumulate-node? n)
                                         (callback-node? n)
                                         (span-start-node? n) (span-end-node? n)
                                         (counted-consume-node? n))
                                     (self-cycle (node-name n)))]]
    # Re-pinned by Milestone 5 Slice ③. Its witness was an EOF-ONLY pause cycle,
  # which §16.2:898's new gate (decision 0027 item 3) excludes on purpose -- so
  # the clause is now witnessed by a BYTE-reachable pause cycle, which is what a
  # check about byte reachability should always have used. The edit this LABEL
  # names is unchanged.
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "a BYTE-reachable pause cycle is still a zero-progress cycle")

# Milestone 3 Slice ② Task 1: the sixth node kind, sequence-dispatch, at all
# seven of verify.sls's permissive fall-throughs (§0 D2). Adds seven mutations
# to this same Pass 33 rather than opening a new one -- one per arm, since a
# silently-clean verifier is the hazard this task closes and each arm needs
# its own witness that reddens when it is removed. Every FIND/REPLACE and
# EXPECT_OUTPUT_MATCHES below is measured against this file's own tree (a
# scratch copy, mutated, run through chez-source.ss directly), never
# predicted. Passes stay at 41; mutations become 186 + 7 = 193.
#
# Arms 5 and 7 both touch pass-eof-execution's :909 machinery and, measured
# together, turned out to share one FAIL record: the self-loop fixture
# ("an eof chain that cycles through a sequence node is an EOF cycle") is
# broken by EITHER removing eof-terminal's sequence-dispatch-node? branch
# (arm 5) or removing the OUTER filter's sequence-dispatch-node? disjunct
# (arm 7) -- with 'seq excluded from the outer map, eof-terminal is never
# even called starting from it, so arm 5's own inner branch is moot and the
# two mutants' captured output for that one case is byte-identical. A second
# fixture below -- a genuine two-node cycle entered from a BYTE-DISPATCH
# node, whose own eof-target check the outer filter never gates on
# sequence-dispatch-node? -- separates them: arm 5's mutant still fails it
# (the walk reads 'unknown at the sequence node and the cycle is never
# closed) while arm 7's mutant leaves it green (the byte-dispatch entry's own
# check still finds the cycle independently of whether the sequence node is
# ALSO iterated by the outer filter). Each arm below is pinned to the one
# fixture that is not also broken by its sibling.
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a sequence node's case and mismatch targets are not out-targets (arm 1, node-out-targets)"
  # Re-anchored by Slice ② task 3: the arm no longer abuts `(else '())`, because
  # the two zero-width kinds' arms were added between them. Anchored on the arm
  # itself now, which is what the LABEL names, rather than on its neighbour.
  # Re-anchored at Slice ⓪b task 5: node-out-targets is now a derived view of
  # node-out-edges, whose arms yield (role . target) pairs.
  FIND [[          ((sequence-dispatch-node? n)
           (append (map (lambda (c) (cons 'alternative (sequence-case-target c)))
                        (sequence-dispatch-node-cases n))
                   (list (cons 'mismatch
                               (edge-target (sequence-dispatch-node-mismatch n))))))]]
  REPLACE [[          ((sequence-dispatch-node? n) '())]]
  # Comparison-caught: with the arm removed, the well-formed fixture's
  # sequence case and mismatch edge targets ('stop and 'reject) are never fed
  # to node-out-targets, so pass-reachability treats both as unreached and the
  # well-formed control's own diagnostic-count check goes from 0 to 2 -- the
  # case this mutation is pinned to below. Measured: this mutant also breaks
  # four OTHER cases (the case-target case, the mismatch-target sibling, arm
  # 2's reachability case, and arm 6's non-eof-into-finish case), since
  # node-out-targets feeds all of them.
  #
  # Fix wave 1 (Important 1): the bare-missing-target pin above was declared
  # "genuinely subsumed" by the pre-existing "verify: a missing transition
  # target is not reported" mutation, but that mutation's own measured output
  # (fallback missing-target, both pause-malformed checks, plus this mutant's
  # OWN case-target and mismatch-target FAIL lines) is not a superset of this
  # mutant's five-case failure set: it lacks the well-formed control, arm 2's
  # reachability case, and arm 6's non-eof-into-finish case, none of which
  # deleting pass-names' missing-target diagnostic construction can produce (a
  # clean control has no missing target to report; arm 2/6 are different
  # passes). The two failure sets only partially overlap -- neither is a
  # subset of the other -- so this was under-anchored, not subsumed: a pin
  # unique to this mutant existed and was measured. Re-anchored to the
  # well-formed control's own diagnostic-count line, which this mutant is the
  # only one in this pass to produce (checked against every other declared
  # pin's captured output, both directions, including the "missing transition
  # target" mutation above): under this mutant, `'stop` and `'reject` (the
  # sequence case's and mismatch edge's targets) go unreachable, so
  # pass-reachability adds two `unreachable-node` diagnostics where the
  # well-formed fixture expects none.
  #
  # Review fix wave (Critical), re-measured at 34 mutations: arm 6's own
  # subsumption by this mutation (mentioned in passing above) is now the
  # SURVIVING half of a two-sided residue -- arm 6's own count fixture
  # separated it from "verify: a byte edge into a finish terminal is
  # accepted" but not from this mutation, confirmed genuinely subsumed by
  # exhaustion at this size. See arm 6's own pin below for the measurement.
  #
  # Re-anchored 2026-09-02, Milestone 4 Slice ①a task 8's whole-pass sweep. The
  # note above records this pin as "checked against every other declared pin's
  # captured output, both directions" -- at 34 mutations. A pin is only ever
  # verified against the mutants that existed when it was measured, and Slice
  # ①a's "the reason repertoire rejects every reason" now reproduces that count
  # coincidentally: rejecting every reason adds one invalid-name diagnostic per
  # declaration, and the well-formed sequence fixture declares two, so it lands
  # on the identical `expected 0, got 2`. Two mutants, one count, no
  # discrimination.
  #
  # Re-anchored onto this mutant's ONE record that no other Pass 33 mutant
  # produces, computed as a set difference against all 43 others rather than
  # against a suspected sibling: the first attempt moved it to the case-target
  # check, which is unique against the reason mutation but collides with
  # "a missing transition target is not reported" -- the very residue the note
  # above records this pin being moved away from. Measured at 44 mutations,
  # 1892 ordered pairs.
  #
  # A count is a weaker anchor than a named check for exactly the reason this
  # sweep found: another mutant can reach the same number by another route.
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a node reached only through the sequence eof-target is reachable: no unreachable-node -- expected 0, got 2")

# RE-ANCHORED, NOT RETIRED, by Milestone 7 Slice ⓪ (decision 0031) — and the
# first draft of this slice DID retire it, on a reason the whole-branch review
# measured false.
#
# The plan said the decision this mutation names — a sequence node's eof-target
# feeds the reachability walk — was subsumed by the new "reachability is the
# occupiable relation" group's sequence-dispatch pair. It is not. In that pair
# `T`'s own eof-target is the error node, which is already byte-reached, so the
# walk's answer is identical with or without `node-eof-target`'s sequence arm;
# what the pair witnesses is that the walk does not take `T`'s BYTE edge.
# Measured over the whole pass: with this block deleted, the shipped case
# "a node reached only through the sequence eof-target is reachable" was still
# reddened by two mutants — "a sequence node's case and mismatch targets are not
# out-targets (arm 1)" and "node-out-targets returns the roles instead of the
# targets" — and BOTH name the byte half, each emitting `got 2` where this one
# emits `got 1`. The decision was RELOCATED by 0031, not subsumed: `eof-step` is
# what reads `node-eof-target` for the walk now, so the mutation moves there.
# AGENTS.md: before deleting a mutation, ask what its REPLACE still changes in
# the surviving tree and whether any input can reach it.

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a sequence node's eof-target does not feed reachability (arm 2, eof-step)"
  # Originally anchored on `all-out-targets`' definition and re-anchored twice
  # since: in Fix wave 1 onto the shared `node-eof-target` helper's call site,
  # and by Milestone 7 Slice ⓪ onto `eof-step`, which decision 0031 made the one
  # reader of that helper for the reachability and pass-7 walks. The REPLACE
  # reproduces the old byte-dispatch-only behaviour by gating the contribution,
  # not by narrowing the helper — so the mutant differs from the baseline in
  # exactly one thing, which kind's EOF route the walk follows.
  FIND [[  (define (eof-step n)
    (let ((t (node-eof-target n)))
      (append (if (symbol? t) (list t) '()) (eof-successors n))))]]
  REPLACE [[  (define (eof-step n)
    (let ((t (node-eof-target n)))
      (append (if (and (byte-dispatch-node? n) (symbol? t)) (list t) '())
              (eof-successors n))))]]
  EXPECT_STATUS 1
  # Comparison-caught, and the record is UNIQUE across the pass: this mutant
  # emits `got 1` on that case where the two mutants naming the BYTE half emit
  # `got 2`, which is exactly the separation the pre-0031 anchoring had. It also
  # reddens three cases whose kinds lose their EOF route for the same reason
  # (two accumulate, one counted) -- the decision reaches them, so this is a
  # discrimination and not a crash.
  EXPECT_OUTPUT_MATCHES
    "sequence dispatch reaches every verifier arm.a node reached only through the sequence eof-target is reachable: no unreachable-node -- expected 0, got 1")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a sequence node's reexecute mismatch edge is invisible to the zero-progress walk (arm 3, reexec-targets)"
  # Re-anchored by Slice ② task 3: this arm no longer abuts `(else '())`, since
  # the zero-width kinds' arm was added between them. Anchored on the arm itself.
  FIND [[              ((sequence-dispatch-node? n)
               (if (eq? (edge-mode (sequence-dispatch-node-mismatch n)) 'reexecute)
                   (list (edge-target (sequence-dispatch-node-mismatch n))) '()))
]]
  REPLACE [[              ]]
  # Comparison-caught: with the arm removed, reexec-targets no longer sees
  # through the sequence node, so the dispatch node's own reexecute-only
  # cycle through it goes undetected and zero-progress-cycle never fires.
  # Measured: a clean, single-case witness against every OTHER mutation in
  # this pass except one.
  #
  # Pin sweep (Step 12): this pin's own FAIL record is also produced,
  # byte-identical, by the pre-existing "verify: zero-progress detection
  # never fires" mutation (which disables pass-zero-progress's report
  # conditional outright). Filed genuinely subsumed here and left collided.
  #
  # Review fix wave (Critical), re-measured at 34 mutations: a whole-FAIL-
  # record subset test alone reports AGENTS.md's bucket 3 ("separable but
  # deliberately declined") as clean too, and that is what happened above --
  # the collision was separable, just not by any check this pass had before
  # this task. verify-tests.sps's "a byte-dispatch self-loop and a
  # sequence-mismatch cycle are two zero-progress cycles" case puts an
  # INDEPENDENT plain self-loop (a decision only "zero-progress detection
  # never fires" touches, never this mutation) beside the sequence-mismatch
  # cycle this mutation's own case above already witnesses by existence, and
  # counts both. Measured directly against all 34 mutants' captured output,
  # not predicted: correct code reports 2; "zero-progress detection never
  # fires" disables PASS 5 outright and reports 0 on this check; this
  # mutation still finds the plain self-loop but can no longer walk through
  # the sequence node, reporting 1 -- a "got" value no other of the 34
  # mutants in this pass produces on this check. UNDER-ANCHORED, not
  # subsumed: re-anchored to that record, which "zero-progress detection
  # never fires" own captured output does not match (it has "got 0" there).
  #
  # Re-anchored by Milestone 3 Slice ③ Task 2: extending PASS 5's REPORT set to
  # the sixth kind adds 'seq itself to this case's count, so the correct value
  # moved 2 -> 3 and the case was renamed to say what it now counts -- from
  # "a byte-dispatch self-loop and a sequence-mismatch cycle are two
  # zero-progress cycles" to "a byte-dispatch self-loop, a
  # dispatch-through-sequence cycle and the sequence node itself are three
  # zero-progress cycles", which is the live name and the one the pin below
  # quotes. The retired name matches no harness-case in verify-tests.sps; its
  # only other appearance anywhere in the tree is in Slice ③'s implementation
  # plan, as that plan's own record of the pin before the rename (searched
  # whitespace-normalised as well as line-wise, since a name this long wraps).
  # So the paragraph above naming it is a record of what was measured, not a
  # lookup key. The pin's "got 1" is unchanged and was re-measured, not assumed: with the arm
  # removed, 'x's plain self-loop is still found, 'start no longer reaches
  # itself, and 'seq is not reported -- 1. The check is now four-way
  # (3 / 2 / 1 / 0); see the case's own comment for the table.
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "and the sequence node itself are three zero-progress cycles: zero-progress-cycle count -- expected 3, got 1")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the sequence mismatch edge's MODE is not tested (arm 3, reexec-targets)"
  # Added by the whole-branch review fix wave (Important 3). Arm 3's mutation
  # above deletes the WHOLE arm, so it never tests the arm's own `if`: whether
  # a sequence node's mismatch target joins the zero-progress walk is
  # conditional on the edge's MODE, and that condition is what keeps an
  # ADVANCE-mode self-target accepted -- an advance edge consumes the
  # mismatching byte, so the cycle makes progress. The design's exit-criterion
  # :1540 disposition asserts that verify-tests.sps's advance case "is what
  # stops the report guard from being widened past the mismatch edge's mode",
  # and this case's own comment said the same; until this mutation, nothing
  # measured either claim.
  # `(if #t` rather than `(if #f`, per AGENTS.md's opposite-constant rule:
  # `(if #f` reproduces arm 3's own deletion and would be a second copy of it,
  # while `(if #t` makes self-cycle report the advance fixture and is
  # caught by a failed comparison on a case that passes in the baseline.
  #
  # MEASURED, not predicted. Baseline cases=57 checks=77 failures=0 status=0;
  # this mutant cases=57 failed-cases=1 checks=77 failures=3 status=1, all
  # three failures on the advance case and nothing else.
  #
  # The pin is the attribution check, and the first pin tried was wrong. The
  # obvious anchor -- "diagnostic count -- expected 0, got 1" -- was measured
  # UNDER-ANCHORED at 42 mutations: "a sequence node's case and mismatch
  # targets are not out-targets (arm 1, node-out-targets)" reddens the same
  # two checks with an unreachable-node on 'stop, and "a sequence alternative
  # is compared against itself" with an ambiguous-sequence-prefix, so a count
  # of 1 is reached three ways and this mutant owned NO unique FAIL record.
  # AGENTS.md's remedy for that signal is an attribution check, so the advance
  # case gained "no zero-progress-cycle" (see its own comment for the table of
  # three diagnostics). Re-measured after the check landed: this mutant emits
  # three FAIL records, exactly one of which is unique lane-wide, and this pin
  # names it. It carries the case-name tail as well as the check label because
  # the bare string "zero-progress-cycle" is a substring of nine other check
  # labels and one case name in verify-tests.sps (measured over its `check`,
  # `check-equal`, `harness-case` and `harness-group` labels, excluding this
  # mutation's own "no zero-progress-cycle"); no regex metacharacter appears
  # in the pin.
  FIND [[(if (eq? (edge-mode (sequence-dispatch-node-mismatch n)) 'reexecute)]]
  REPLACE [[(if #t]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "advance mismatch edge is a consuming cycle and passes: no zero-progress-cycle")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a self-targeting sequence node is not reported as a zero-progress cycle (§25:1533)"
  # The REPORT set, not the walk: arm 3 above mutates reexec-targets and lands
  # on "got 1", "zero-progress detection never fires" lands on "got 0", and
  # this one lands on "got 2" -- three distinct values on one check, all
  # measured, none predicted. Comparison-caught: the count check fails outright
  # rather than depending on where a mutant happens to crash.
  # RE-ANCHORED by Slice ② task 2's census, same reflow as the sibling pin.
  FIND [[(and (memq (node-name n) br898)
                                     (or (byte-dispatch-node? n) (pause-node? n)
                                         (sequence-dispatch-node? n)
                                         (keyword-table-node? n)
                                         (field-action-node? n) (field-branch-node? n)
                                         (integer-accumulate-node? n)
                                         (callback-node? n)
                                         (span-start-node? n) (span-end-node? n)
                                         (counted-consume-node? n))]]
  REPLACE [[(and (memq (node-name n) br898)
                                     (or (byte-dispatch-node? n) (pause-node? n)
                                         (keyword-table-node? n)
                                         (field-action-node? n) (field-branch-node? n)
                                         (integer-accumulate-node? n)
                                         (callback-node? n)
                                         (span-start-node? n) (span-end-node? n)
                                         (counted-consume-node? n))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "and the sequence node itself are three zero-progress cycles: zero-progress-cycle count -- expected 3, got 2")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a sequence node's eof-target is not resolution-checked (arm 4, pass-eof)"
  # Re-anchored in Fix wave 1 (Important 3): pass-eof's own inline cond was
  # extracted into the shared node-eof-target helper (see arm 2 above); the
  # REPLACE reproduces byte-dispatch-only behaviour by gating the call.
  FIND [[              (map (lambda (n)
                     (let ((t (node-eof-target n)))
                       (if (or (eq? t #f) (lookup nodes t)) '()
                           (list (make-diagnostic 'invalid-eof-target (node-name n)
                                                  "eof-target names no node")))))
                   nodes)))))]]
  REPLACE [[              (map (lambda (n)
                     (if (byte-dispatch-node? n)
                         (let ((t (node-eof-target n)))
                           (if (or (eq? t #f) (lookup nodes t)) '()
                               (list (make-diagnostic 'invalid-eof-target (node-name n)
                                                      "eof-target names no node"))))
                         '()))
                   nodes)))))]]
  # Comparison-caught: with the arm reverted to byte-dispatch-only, a
  # sequence node's dangling eof-target is never checked against the node
  # table, so invalid-eof-target never fires. Re-measured against the
  # refactored source: byte-identical output to the pre-refactor mutation, a
  # clean, single-case witness.
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a sequence eof-target that names no node is invalid-eof-target: invalid-eof-target")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: eof-terminal does not classify a sequence node reached mid-chain (arm 5)"
  # RE-ANCHORED by Slice ② task 2. The old FIND ended on `(else 'unknown)))))))`
  # -- the arm boundary -- and decision 0021 item 3 DELETED that residual, so the
  # anchor is gone with it. The replacement keeps the mutation
  # COMPARISON-caught, which the note below depends on: dropping the arm
  # entirely would now reach the raising `else` and kill the mutant by
  # assertion-violation instead of by the wrong classification this pin names.
  FIND [[                ((sequence-dispatch-node? n)
                 (dispatch-arm (sequence-dispatch-node-eof-target n) path))]]
  REPLACE [[                ((sequence-dispatch-node? n) (verdict 'default-error path))]]
  # Comparison-caught: with the arm removed, eof-terminal falls to its
  # `(else 'unknown)` the moment the walk reaches a sequence node, so a cycle
  # that must pass back OUT through that node's own eof-target is never
  # closed. Pinned to the two-node (byte-dispatch <-> sequence) fixture, not
  # the self-loop sibling above it: measured, this mutant's FAIL record for
  # the self-loop case is byte-identical to arm 7's mutant's (see the header
  # note), but this fixture is unaffected by arm 7's own mutation -- arm 7
  # only gates whether the OUTER pass-eof-execution walk starts an
  # eof-terminal call from a sequence node; here the walk is entered from the
  # byte-dispatch node's own (untouched) eof-target check, so only arm 5's
  # removal breaks it.
  #
  # Pin sweep (Step 12): this pin's own FAIL record is ALSO produced,
  # byte-identical, by the pre-existing "verify: an eof-target cycle is
  # classified as a finish terminal" mutation (which disables eof-terminal's
  # own `(memq name seen)` cycle guard outright -- a strictly broader
  # decision covering every eof-target chain's cycle detection, old and new;
  # that mutation's measured output contains BOTH of this case's sibling
  # fixtures). Filed genuinely subsumed here and left collided.
  #
  # Review fix wave (Critical), re-measured at 34 mutations: a whole-FAIL-
  # record subset test alone reports AGENTS.md's bucket 3 ("separable but
  # deliberately declined") as clean too. verify-tests.sps's "a byte-dispatch
  # eof self-loop and a two-node dispatch/sequence eof cycle are three
  # eof-zero-progress cycles" case puts an INDEPENDENT byte-dispatch eof
  # self-loop (a decision only "an eof-target cycle is classified as a
  # finish terminal" touches, never this mutation) beside the SAME two-node
  # dispatch/sequence cycle this mutation's own second case above already
  # witnesses by existence, and counts all eof-zero-progress-cycle
  # diagnostics. A design entirely local to the sequence node (a
  # self-referencing 'seq, matching this mutation's OWN first case and arm
  # 7's fixture) was tried first and rejected: measured, it does not
  # separate this mutation from arm 7 -- a walk that starts and ends at the
  # sequence node without ever passing through a byte-dispatch node is
  # killed identically by dropping eof-terminal's sequence clause (this
  # mutation) or by dropping the :909 outer filter's sequence disjunct
  # (arm 7), both reporting "got 1" on that design. The two-node pair avoids
  # this because it is entered from the byte-dispatch node's own eof-target,
  # which only this mutation's inner change touches -- arm 7's outer-filter
  # change is irrelevant to a chain that never STARTS at the sequence node.
  # Measured directly against all 34 mutants' captured output: correct code
  # reports 3; "an eof-target cycle is classified as a finish terminal"
  # disables the cycle guard globally and reports 0; this mutation still
  # finds the self-loop's own cycle but every walk through the sequence node
  # now returns 'unknown, reporting 1 -- a "got" value no other of the 34
  # mutants produces on this check (arm 7 reports 2, confirmed as a control).
  # UNDER-ANCHORED, not subsumed: re-anchored to that record, which "an
  # eof-target cycle is classified as a finish terminal"'s own captured
  # output does not match (it has "got 0" there).
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a byte-dispatch eof self-loop and a two-node dispatch/sequence eof cycle are three eof-zero-progress cycles: eof-zero-progress-cycle count -- expected 3, got 1")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the §16.2:894 sequence-ambiguity pass is never run"
  FIND [[                                  (pass-sequence-ambiguity machine)]]
  REPLACE [[                                  '()]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "both directions, counted over both declaration orders: ambiguity count over both orderings -- expected 6, got 0")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the terminal-prefix test is one-directional (§16.2:894)"
  # Comparison-caught. The pair test must ask BOTH directions: a caller may
  # declare the longer alternative first, and normal-ir-tests.sps's own
  # "reverse order" case exists because the trie has two distinct guard sites
  # for exactly this. Measured: the summed check goes 6 -> 3, a value no other
  # mutant in this pass produces on it. A per-ordering check would NOT separate
  # this mutation from "never run" -- its records would be a strict subset.
  FIND [[                                 (if (or (byte-prefix? (car as) (car others))
                                         (byte-prefix? (car others) (car as)))]]
  REPLACE [[                                 (if (byte-prefix? (car as) (car others))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "both directions, counted over both declaration orders: ambiguity count over both orderings -- expected 6, got 3")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the prefix relation degenerates to a first-byte test (§16.2:894)"
  # The OVER-rejection direction, which no other mutation in this pass reaches:
  # with the recursion collapsed, any two alternatives sharing a first byte are
  # called ambiguous, and every branching machine this milestone ships would be
  # refused. Measured: the well-formed AB/AC/XY fixture goes 0 -> 1.
  FIND [[((= (car a) (car b)) (byte-prefix? (cdr a) (cdr b)))]]
  REPLACE [[((= (car a) (car b)) #t)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "alternatives that merely share a prefix are not ambiguous: ambiguity count -- expected 0, got 1")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: only the first sequence alternative is compared against the others"
  # The sequence twin of pass-overlap's own "verify: only the first case is
  # compared against the others" -- cited by LABEL, not by line, because this
  # task's own edits to this file moved every one of the three (AGENTS.md: name
  # the mutation, not the line). Measured on the nested-family fixture: 4 -> 2.
  FIND [[(scan (cdr as)]]
  REPLACE [[(scan '()]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "every pair is enumerated once, across a nested family and a disjoint one: ambiguity count -- expected 4, got 2")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a sequence alternative's collisions after the first are dropped"
  # The twin of pass-overlap's "verify: a case's collisions after the first are
  # dropped". Measured: 4 -> 3. Note this and the mutation above are
  # indistinguishable on the summed check (both 4) and on either per-ordering
  # count (both 2); only the nested-family fixture, which makes the two walks
  # visit different pair sets, separates them.
  FIND [[(against (cdr others)]]
  REPLACE [[(against '()]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "every pair is enumerated once, across a nested family and a disjoint one: ambiguity count -- expected 4, got 3")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a sequence alternative is compared against itself"
  # The twin of pass-overlap's "verify: a case is compared against itself".
  # Every alternative is a terminal prefix of itself, so self-comparison adds
  # exactly one spurious diagnostic per alternative. Measured: 4 -> 9 on a
  # five-alternative fixture.
  FIND [[(let against ((others (cdr as)) (found found))]]
  REPLACE [[(let against ((others as) (found found))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "every pair is enumerated once, across a nested family and a disjoint one: ambiguity count -- expected 4, got 9")

# Slice ①b Task 4 adds THREE mutations to Pass 33 for pass-fields, the
# declaration half of §16.3:924 item 6. Two permissive, one per check, and one
# restrictive on the portable-name check -- the direction that makes the pass's
# clean-premise case load-bearing rather than decorative.
#
# *** CORRECTED by this slice's whole-branch review. Two mutations were declined
# here as "SUBSUMED"; NEITHER is subsumed, and the stated measurement for one of
# them was false. Both are written below. The original text and what was wrong
# with it, because the error is more instructive than the fix: ***
#
#   * "Dropping `(pass-fields machine)` from verify-machine's append. Its record
#     set is exactly the UNION of the two permissive mutants' below, so it owns
#     no record of its own." The premise is right and the CONCLUSION does not
#     follow. AGENTS.md's relation is "is my whole record set inside ONE
#     sibling's?" -- a union is contained in NEITHER of the two sets it unions,
#     so this is separable, and the tree already ships the remedy as the :909
#     conjunction pin. A mutation whose records are each shared with a DIFFERENT
#     sibling is the exact case AGENTS.md calls out as wrongly documented before.
#   * "The duplicate check made restrictive ... reports every field twice and
#     reddens twenty-odd records across five unrelated groups." FALSE as
#     measured: three records, all in ONE group. That description was true of an
#     earlier TWO-field clean fixture; a third field was added to that fixture
#     later in the same task, to separate a different pin, and this paragraph was
#     never re-measured against it. Neither set contains the other -- this mutant
#     emits `nonportable ... got 2`, which the restrictive-portable mutant does
#     not, and that one emits `two fields ... got 3`, which this one does not.
#
# The reusable lesson is not about fields. A measurement written against a
# fixture goes stale when the fixture changes, and nothing in this suite checks
# prose. Both pins below are CONJUNCTIONS, because each mutant's individual
# records are shared with a sibling and only the pair is unique.

# The whole-branch review found BOTH field diagnostics' "carries the offending
# field name" decision (§0 D2, and verify.sls's own comment) stated everywhere
# and asserted nowhere: verify-tests.sps read diagnostics through a `codes`
# helper that maps diagnostic-code, which is blind to the `node` slot. A
# `nodes-of` helper and two cases were added; these are their mutations.

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the duplicate-field diagnostic does not name the field"
  FIND [[(make-diagnostic/declarations 'invalid-field-declaration fname]]
  REPLACE [[(make-diagnostic/declarations 'invalid-field-declaration #f]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the duplicate diagnostic names the offending FIELD: the field name -- expected \\(count\\), got \\(#f\\)")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the nonportable-field diagnostic does not name the field"
  FIND [[(make-diagnostic/declarations 'invalid-field-declaration (uint-field-name f)]]
  REPLACE [[(make-diagnostic/declarations 'invalid-field-declaration #f]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the nonportable diagnostic names the offending FIELD: the field name -- expected \\(Count\\), got \\(#f\\)")

# Slice ② task 2 adds FOUR pinned and ONE survivor for the multi-successor
# eof-terminal rewrite (§4.4, decision 0021). Every one of them needs a kind with
# more than one successor, which is why tasks 1 and 2 are swapped relative to the
# plan: written against shipped kinds, all five would have been unwitnessable.

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: sibling EOF answers take the first arm instead of the max"
  # *** This is the UNION mutant: taking the first arm means neither a branch's
  # false target nor an action's error target is walked, so its record set is
  # exactly the union of the two arm mutations below and is contained in
  # NEITHER. *** AGENTS.md's relation is "inside ONE sibling's", so it is
  # separable, and the conjunction is what separates it -- one record from each
  # arm, which no single-arm mutant can produce together.
  FIND [[                      (if acc (eof-verdict-join acc v) v))))))]]
  REPLACE [[                      (if acc acc v))))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "one arm cycling is a cycle even though the other finishes: cycle -- expected a true value.*a field action's error target is walked too: reachable stop -- expected a true value")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a field branch's false target is not an EOF successor"
  # SUBSUMED BY the union mutant above, by construction -- taking the first arm
  # does everything this does and more. Kept because it names its own decision.
  # Anchored in `zero-width-successors`, the single definition all three
  # consumers share -- factored in task 3 when the triplicated arms took every
  # pin on them to SITES 3.
  FIND [[          ((field-branch-node? n)
           (list (cons 'true (field-branch-node-true-target n))
                 (cons 'false (field-branch-node-false-target n))))]]
  REPLACE [[          ((field-branch-node? n)
           (list (cons 'true (field-branch-node-true-target n))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "one arm cycling is a cycle even though the other finishes: cycle -- expected a true value")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a field action's error target is not an EOF successor"
  # The other half of the union, and the reason a field ACTION is multi-successor
  # too: a walk following only `next` misses a stop sitting behind a failure.
  FIND [[                 (list (cons 'next (field-action-node-next n)) (cons 'error e))
                 (list (cons 'next (field-action-node-next n))))))]]
  REPLACE [[                 (list (cons 'next (field-action-node-next n)))
                 (list (cons 'next (field-action-node-next n))))))]]
  EXPECT_STATUS 1
  # A CONJUNCTION, tightened by task 4's whole-pass sweep. Extracting
  # `zero-width-successors` made this arm feed THREE consumers, so each of its
  # records is shared with a mutant of one consumer: the EOF record with
  # "sibling EOF answers take the first arm", the reachability record with "a
  # zero-width node's targets are not out-targets". Only the pair is this
  # mutation's own.
  EXPECT_OUTPUT_MATCHES
    "a field action's error target is walked too: reachable stop -- expected a true value.*a zero-width node's targets are out-targets, so they are reachable: nothing unreachable")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: cycle no longer outranks eof-reachable-stop in the join"
  # The ONE relation decision 0021 item 1 pins in the source: a cycle is the
  # non-termination neither runtime loop guards against, so it must survive a
  # join. Pinned on the MIRRORED arm order, which is the record that separates it
  # from "the false target is not walked" -- a mutant that walks only the true
  # arm answers this fixture correctly and the other one wrongly.
  # Re-anchored at Slice ⓪b task 6: the flat six-element ranking became three
  # tiers, so the decision this pins -- `cycle` outranking `eof-reachable-stop` --
  # is now a tier assignment. Swapping the two tiers is the same decision
  # inverted, in one token rather than two list positions.
  FIND [[      (eof-reachable-stop)
      (cycle)))]]
  REPLACE [[      (cycle)
      (eof-reachable-stop)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "cycle outranks eof-reachable-stop in the OTHER arm order too: cycle -- expected a true value")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the EOF walk keeps no completed-set"
  FIND [[              ((assq name done) => cdr)
]]
  REPLACE [[              ]]
  EXPECT_SURVIVES
    "measured, not assumed: this mutant passes the whole verify lane unchanged. The completed-set is decision 0021 item 2's SECOND structure and its job is complexity, not correctness -- the path stack alone already answers every verdict correctly, because the only path-dependent answer is `cycle` and a re-visit off the current path re-derives the same verdict rather than a different one. What the set buys is that a diamond costs one visit instead of two, and a chain of k diamonds costs k instead of 2^k, which is exactly the defect 0021 item 2 names in the algorithm it rejects. No assertion over verdicts can see a difference, because there is none. A TIMING witness was considered and declined: a chain of ~25 branch nodes makes the mutant take 2^25 walks and blow the lane's TIMEOUT, but a catch that depends on how fast the host is is not a catch this suite can state, and the project has recorded before that a nonzero exit is not proof. Reopening condition: if a later slice gives the walk a verdict that DOES depend on which path reached a node, the memo stops being sound and this mutation stops being a survivor -- it becomes a bug detector, and must be re-measured then rather than inherited. 2026-09-10 (Milestone 7 Slice ①): the condition FIRED and this was re-measured, not inherited. The walk now answers a `(verdict path)` pair, so which route reached a node IS observable -- but the mutant STILL SURVIVES (verify-tests 184/184, status 0 with the line deleted). Why no fixture separates it: `eof-verdict-join` folds its operands left-to-right and keeps the LEFT on a tie (decision 0032 item 5), so the winning operand's path is always the one computed first, before any node it shares with a later operand is memoised; the memo can only ever return a stale path to a LOSING right operand. A re-convergent fixture (a parked node whose two eof-successors both reach one node that then reaches a stop) was reasoned through and reports the same path with the memo present or absent, because the left branch wins the tie and its path is fresh either way. The reopening condition is now satisfied at the path level and the answer is the same: sound, and unwitnessed, for the same structural reason as before -- one level deeper."
  )

# Slice ② task 3 adds FIVE for the zero-width census. Two of them are the
# WALK/REPORT pair the M3 precedent in this file warns about, and they needed a
# fixture of their own before they were separable at all -- see the middle two.

# Slice ③ task 2 adds SIX for the input-reading kind's census.
#
# *** The two zero-progress disjuncts have SEPARATE fixtures, and that is the
# whole point of design §8's correction. *** §8 said only `nondigit-edge` can be
# `reexecute` "since the overflow edge is non-consuming but terminal-directed" --
# it is not, and §8 contradicts itself sixteen lines later. Measured: cutting
# Slice ②'s field-action arm to one disjunct makes a self-targeting error edge
# verify with ZERO diagnostics. Each disjunct's mutation fails only its own
# fixture, which is what a one-fixture task would have hidden.

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: an accumulate's OVERFLOW edge is invisible to the zero-progress walk"
  # §12.7:772 makes the overflow non-consuming and §15:870 leaves the field
  # unchanged, so an overflow-error naming its own node re-reads the same byte
  # forever -- and neither runtime loop guards against it. This is the arm
  # design §8's instruction would have omitted.
  FIND [[                (list (integer-accumulate-node-overflow-error n))))]]
  REPLACE [[                '()))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the input-reading kind in the verifier census \\(Slice ③\\).an accumulate whose OVERFLOW edge targets itself is a zero-progress cycle: zero-progress-cycle")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: an accumulate's NONDIGIT reexecute edge is invisible to the zero-progress walk"
  # The disjunct §8 did name. Its own fixture, because the overflow mutation
  # above passes this one and vice versa.
  FIND [[                (if (eq? (edge-mode (integer-accumulate-node-nondigit-edge n)) 'reexecute)
                    (list (edge-target (integer-accumulate-node-nondigit-edge n)))
                    '())]]
  REPLACE [[                '()]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the input-reading kind in the verifier census \\(Slice ③\\).an accumulate whose NONDIGIT edge reexecutes into itself is a zero-progress cycle: zero-progress-cycle")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the accumulate DIGIT edge wrongly joins the zero-progress walk"
  # The restrictive direction, and the reason the digit edge stays out:
  # §10.6:566 makes it always advance, so a machine looping on digits makes
  # progress and must not be reported.
  FIND [[                (list (integer-accumulate-node-overflow-error n))))]]
  REPLACE [[                (list (integer-accumulate-node-overflow-error n)
                      (integer-accumulate-node-digit-target n))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the input-reading kind in the verifier census \\(Slice ③\\).the DIGIT edge self-targeting is not a cycle -- it advances: no cycle")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the zero-progress REPORT set excludes the accumulate kind"
  # SUBSUMED BY either walk mutation above, by construction and in the nesting
  # this file already records for the pause kind -- narrowing the report stops
  # the accumulate node being flagged, narrowing a walk stops that AND every node
  # whose cycle runs through one. Kept because shipping one without the other is
  # the half-fix this pass exists to prevent.
  FIND [[                                         (integer-accumulate-node? n)
                                         (callback-node? n)
                                         (span-start-node? n) (span-end-node? n)
                                         (counted-consume-node? n))
                                     (self-cycle (node-name n)))]]
  REPLACE [[                                         (callback-node? n)
                                         (span-start-node? n) (span-end-node? n)
                                         (counted-consume-node? n))
                                     (self-cycle (node-name n)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the input-reading kind in the verifier census \\(Slice ③\\).an accumulate whose NONDIGIT edge reexecutes into itself is a zero-progress cycle: zero-progress-cycle")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: an accumulate's byte targets are not out-targets"
  # Three of its four explicit targets are byte out-targets; the fourth,
  # eof-target, belongs to node-eof-target so that `eof-step` -- which is what
  # reads it for the reachability walk since decision 0031 -- adds it and the
  # :908 filter does not see it.
  # Re-anchored at Slice ⓪b task 5: node-out-targets is now a derived view of
  # node-out-edges, whose arms yield (role . target) pairs.
  FIND [[          ((integer-accumulate-node? n)
           (list (cons 'digit (integer-accumulate-node-digit-target n))]]
  REPLACE [[          ((integer-accumulate-node? n)
           (list]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the input-reading kind in the verifier census \\(Slice ③\\).an accumulate's three byte targets are out-targets, so they are reachable: nothing unreachable")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: an accumulate's field reference is not checked"
  # D3's sibling arm. Not a `field-operand-schemas` row: that table is keyed on
  # a selector and an arity and an accumulate node has neither. Reported under
  # the NODE's name, matching the operand walk's own convention -- design §8
  # prescribes the field name, which would put two conventions under one code.
  FIND [[    (if (field-width-of fs (integer-accumulate-node-field n))]]
  REPLACE [[    (if #t]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the input-reading kind in the verifier census \\(Slice ③\\).an accumulate naming no declared field is invalid-field-operand: invalid-field-operand")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a zero-width node's targets are not out-targets"
  # node-out-targets feeds name resolution, reachability AND the :908 check, so
  # this one arm missing makes a well-formed machine report defects it does not
  # have and hides one it does.
  # Re-anchored at Slice ⓪b task 5: node-out-targets is now a derived view of
  # node-out-edges, whose arms yield (role . target) pairs.
  # Re-anchored by Milestone 5 Slice ②, FIND *and* REPLACE: the arm gained the
  # callback kind, and the REPLACE keeps the disjunct list intact so the mutant
  # still differs from the baseline in ONE thing -- the arm's answer.
  FIND [[          ((or (field-action-node? n) (field-branch-node? n)
               (callback-node? n)
               (span-start-node? n) (span-end-node? n))
           (zero-width-edges n))]]
  REPLACE [[          ((or (field-action-node? n) (field-branch-node? n)
               (callback-node? n)
               (span-start-node? n) (span-end-node? n))
           '())]]
  EXPECT_STATUS 1
  # RE-PINNED by Milestone 7 Slice ⓪, on a fixture this mutant can still reach.
  # The old pin was a conjunction whose first half was the case's "nothing
  # unreachable" check on a machine whose field-action node IS THE ENTRY -- and
  # decision 0031 makes the entry a parked node, so `eof-step` (which reads
  # `zero-width-edges` directly) visits its successors on the EOF walk and the
  # check no longer reddens under this mutant. Strengthened, not loosened: the
  # entry fixture keeps its own check, and the case gained a SECOND machine
  # where the zero-width node is reached by a byte edge from the entry instead
  # -- nothing is parked there, so the arm under test is the only route to the
  # stop. One whole measured record, no `.*`.
  EXPECT_OUTPUT_MATCHES
    "the zero-width census .Slice ② task 3..a zero-width node's targets are out-targets, so they are reachable: and reachable through a zero-width node the entry only reaches by a byte edge -- expected .., got ..unreachable-node . after..")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the zero-progress WALK does not follow a zero-width node"
  # Pinned on the through-a-dispatch fixture, which is the record the REPORT
  # mutation below cannot produce: there the cycle's reported member is the
  # byte-dispatch node, which stays in the report set either way, so narrowing
  # the report leaves that diagnostic standing while narrowing the walk removes
  # it. That fixture was added FOR this separation -- without it the two mutants
  # emit identical records, which is exactly the half-fix M3 Slice ② shipped.
  # Re-anchored by Milestone 5 Slice ②: the arm gained the callback kind, which
  # is zero-width too, so deleting the arm is still exactly the edit this LABEL
  # names -- the walk stops following a zero-width node, now for three kinds
  # rather than two.
  FIND [[              ((or (field-action-node? n) (field-branch-node? n)
                   (callback-node? n)
                   (span-start-node? n) (span-end-node? n))
               (zero-width-successors n))
]]
  REPLACE [[              ]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a cycle running THROUGH a zero-width node is attributed to the dispatch: attributed to start")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the zero-progress REPORT set excludes the zero-width kinds"
  # SUBSUMED BY the walk mutation above, by construction and in the same nesting
  # this file already records for the pause kind: narrowing the REPORT stops the
  # zero-width nodes being flagged, narrowing the WALK stops those AND every node
  # whose cycle merely runs through one. Each removes a superset of the last, so
  # there is no record the narrower one owns. Kept because the two are distinct
  # decisions and shipping only one of them is the defect this pass exists to
  # prevent -- a `store`-into-itself machine that verifies clean and then hangs.
  # Re-anchored by Slice ③ task 2: the guard gained its sixth disjunct.
  FIND [[                                         (field-action-node? n) (field-branch-node? n)
                                         (integer-accumulate-node? n)
                                         (callback-node? n)
                                         (span-start-node? n) (span-end-node? n)
                                         (counted-consume-node? n))
                                     (self-cycle (node-name n)))]]
  REPLACE [[                                         (integer-accumulate-node? n)
                                         (callback-node? n)
                                         (span-start-node? n) (span-end-node? n)
                                         (counted-consume-node? n))
                                     (self-cycle (node-name n)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a zero-width self-cycle is a zero-progress cycle: zero-progress-cycle")

# Slice ② task 4 adds EIGHT for pass-fields' operand half. Three by-construction
# subsumptions are recorded at their own sites: each is a NARROWER edit of a
# check a broader mutation already removes, and each is kept because it names its
# own decision.

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: field operand arity is not checked"
  # The check the constructor deliberately does not make -- 0020 item 2: nothing
  # can be read out of `arguments` before arity is known, which is the same
  # sentence that put this here rather than there.
  FIND [[       ((not (= (length args) (cadr row)))]]
  REPLACE [[       ((and #f (not (= (length args) (cadr row))))]]
  EXPECT_STATUS 1
  # Pinned on the RAISE, which is this mutant's own record lane-wide and is
  # also the decision's own stated reason: 0020 item 2 puts arity here rather
  # than in the constructor because "nothing can be read out of `arguments`
  # before arity is known", and unguarded, the range check reads a third
  # element that is not there. The union mutants above produce every other
  # record this one does, but not this: with the pass gone, the range check is
  # never reached at all.
  EXPECT_OUTPUT_MATCHES
    "every predicate's arity is enforced: case raised -- Exception in caddr")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: an operand naming no declared field is accepted"
  # SUBSUMED BY "the operand width is read from the first declared field"
  # below, by construction: that mutant looks up a field that always exists, so
  # it never reports an undeclared one either, and it additionally answers the
  # wrong width. Kept because the two name different decisions.
  FIND [[           ((not width)]]
  REPLACE [[           ((and #f (not width))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "an undeclared field is invalid-field-operand: one -- expected 1, got 0")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the operand width is read from the first declared field"
  # The reason the width lookup is keyed on the operand: with one field declared
  # this is invisible, so the fixture declares TWO of different widths and asserts
  # that a value legal for the WIDE one is accepted.
  FIND [[(field-width-of fs (car args))]]
  REPLACE [[(field-width-of fs (uint-field-name (car fs)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the width checked is the REFERENCED field's, not some other field's: legal for the wide field")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: operand range against the declared width is not checked"
  # Pinned on the range fixture's TWO-fault count, which is the record the
  # off-by-one mutation below cannot produce.
  FIND [[                            (if (operand-in-width? v width) #f]]
  REPLACE [[                            (if #t #f]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "an out-of-width range operand does not also report low > high: two width faults only -- expected 2, got 0")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the operand width bound is off by one"
  # SUBSUMED BY the mutation above, by construction -- accepting 2^w accepts
  # everything that accepting anything accepts, minus nothing this lane can see.
  # The boundary is what it names: 255 is legal for a u8 and 256 is the first
  # value that is not, so the premise case and this one together pin the edge
  # rather than "some large number is refused".
  FIND [[    (and (integer? v) (exact? v) (<= 0 v (- (expt 2 width) 1))))]]
  REPLACE [[    (and (integer? v) (exact? v) (<= 0 v (expt 2 width))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a constant above the field's declared width is invalid-field-operand: 256 -- expected 1, got 0")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: low > high for a range predicate is accepted"
  # Decision 0020 item 2's "consequence that will look wrong to a reader of
  # 0017": the constructor accepts this and the verifier is where it is caught.
  FIND [[                      (> (cadr args) (caddr args)))]]
  REPLACE [[                      #f)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "low > high for range is invalid-field-operand: one -- expected 1, got 0")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a range's low may not equal its high"
  # The RESTRICTIVE direction, and the boundary the check actually names: the
  # test is `low > high`, not `low >= high`. Without this a `range` over a single
  # value would be rejected and nothing would notice.
  FIND [[                      (> (cadr args) (caddr args)))]]
  REPLACE [[                      (>= (cadr args) (caddr args)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "low = high for range is legal: none -- expected 0, got 1")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the operand half is never run"
  # The UNION mutant -- dropping the join removes every check above at once, so
  # its record set contains each of theirs and is inside none of them. Separated
  # by a CONJUNCTION: one arity record and one low/high record, which no
  # single-check mutant produces together.
  FIND [[       (pass-field-operands m fs))))]]
  REPLACE [[       '())))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "wrong arity is invalid-field-operand: too few -- expected 1, got 0.*low > high for range is invalid-field-operand: one -- expected 1, got 0")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: pass-fields is never run"
  # The JOIN, which shipped with no mutation at all until the whole-branch review
  # found the declination above unsound. Its two records are each shared with one
  # of the two permissive mutants, and with a different one each -- so the
  # conjunction is what identifies it, and neither half alone would.
  # `'()` rather than deleting the line: the runner requires a non-empty REPLACE,
  # and an empty append arm drops the pass while keeping the form well-shaped, so
  # the mutant dies at the checks rather than at expand time.
  FIND [[                                  (pass-fields machine)]]
  REPLACE [[                                  '()]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "two fields sharing a name is invalid-field-declaration: one finding -- expected 1, got 0.*a nonportable field name is invalid-field-declaration: one finding -- expected 1, got 0")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: every pair of fields is reported as sharing a name"
  # The duplicate check's restrictive direction, which is what makes the
  # clean-premise case load-bearing for THAT check -- exactly the argument this
  # block already made for the portable check, and then declined to apply here on
  # a measurement that was stale.
  FIND [[(memq fname fseen)]]
  REPLACE [[#t]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "two fields sharing a name is invalid-field-declaration: one finding -- expected 1, got 2.*distinct portable field names verify clean: no diagnostics -- expected 0, got 3")

# *** Both permissive arm mutations below are SUBSUMED BY the join mutation
# above, BY CONSTRUCTION, and are kept anyway. *** Measured in the re-sweep: each
# arm's whole record set is a strict subset of the join's, because the join drops
# both checks and each arm drops one, so the join is strictly more permissive on
# every machine and no fixture can redden an arm while leaving the join green.
# That is the one kind of subsumption this project treats as closed rather than
# as an under-specified lane -- there is nothing to separate, not merely nothing
# found. They are kept because they name DISTINCT decisions: that the duplicate
# check fires, that the portable check fires, and that the pass is wired in at
# all. The cost is attribution, not detection: delete the join and all three
# report caught, two of them under an arm's label.
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: two fields may share a name"
  # The defect the pass exists to close, and the one measured to verify CLEAN
  # before this slice: slot = declaration index, so two `count` fields take two
  # slots and parser-field-ref answers with whichever the name map finds first,
  # orphaning the other slot and its initial.
  FIND [[(memq fname fseen)]]
  REPLACE [[#f]]
  # Named apart from pass-names' node-duplicate loop, which is the same shape:
  # cloning its `(memq nm seen)` gave this file ONE find at TWO sites, measured,
  # and silently mutated the node check as well.
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "two fields sharing a name is invalid-field-declaration: one finding -- expected 1, got 0")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a field name is not checked against the portable grammar"
  FIND [[(valid-name? (uint-field-name f))]]
  REPLACE [[#t]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a nonportable field name is invalid-field-declaration: one finding -- expected 1, got 0")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: every field name is reported as nonportable"
  # The restrictive direction. Only field-carrying machines move, and this file
  # has exactly three, so the mutant emits two records rather than flooding the
  # lane. Pinned on the CLEAN one: without it a permissive-only pin set would
  # accept a pass that rejects everything.
  FIND [[(valid-name? (uint-field-name f))]]
  REPLACE [[#f]]
  EXPECT_STATUS 1
  # A CONJUNCTION, re-anchored by the whole-branch review's re-sweep. The clean
  # record alone is shared with the duplicate check's restrictive mutant (written
  # above, after that declination was found unsound), which reddens the same case
  # with the same 0-versus-3. Neither mutant's set contains the other's, so the
  # pair separates them where neither record does: this mutant reports one
  # diagnostic per field and the two-field case reaches 3, which the other never
  # does.
  EXPECT_OUTPUT_MATCHES
    "two fields sharing a name is invalid-field-declaration: one finding -- expected 1, got 3.*distinct portable field names verify clean: no diagnostics -- expected 0, got 3")

# --- Whole-branch review, 2026-09-03: the three kind filters Slice ③ did not
# widen. Each is a hand-enumerated list of node kinds that `node-eof-target` and
# `node-out-targets` were taught about and these were not, and each was written
# with an EXPLICIT `else` or an implicit '() so that a missing kind is silent --
# which is why nothing failed for a whole slice.

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: eof-terminal's classify loses its accumulate arm and raises out of verification"
  # The worst FAILURE MODE of the three, though not the worst consequence: this
  # one raises, so a legal machine gets no verdict at all rather than a wrong
  # one, and compile-machine raises with it. Caught by a case that asserts
  # verify-machine RETURNS -- an ok?/diagnostics assertion cannot see a raise.
  FIND [[                ((integer-accumulate-node? n)
                 (dispatch-arm (integer-accumulate-node-eof-target n) path))
                (else (assertion-violation 'eof-terminal]]
  REPLACE [[                (else (assertion-violation 'eof-terminal]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "an EOF chain may reach an accumulate node at all: case raised")

# --- Milestone 5 Slice ⓪ task 1: the site that was DEAD IN THE SUITE ----------
#
# Measured before the fixture existed: deleting this clause left every runnable
# program in the tree byte-identical -- 26 programs, 504 case-runs, zero
# failures. The clause is live code with no witness, and it is the only site
# that can attribute an EOF zero-progress cycle to a PAUSE node; the other site
# attributes such a cycle to a dispatch node's eof-target chain, which this
# fixture's machine deliberately does not have (its entry's eof route is a
# finish). parser-finish-op! relies on these checks for termination, so the
# shape this clause rejects is one that loops forever in both executors.

# --- Milestone 5 Slice ⓪b task 2: §16.2:908 becomes ONE derived block ---------
#
# SEVEN mutations were REMOVED here, and their residue is recorded rather than
# lost. They pinned decisions that no longer exist as separate code: three
# hand-written :908 sites (one unconditional and kind-filtered, two gated on
# byte-reachability) collapsed into one block keyed on byte-reachability alone.
# The removed labels, and where each decision now lives:
#
#   "a byte edge into a finish terminal is accepted"          -> the shared
#       finish-node? test, now pinned by "reads only the first out-target"
#       and by the vacuous-gate pin below.
#   "a byte-reachable pause into finish is rejected"          -> subsumed: the
#   "the zero-width :908 check never fires"                      one block sees
#       every kind through node-out-targets, so a per-kind site cannot be
#       removed independently of the others.
#   "a pause's byte-reachability gate is not checked"         -> subsumed into
#   "the zero-width :908 check is not gated on byte-reachability"  the single
#       gate, pinned below in both directions.
#   "a sequence case's byte edge ... (arm 6, :908)"           -> the outer
#   ":908 byte-edge-into-finish stops admitting accumulate"      source-kind
#       filter is GONE. There is no kind census left to narrow, which is the
#       point of the change: those two mutations existed because the filter
#       existed, and it is the construct that shipped three Slice ③ defects.
#
# Net: 7 removed, 3 added.

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the :908 check is not gated on byte-reachability"
  # The decision OQ-3 settled. Measured in both directions: this mutant rejects
  # `make-pause-machine` -- decision 0011's canonical legal shape, an EOF-only
  # pause continuing into a finish -- so the shipped fixture's own case reddens
  # alongside the new twelve-machine battery. That is the evidence the
  # unconditional reading is wrong, wired in as a pin.
  FIND [[                       (if (memq (node-name n) br908)
                           (filter values]]
  REPLACE [[                       (if #t
                           (filter values]]
  EXPECT_STATUS 1
  # RE-PINNED by Milestone 7 Slice ⓪. The old pin was the case-label prefix
  # "...: none rejected", which Task 2 renamed when the case was re-baselined --
  # and which the suite's own note on "verify: a counted consume's next is not
  # an out-edge" already recorded as coarse enough for three mutants to satisfy.
  # This is the whole measured `expected ... got ...` record of the renamed
  # check, so it stops being a prefix: under this mutant every one of the eight
  # kinds gains `non-eof-into-finish` at `hop`, beside the three
  # `unreachable-node`s the narrowing puts there. The case's sibling check "no
  # kind reports non-eof-into-finish for the untakeable edge" is §16.2:908 in
  # isolation and also reddens; either separates this mutant, and the whole-list
  # record is the stronger of the two.
  EXPECT_OUTPUT_MATCHES
    "§16.2:908 is gated on byte-reachability, for every kind .Slice ⓪b..an EOF-only-reachable byte edge into a finish is accepted: the finish behind a dead byte edge is unreachable for the three input-reading kinds, and nothing else is reported -- expected ..byte-dispatch .unreachable-node . fin.. .sequence-dispatch .unreachable-node . fin.. .integer-accumulate .unreachable-node . fin..., got ..byte-dispatch .unreachable-node . fin. .non-eof-into-finish . hop.. .sequence-dispatch .unreachable-node . fin. .non-eof-into-finish . hop.. .integer-accumulate .unreachable-node . fin. .non-eof-into-finish . hop.. .pause .non-eof-into-finish . hop.. .field-action .non-eof-into-finish . hop.. .field-branch .non-eof-into-finish . hop.. .callback .non-eof-into-finish . hop.. .counted-consume .non-eof-into-finish . hop...")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the :908 gate is vacuous, so no byte edge into a finish is ever rejected"
  # The reverse direction. A gate that admits nothing passes the acceptance half
  # of the battery for the wrong reason, so the rule needs its own pin against
  # emptiness -- the shape AGENTS.md calls seeding an output before asserting it.
  FIND [[                       (if (memq (node-name n) br908)
                           (filter values]]
  REPLACE [[                       (if #f
                           (filter values]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a BYTE-reachable byte edge into a finish is rejected at its source node")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the :908 check reads only the first of a node's out-targets"
  # `node-out-targets` is now the single census this rule consults. Reading one
  # element of it is the shape that survives a per-node dedup and still misses a
  # real violation -- a dispatch whose SECOND case targets a finish.
  # Re-anchored at Slice ⓪b task 5: node-out-targets is now a derived view of
  # node-out-edges, whose arms yield (role . target) pairs.
  # *** Re-shaped by the whole-branch review: this REPLACE was caught by a CRASH,
  # not by the decision its label names. *** `(car '())` raises on any node with
  # no out-edges, so 109 of 116 cases failed with the identical
  # "Exception in car: () is not a pair" -- including the case the pin's own
  # regex anchors on. AGENTS.md prefers a comparison precisely because a raise
  # depends on where the mutant happens to crash. Taking the LAST edge instead
  # keeps the mutation total (it still reads one edge of many) and makes the
  # failure a comparison on the case that names the decision.
  FIND [[                                        (node-out-edges n)))
                           '()))
                     nodes)))]]
  REPLACE [[                                        (let ((es (node-out-edges n)))
                                          (if (null? es) '() (list (car es))))))
                           '()))
                     nodes)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a byte-dispatch's case and fallback into one finish are two distinguishable findings")
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the entry being a finish terminal is not rejected (Slice ⓪b, OQ-2)"
  # The zero-hop case. Kept as its own clause and its own pin rather than folded
  # into the per-edge loop, because it is an independently revertible decision:
  # §16.2:908's words are about control flow INTO a node, and reading the entry
  # as "reached by parser-feed!" is an interpretation the plan argues for
  # explicitly. If a later slice disagrees, this is the one line to remove.
  FIND [[         (if (and en (finish-node? en))]]
  REPLACE [[         (if (and en (finish-node? en) #f)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a machine whose entry IS a finish node is rejected, once, at the entry")

# --- Milestone 5 Slice ⓪b task 4: §16.2:909 walks from the PARKED set ---------
#
# FIVE mutations removed here, residue recorded. They pinned per-kind :909 sites
# that no longer exist: two blocks (one enumerating dispatch/sequence/accumulate
# and classifying each one's eof-TARGET, one for byte-reachable pauses) became a
# single walk over the states a parser can be parked on, classifying each node as
# ITSELF. The removed labels and where each decision now lives:
#
#   "a byte-reachable pause's continuation chain ..."   -> subsumed: a pause is
#   "a pause's byte-reachability gate is not checked"      in the parked set and
#       classified through the same eof-terminal call, under the same gate --
#       pinned below in both directions.
#   "a sequence node's own eof-target chain ..." (arm 7) -> the outer source-kind
#   "the :909 EOF-chain walk stops admitting accumulate"    filter is GONE. The
#       derived `(symbol? (node-eof-target n))` disjunct replaces both, and its
#       own pin is below. This is the one decision the derived form genuinely
#       costs: arm 7 had a disjunct to re-anchor onto and now there is none.
#   "an EOF cycle through pause continuations is not reported" -> RE-ANCHORED,
#       not deleted: Slice ⓪'s task 1 decision is intact and its fixture is
#       byte-identical under the new walk. Only its anchor moved.

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the :909 walk does not start at the entry (D-1)"
  # The defect this slice exists for. Without the entry in the start set, a
  # machine whose entry is itself a stop -- or a zero-width node leading to one --
  # verifies with ZERO diagnostics and `parser-finish!` returns `stopped`.
  # Re-anchored by Milestone 7 Slice ⓪ (decision 0031): the §16.2:909
  # membership and `span-flow`'s copy are ONE `parked?` now, so this FIND
  # moved onto that procedure and the mutant reaches all three consumers
  # (pass 6, pass 7, `occupiable`). The decision it names is unchanged.
  FIND [[         (or (eq? (node-name n) (machine-entry m))]]
  REPLACE [[         (or #f]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "an entry whose own EOF path reaches a stop is rejected: each rejected exactly once, at the entry")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the :909 start set is not gated on byte-reachability"
  # The parked set is parkable states, not graph nodes. Ungated, nodes no
  # execution can occupy start walks -- which is the over-approximation decision
  # 0011 item 4(a)'s literal words invite and this slice narrows.
  # Re-anchored by Milestone 7 Slice ⓪ (decision 0031): the §16.2:909
  # membership and `span-flow`'s copy are ONE `parked?` now, so this FIND
  # moved onto that procedure and the mutant reaches all three consumers
  # (pass 6, pass 7, `occupiable`). The decision it names is unchanged.
  FIND [[    (and (memq (node-name n) br)]]
  REPLACE [[    (and #t]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "an EOF chain of pauses that cycles is a zero-progress EOF cycle")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the :909 start set enumerates a kind instead of deriving the EOF route"
  # The census this slice removed, reinstated as a mutant. Narrowing the derived
  # disjunct back to one kind is exactly the shape that lost sequence nodes and
  # then accumulate nodes their walks, twice, in two different slices.
  # Re-anchored by Milestone 7 Slice ⓪ (decision 0031): the §16.2:909
  # membership and `span-flow`'s copy are ONE `parked?` now, so this FIND
  # moved onto that procedure and the mutant reaches all three consumers
  # (pass 6, pass 7, `occupiable`). The decision it names is unchanged.
  FIND [[             (symbol? (node-eof-target n)))))]]
  REPLACE [[             (byte-dispatch-node? n))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "an eof chain that cycles through a sequence node is an EOF cycle")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: an EOF cycle through pause continuations is not reported"
  # Slice ⓪ task 1's pin, RE-ANCHORED onto the same decision's new home. The
  # decision is unchanged and its fixture is byte-identical under the parked-set
  # walk; only the code it lives in moved. Recorded rather than silently
  # re-pinned, because a pin that changes anchor without changing decision is
  # exactly what a reader needs told.
  FIND [[                               ((cycle)
                                (list (make-diagnostic/path 'eof-zero-progress-cycle (node-name n)
                                                            "an EOF path cycles without reaching a terminal"
                                                            path)))]]
  REPLACE [[                               ((cycle) '())]]
  EXPECT_STATUS 1
  # RE-ANCHORED (the incumbent half of Milestone 7 Slice ⓪'s two-direction
  # sweep). The pin was the bare check label "…AT A PAUSE NODE: at least one, at
  # a pause", which this slice's new "the parked set loses the pause disjunct"
  # also reddens -- and which two shipped mutants already satisfied on the merge
  # base. Re-anchored on a CONJUNCTION of two whole measured records no sibling
  # produces together; measured collision set: EMPTY, where the base's was two.
  EXPECT_OUTPUT_MATCHES
    "EOF terminals and eof-target verification .§16.2..an eof-target cycle is rejected .eof-zero-progress-cycle.: has eof-zero-progress-cycle -- expected a true value.*the thirteenth kind in the verifier census .Milestone 6 Slice ①..a self-targeting eof-target is an EOF zero-progress cycle: eof-zero-progress-cycle, at the node -- expected ..eof-zero-progress-cycle . body.., got .[)]")

# --- Milestone 5 Slice ⓪b task 5: §16.4:940's edge/source label --------------

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: every :908 finding is labelled `case` regardless of which edge produced it"
  # A constant label is the failure mode a label invites: present, plausible, and
  # carrying no information. It passes any check that merely asserts the slot is
  # non-#f, which is why the fixtures assert the whole (code node edge) triple.
  FIND [[                                                 (car re)]]
  REPLACE [[                                                 'case]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a byte-dispatch's case and fallback into one finish are two distinguishable findings")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: node-out-targets returns the roles instead of the targets"
  # The census and its derived view must not drift apart. `node-out-edges` is the
  # one census; `node-out-targets` is `(map cdr ...)` of it. Taking `car` instead
  # is the shape a hand-written second census would have had to get right, and it
  # breaks reachability and :908 together -- which is the argument for deriving
  # the view rather than writing it twice.
  FIND [[  (define (node-out-targets n) (map cdr (node-out-edges n)))]]
  REPLACE [[  (define (node-out-targets n) (map car (node-out-edges n)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "a finish node reachable only via an eof-target verifies")

# --- Milestone 5 Slice ⓪b task 6: the EOF verdict tiers ----------------------
#
# A flat six-element ranking has 720 orderings, of which 24 are observationally
# identical -- four mutations permuted it undetected. Three tiers make those 24
# UNWRITABLE rather than something to declare EXPECT_SURVIVES, and each tier
# assignment becomes a single-token mutation caught by a failed comparison.

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: eof-reachable-stop is promoted into the benign tier"
  # §16.2:909's whole verdict, demoted to tie with the verdicts that mean "the
  # chain terminates". Every join then masks it -- three fixtures redden.
  FIND [[    '((finish unresolved error default-error)
      (eof-reachable-stop)]]
  REPLACE [[    '((finish unresolved error default-error eof-reachable-stop)
      ()]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "an `error` sibling does not mask the stop")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: default-error is promoted out of the benign tier"
  # The acceptance hole, as a pin. Promoting `default-error` above the benign
  # tier is one step from promoting it above `cycle`, which was MEASURED to make
  # a field-branch machine verify with zero diagnostics while `parser-finish!`
  # never returns. One token, and the only fixture that moves is the one whose
  # sibling verdict is `default-error` -- which is what makes it this pin's own.
  FIND [[    '((finish unresolved error default-error)
      (eof-reachable-stop)]]
  REPLACE [[    '((finish unresolved error)
      (eof-reachable-stop default-error)]]
  EXPECT_STATUS 1
  # RE-ANCHORED by Milestone 7 Slice ⓪. The pin was a bare CASE-NAME prefix,
  # which twelve mutants satisfied on the merge base and which the re-baselined
  # join expectation would have taken to fourteen. Re-anchored on a conjunction
  # of two whole measured records. Residue, measured and named: "verify: an
  # EOF-reachable stop terminal is accepted" and "verify: eof-reachable-stop is
  # promoted into the benign tier" still satisfy it -- both stop
  # `eof-reachable-stop` being reported at all, so every check this mutant
  # reddens they redden too. The subset relation was computed in BOTH
  # directions; it holds one way only, so this is subsumption rather than
  # under-anchoring, and the merge-base control shows both.
  EXPECT_OUTPUT_MATCHES
    "a benign EOF verdict never outranks a stop in a join .Slice ⓪b..a `default-error` sibling does not mask the stop: eof-reachable-stop survives the join -- expected ..unreachable-node . rj2. .eof-reachable-stop . s0.., got ..unreachable-node . rj2...*the thirteenth kind in the verifier census .Milestone 6 Slice ①..the flow-through zero-count stop at the ENTRY is rejected .0030 item 5.: eof-reachable-stop, at the entry -- expected ..eof-reachable-stop . body.., got .[)]")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: unresolved is promoted out of the benign tier"
  # Added by the whole-branch review, which found this tier assignment
  # LOAD-BEARING AND UNWITNESSED -- while the source claimed the verdict was
  # unproducible and the tier comment claimed every assignment was a one-token
  # caught mutation. Both were false for this one symbol. `classify` still
  # answers `'unresolved` for an EOF successor naming no node, and a machine
  # whose chain reaches a dangling name AND a stop reports the stop only because
  # `unresolved` loses the join.
  FIND [[    '((finish unresolved error default-error)
      (eof-reachable-stop)
      (cycle)))]]
  REPLACE [[    '((finish error default-error)
      (eof-reachable-stop)
      (cycle unresolved)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "an UNRESOLVED sibling does not mask the stop")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the zero-width kinds report one role for all their edges"
  # Added by the whole-branch review, which found NINE of the thirteen role
  # labels with no test and no pin -- so a role could be wired to the wrong
  # accessor, or to a constant, for four of the six kinds without anything
  # failing. That is the same shape as a label that is always present: there,
  # carrying no information; here, carrying the wrong one.
  # Re-anchored by Milestone 5 Slice ②, FIND *and* REPLACE: the arm gained the
  # callback kind. The REPLACE keeps all three disjuncts, so the mutant still
  # differs from the baseline in ONE thing -- the labels -- which is what this
  # LABEL claims and what its pin can prove.
  FIND [[          ((or (field-action-node? n) (field-branch-node? n)
               (callback-node? n)
               (span-start-node? n) (span-end-node? n))
           (zero-width-edges n))]]
  REPLACE [[          ((or (field-action-node? n) (field-branch-node? n)
               (callback-node? n)
               (span-start-node? n) (span-end-node? n))
           (map (lambda (re) (cons 'next (cdr re))) (zero-width-edges n)))]]
  EXPECT_STATUS 1
  # Re-anchored at Slice ③ task 8: the case is "every other kind" now, the
  # census having grown a callback row and two span rows.
  EXPECT_OUTPUT_MATCHES "every other kind labels its edges too")

# Milestone 5 Slice ②: §16.2:901's NODE half. Four faults, three codes, and one
# arm ORDER that is load-bearing -- the duplicate check runs first, so a key
# listed twice reports once as a duplicate rather than twice as whatever else it
# is. Each mutation below removes exactly one arm.
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a callback node may invoke a span callback"
  # §10.6:584 invokes "one named event or decision callback". Without this arm
  # a node naming a span-data callback verifies clean and then invokes, at run
  # time, a procedure whose signature takes four arguments and not two.
  FIND [[        ((not (memq (callback-declaration-kind cd) '(event decision)))]]
  REPLACE [[        ((and #f (not (memq (callback-declaration-kind cd) '(event decision))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a node invoking a span-kind callback is an invalid invocation: the invocation, and nothing about keys")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a callback node's UNDECLARED branch key is accepted"
  # This arm is also §13:812's first sentence enforced statically: an event
  # callback declares no keys, so every key on its node is undeclared.
  FIND [[                         (if (memq k (callback-declaration-branch-keys cd)) #f]]
  REPLACE [[                         (if #t #f]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a key the declaration never declared is UNDECLARED: one finding, at the node")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a declared branch key with no target on the node is accepted"
  # The arm that makes `normalize-machine`'s own "no target for the default
  # branch" raise unreachable: §9.3:419 takes an optional decision callback's
  # default branch with no callback to ask, so a node with no target for it has
  # nothing to lower.
  FIND [[                         (if (memq k keys) #f]]
  REPLACE [[                         (if #t #f]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a declared key the node gives no target for is MISSING: one finding, at the node")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a branch key listed twice on one node is not reported"
  # Dropping the duplicate arm does not make the machine verify: the key is
  # declared and has a target, so nothing else objects to it. The pin is the
  # duplicate case's whole result, which is the only thing that can tell "not
  # reported" from "reported under another code".
  FIND [[                           (cons (make-diagnostic 'duplicate-branch-key nm
                                                  "branch key listed twice on one node")
                                 kout)]]
  REPLACE [[                           kout]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a key listed twice is DUPLICATED, and reports once: exactly one finding, and it is the duplicate")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a callback node naming no declaration falls through to the key arms"
  # The RESOLUTION short circuit. Without it the key arms run against `cd` = #f
  # and `callback-declaration-branch-keys` reads slot 4 of a boolean, so the
  # verifier RAISES on a machine it is supposed to reject with one finding.
  #
  # Pinned on the RAISE, deliberately, and this is the case AGENTS.md's "prefer
  # a comparison" rule makes room for rather than the case it warns about: the
  # raise IS the decision's consequence, not where the mutant happens to crash,
  # and there is no opposite constant to try -- `(and #t (not cd))` is the
  # baseline. Measured: `Exception in vector-ref: #f is not a vector`.
  FIND [[        ((not cd)
         (list (make-diagnostic/declarations 'missing-callback-declaration nm]]
  REPLACE [[        ((and #f (not cd))
         (list (make-diagnostic/declarations 'missing-callback-declaration nm]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the resolution arm answers ALONE: case raised")

# Milestone 5 Slice ③: pass 7, the span-state lattice (decision 0029). One
# mutation per decision the pass makes, and the two structural ones -- the edge
# set and the node domain -- are the two 0029 does NOT settle between them.
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: span RE-ENTRY is accepted"
  FIND [[               ((and (pair? state) (eq? (cadr state) s))
                (list (make-diagnostic/path 'invalid-span-state (node-name n)
                                            "span re-entry: this span is already open"
                                            path)))]]
  REPLACE [[               ((and (pair? state) (eq? (cadr state) s)) '())]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "span RE-ENTRY: a second start for the same span")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: span OVERLAP is accepted"
  FIND [[               ((pair? state)
                (list (make-diagnostic/path 'invalid-span-state (node-name n)
                                            "span overlap: another span is already open"
                                            path)))]]
  REPLACE [[               ((pair? state) '())]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "span OVERLAP: a start for a different span while one is open")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a WRONG END is accepted"
  FIND [[               ((pair? state)
                (list (make-diagnostic/path 'invalid-span-state (node-name n)
                                            "wrong end: a different span is open"
                                            path)))]]
  REPLACE [[               ((pair? state) '())]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "WRONG END: closing a span that is not the one open")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: an UNMATCHED END is accepted"
  FIND [[               ((eq? state 'none)
                (list (make-diagnostic/path 'invalid-span-state (node-name n)
                                            "unmatched end: no span is open"
                                            path)))]]
  REPLACE [[               ((eq? state 'none) '())]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "UNMATCHED END: closing with nothing open")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a merge disagreement is not reported"
  # Decision 0029 item 2, whose whole Context is the argument that this is a
  # rejection of its own and not a paraphrase of §14:843's fourth property.
  FIND [[                                    ((eq? st 'top)
                                     (list (make-diagnostic/path 'inconsistent-span-state]]
  REPLACE [[                                    ((and #f (eq? st 'top))
                                     (list (make-diagnostic/path 'inconsistent-span-state]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "INCONSISTENT: two branches disagree at a merge")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: top flows onward instead of stopping at the merge"
  # The other half of decision 0029 item 2, and the half that keeps the transfer
  # functions TOTAL: with `top` flowing, a span end downstream of the merge is
  # asked what it does on `top`, answers `unmatched end`, and blames a node that
  # is innocent.
  # Re-anchored at the final review, which deleted the `(not fn)` disjunct that
  # used to ride along here: `fn` is `(lookup nodes from)` and every edge's
  # `from` is a node's own name, so it could never be #f. The mutant is the same.
  FIND [[                             (if (or (not fs) (eq? fs 'top))]]
  REPLACE [[                             (if (not fs)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "INCONSISTENT: two branches disagree at a merge")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: pass 7's edge set omits the EOF routes"
  # *** THE ROW DECISION 0029 COULD NOT REACH. *** Its item 3 fixes the pass's
  # node domain and says nothing about its edges; without the eof half the
  # dataflow never arrives at a finish node that is only EOF-reachable, and
  # §16.2:907 -- "successful EOF with an active span" -- becomes unreachable.
  FIND [[      (append byte-edges eof-edges)))]]
  REPLACE [[      byte-edges))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "a span open at an EOF-ONLY finish is rejected too")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: pass 7's EOF half keeps taking byte edges"
  # Decision 0029 item 3 takes 0027's relation rather than minting a third, and
  # 0027 rejects by name the walk that crosses an eof-target and then keeps
  # taking byte edges, which describes no execution. This mutant is that walk,
  # and the fixture is the machine 0027's own Context derives.
  #
  # *** ITS FIRST FORM SHIPPED UNCAUGHT AND THE SUITE SAID SO. *** It removed a
  # `(memq to live)` filter -- which turned out to be vacuous, because `live` is
  # the CLOSURE of the edge relation and every edge's target is in it by
  # construction. The filter was deleted rather than documented, and the
  # decision it was meant to witness is witnessed here, where the two relations
  # actually differ.
  #
  # RE-SHAPED by Milestone 7 Slice ⓪: the REPLACE called `all-out-targets`,
  # which decision 0031 deleted -- an unbound identifier is a raise, not a
  # comparison, and the mutant would have been caught by where it happened to
  # crash rather than by the decision it names. The retired walk is reproduced
  # INLINE here; this and the tombstone above are the only two places the name
  # survives, both saying it is history.
  FIND [[                              (map (lambda (t) (cons (node-name n) t)) (eof-step n))]]
  REPLACE [[                              (map (lambda (t) (cons (node-name n) t))
                                   (append (node-out-targets n)
                                           (let ((t (node-eof-target n)))
                                             (if (symbol? t) (list t) '()))))]]
  EXPECT_STATUS 1
  # RE-MEASURED with the re-shaped REPLACE and with the case's re-baselined
  # expectation: the mutant reports the unmatched end at `cl` beside the four
  # `unreachable-node`s decision 0031 puts there, so the whole `got` is pinned
  # rather than the bare check label the shipped pin carried.
  EXPECT_OUTPUT_MATCHES
    "the span-state lattice .§16.2:899, :900, :907..a node no execution can occupy contributes no state .0029 item 3.: the span end on the untakeable byte edge is not reported -- expected ..unreachable-node . cl. .unreachable-node . exit. .unreachable-node . done. .unreachable-node . fin.., got ..invalid-span-state . cl. .unreachable-node . cl. .unreachable-node . exit. .unreachable-node . done. .unreachable-node . fin..")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the zero-progress report is not gated on byte-reachability"
  # §16.2:898's gate, decision 0027 item 3 (Milestone 5 Slice ③). Its own
  # fixture asserts BOTH directions, so this mutant is caught by the accepting
  # half -- the machine 0027's Context derives, which `unreachable-node` does
  # NOT catch either, which is why the gate is not the benign no-op design §3.2
  # item 4 called it.
  FIND [[                     (let ((cyc (and (memq (node-name n) br898)]]
  REPLACE [[                     (let ((cyc (and #t]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "an unoccupiable zero-progress cycle is accepted")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a span open at an ERROR terminal is rejected too"
  # Decision 0029 item 4 is about the SUCCESSFUL terminals only, and §14:839
  # contemplates a span still open at an error one. This is the mutation that
  # consumes decision 0023 item 5's kept `finish`-versus-`error` distinction:
  # widen the check and the accepted machine is rejected.
  FIND [[      ((and (pair? state) (or (stop-node? n) (finish-node? n)))]]
  REPLACE [[      ((and (pair? state) (or (stop-node? n) (finish-node? n) (error-node? n)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "a span open at an ERROR terminal is ACCEPTED")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: §16.2:900 does not see callback invocations"
  # The bullet names "explicit pauses OR event/decision callback invocations",
  # and the two halves are one arm here -- so dropping either is its own
  # mutation and its own case.
  FIND [[      ((and (pair? state) (or (pause-node? n) (callback-node? n)))]]
  REPLACE [[      ((and (pair? state) (pause-node? n))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "a CALLBACK invocation reachable with a span active is the same finding")

# --- Slice ③ task 8: the two holes the census reconciliation found -----------
#
# Both are Slice ③'s own: it made a span end a PARKED state and a span node a
# DECLARATION-REFERENCING one, and shipped neither check. Both were reachable
# rather than theoretical -- one machine verified clean and then answered
# `stopped` from `parser-finish!`, the other verified clean and then raised out
# of `normalize-machine`.
#
# A THIRD line was written and deleted here: an arm in `parked-eof-start`
# answering `(span-end-node-next n)`. Its mutation SURVIVED, because a span end
# is pure flow-through and `classify` joins over its `next` anyway, so starting
# the walk at the node and at its successor give the same verdict. Only the
# membership below does anything.

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a span end is not treated as a parked state"
  # §16.2:909 and §14:838. Without the disjunct, a machine whose span end
  # continues into a stop verifies clean -- and `parser-finish!` after a
  # span-data pause answers `stopped` from it, which is the outcome the whole
  # check exists to forbid.
  # Re-anchored by Milestone 7 Slice ⓪ (decision 0031): the §16.2:909
  # membership and `span-flow`'s copy are ONE `parked?` now, so this FIND
  # moved onto that procedure and the mutant reaches all three consumers
  # (pass 6, pass 7, `occupiable`). The decision it names is unchanged.
  FIND [[             (span-end-node? n)
             (symbol? (node-eof-target n)))))]]
  REPLACE [[             (symbol? (node-eof-target n)))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a span end continuing into a STOP is rejected .*one finding, at the span end -- expected ..eof-reachable-stop . cl.., got .."
)

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a span node's declaration cross-reference is not checked"
  # §16.2:901's span half. `make-span-start-node` stores its span as a bare
  # symbol and its own comment assigns this to the verifier; pass 7 cannot do it,
  # because the lattice is well defined over any symbol and treats the name
  # opaquely. Without the arm the machine verifies CLEAN and `normalize-machine`
  # raises `assertion-violation` -- a verified machine crashing the normalizer,
  # which §9.2:368 forbids in as many words.
  FIND [[                           ((or (span-start-node? n) (span-end-node? n))
                            (span-node-declaration-diagnostics sps n))]]
  REPLACE [[                           ((or (span-start-node? n) (span-end-node? n)) '())]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "an UNDECLARED span is rejected .*one finding per node -- expected ..missing-span-declaration . op. .missing-span-declaration . cl.., got .."
)

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: only a span START's declaration is checked, not a span end's"
  # The accessor split, which one node cannot witness: each kind carries its own
  # `-span` accessor and a fix reaching only one of them leaves the other
  # unchecked. The fixture places both and the pin names the SURVIVING half.
  FIND [[    (let ((s (if (span-start-node? n) (span-start-node-span n) (span-end-node-span n))))]]
  REPLACE [[    (let ((s (if (span-start-node? n) (span-start-node-span n) 'body)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "an UNDECLARED span is rejected .*got ..missing-span-declaration . op.."
)

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: an ABSENT label is treated as a nonportable one"
  # §16.2:886's LABEL clause, built by Milestone 5's close-out from design §4.12
  # item 2 -- an owner approval no slice had picked up.
  #
  # Milestone 6 Slice ⓪ made the clause TOTAL, and this mutant's blast radius
  # grew with it: every fixture in this lane carries `#f` labels, so an arm that
  # rejects absence now reddens nearly every case here, where before the fold it
  # reddened the two declaration-family cases alone. The Slice ⓪ sweep measured
  # the consequence -- NINE shipped pins in this pass are satisfied by this
  # mutant's output that were satisfied by nothing else before. By LABEL:
  #   "verify: default-error is promoted out of the benign tier"
  #   "verify: eof-reachable-stop is promoted into the benign tier"
  #   "verify: unresolved is promoted out of the benign tier"
  #   "verify: every :908 finding is labelled `case` regardless of which edge produced it"
  #   "verify: the :908 check reads only the first of a node's out-targets"
  #   "verify: node-out-targets returns the roles instead of the targets"
  #   "verify: the :909 walk does not start at the entry (D-1)"
  #   "verify: the entry being a finish terminal is not rejected (Slice ⓪b, OQ-2)"
  #   "verify: the zero-progress report is not gated on byte-reachability"
  # A nesting by construction, in the pass-fields-never-run shape, and not a
  # weakness in any of the nine: each still catches its own mutant for its
  # declared reason (0 self-failures), and this pin still catches this one.
  #
  # *** THIS IS THE ARM THAT GETS THE PIN, and the symbol and string arms
  # deliberately do NOT. *** Both of those call the shipped `valid-reason?`, so
  # every mutant of them is NESTED BY CONSTRUCTION inside the two reason mutants
  # above -- measured: the permissive `reason-char?` mutant reddens all four
  # label cases and more. A nesting by construction is a closed question, not a
  # coverage gap; their control is that each arm is asserted in BOTH directions
  # (a portable label accepted, a nonportable one rejected).
  #
  # This mutant is not nested: absence is decided before `valid-reason?` is
  # reached, so no reason mutant touches it. §10.3:506 and §10.4:517 both say
  # "optional diagnostic label", and an arm that rejected absence would redden
  # every fixture in the tree -- which is why the case it fails is the group's
  # own negative control rather than one of its rejections.
  FIND [[    (cond ((eq? l #f) #t)]]
  REPLACE [[    (cond ((eq? l #f) #f)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "both absent -- expected .., got .invalid-name invalid-name."
)

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the callback family stops checking its label, the span family does not"
  # The per-family split, which one family's fixture cannot witness: each arm
  # reads its own accessor. Pinned on the SHAPE case, and that choice is the
  # measurement -- the permissive reason mutant leaves the shape case GREEN,
  # because `valid-label?`'s `(else #f)` rejects an integer without consulting
  # the repertoire at all. That is this mutant's unique record.
  FIND [[                      (if (and (valid-name? (callback-declaration-name cd))
                               (valid-label? (callback-declaration-source-label cd)))]]
  REPLACE [[                      (if (and (valid-name? (callback-declaration-name cd))
                               #t)]]
  EXPECT_STATUS 1
  # `got .[)]` and not `got ..`: a bare two-wildcard tail also matches the
  # RESTRICTIVE reason mutant, which reddens this same case with a LONGER got
  # list. Requiring a literal `)` as the second character is what asserts the
  # list is EMPTY -- measured, `$` does not work here, because CMake's MATCHES
  # anchors at the end of the whole captured output rather than the line.
  EXPECT_OUTPUT_MATCHES "an integer on the callback -- expected .invalid-name., got .[)]"
)

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the span family stops checking its label, the callback family does not"
  # The other half of the per-family split. It had NO pin until the close-out
  # audit found the asymmetry: with the shape fixture's integer sitting only on
  # the callback, this mutant's single record -- the span label case -- was
  # wholly contained in the permissive `reason-char?` mutant's, so it could not
  # be pinned soundly. The fixture now carries an integer on the SPAN too, which
  # is the record no reason mutant can produce.
  FIND [[                      (if (and (valid-name? (span-declaration-name sd))
                               (valid-label? (span-declaration-source-label sd)))
                          #f]]
  REPLACE [[                      (if (and (valid-name? (span-declaration-name sd))
                               #t)
                          #f]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "an integer on the span -- expected .invalid-name., got .[)]"
)

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a callback declaration's NAME is no longer checked"
  # Not this slice's arm -- Slice ①b's. It shipped with no case and no pin while
  # `ir-tests.sps` asserted in prose that it was covered, and Milestone 5's
  # close-out found it while building the label clause beside it. BOTH families
  # get a pin, because each arm reads its own accessor and the earlier version of
  # this pass pinned only one of the two while the close note claimed both.
  FIND [[                      (if (and (valid-name? (callback-declaration-name cd))
                               (valid-label? (callback-declaration-source-label cd)))
                          #f]]
  REPLACE [[                      (if (and #t
                               (valid-label? (callback-declaration-source-label cd)))
                          #f]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the callback -- expected ..invalid-name . Bad.., got .[)]"
)

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a span declaration's NAME is no longer checked"
  FIND [[                      (if (and (valid-name? (span-declaration-name sd))
                               (valid-label? (span-declaration-source-label sd)))]]
  REPLACE [[                      (if (and #t
                               (valid-label? (span-declaration-source-label sd)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the span -- expected ..invalid-name . Body.., got .[)]"
)

# --- Milestone 6 Slice ⓪: §16.2:886's label clause made TOTAL -----------------
# Five conjuncts, one per arm the fold reached, each pinned on the carrier row
# whose integer label it stops rejecting. The fixtures use a wrong-SHAPE label
# because every one of these mutants is otherwise nested inside the permissive
# `reason-char?` mutant above: `valid-label?`'s `(else #f)` rejects an integer
# without consulting the repertoire, so the integer row is the record no reason
# mutant can produce. `got .[)]` asserts the diagnostic list is EMPTY.
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the machine's label is no longer checked"
  FIND [[(valid-label? (machine-source-label m))]]
  REPLACE [[#t]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "machine: integer label -- expected ..invalid-name . labm.., got .[)]")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a node's own label is no longer checked"
  # Every node-kind row reddens; the pin is one of them. The case-label conjunct
  # below keeps the byte-case and sequence-case rows GREEN under this mutant,
  # which is what separates the two pins.
  FIND [[(valid-label? (node-source-label n))]]
  REPLACE [[#t]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "stop: integer label -- expected ..invalid-name . done.., got .[)]")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a node's case labels are no longer checked"
  # The other half of the node arm: only the two case rows redden, under the
  # OWNING node's name, and every node-kind row stays green.
  FIND [[(for-all valid-label? (node-case-labels n))]]
  REPLACE [[#t]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "byte-case: integer label -- expected ..invalid-name . start.., got .[)]")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: an error declaration's label is no longer checked"
  FIND [[(valid-label? (error-declaration-source-label e))]]
  REPLACE [[#t]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "error-declaration: integer label -- expected ..invalid-name . rejected.., got .[)]")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a field's label is no longer checked"
  # `pass-fields`' arm, the fourth of the fold's four; it reports under the field
  # name and the CODE is `invalid-field-declaration`, so the expected list here
  # differs from the four `invalid-name` rows above. The Slice ⓪ sweep found
  # this pin also satisfied by "pass-fields is never run" -- a nesting BY
  # CONSTRUCTION shared with all eight pins inside that pass (the sweep names
  # them), not a collision this pin introduced: a pass that never runs produces
  # every failure any conjunct inside it can.
  FIND [[(valid-label? (uint-field-source-label f))]]
  REPLACE [[#t]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "uint-field: integer label -- expected ..invalid-field-declaration . count.., got .[)]")

# --- Milestone 6 Slice ① task 1: the thirteenth kind's nine verifier decisions --
# Decision 0030 items 5-7, one pin per arm the appendix names. Two pairs share a
# fixture and are separated by the `got`: the walk arm and the REPORT-set
# predicate both redden the value-terminated loop, one to an EMPTY list and the
# other to a list missing the counted node; the two halves of `classify`'s join
# each unreport a different fixture.
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a counted consume's next is not an out-edge"
  # The Slice ① sweep, the OTHER direction: this mutant satisfies three shipped
  # pins -- "verify: the :908 check is not gated on byte-reachability", "verify:
  # the :908 gate is vacuous, so no byte edge into a finish is ever rejected" and
  # "verify: the zero-width kinds report one role for all their edges" -- whose
  # regexes are case-label prefixes over the t2 and edge-role rows; dropping one
  # kind's out-edge is a per-kind subset of dropping the gate. Recorded, not
  # fixed here: those pins are pre-existing and coarse, and this pin's own record
  # is the entry fixture's, which none of them produce.
  FIND [[          ((counted-consume-node? n)
           (list (cons 'next (counted-consume-node-next n))))]]
  REPLACE [[          ((counted-consume-node? n) '())]]
  EXPECT_STATUS 1
  # RE-PINNED by Milestone 7 Slice ⓪. The old pin read the entry-stop fixture's
  # `got ..unreachable-node`, and the narrowing emptied it: the entry there is a
  # counted consume, so it is PARKED, and its walk visits `next`'s target
  # through `eof-successors` (0030 item 5) -- nothing in that machine is
  # unreachable any more. The decision this mutation names -- `next` is a BYTE
  # out-edge -- is still observable through the §16.2:908 block, which reads
  # `node-out-edges`: with the arm gone, the byte-reachable counted consume
  # whose `next` is the finish stops being `non-eof-into-finish` and is reported
  # `unreachable-node` instead. That is the measured record below, and it is
  # unique to this mutant across the pass.
  EXPECT_OUTPUT_MATCHES
    "§16.2:908 is gated on byte-reachability, for every kind .Slice ⓪b..a BYTE-reachable byte edge into a finish is rejected at its source node: each rejected exactly once, at `hop` -- expected .., got ..counted-consume .unreachable-node . fin...")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a counted consume's eof-target is read as absent"
  # The Slice ① sweep: also satisfied by "verify: the :909 start set enumerates a
  # kind instead of deriving the EOF route" and "verify: an EOF cycle through
  # pause continuations is not reported" -- both unpark or unreport the node this
  # arm's route parks, so the self-eof fixture goes empty under them too. By
  # construction: the route this arm answers is what the parked-set proxy reads.
  FIND [[          ((counted-consume-node? n) (counted-consume-node-eof-target n))]]
  REPLACE [[          ((counted-consume-node? n) #f)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a self-targeting eof-target is an EOF zero-progress cycle: eof-zero-progress-cycle, at the node -- expected ..eof-zero-progress-cycle . body.., got .[)]")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a counted consume's field reference is not checked"
  # The Slice ① sweep: also satisfied by "verify: pass-fields is never run" and
  # "verify: the operand half is never run" -- pass containment, the nesting every
  # pin inside pass-fields shares. By construction.
  FIND [[    (if (field-width-of fs (counted-consume-node-field n))]]
  REPLACE [[    (if #t]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "undeclared: reported under the node -- expected ..invalid-field-operand . body.., got .[)]")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a counted consume's next is invisible to the zero-progress walk"
  # The WALK half of 0030 item 7. Without it no node of the value-terminated
  # loop reaches itself, so the loop's record is EMPTY -- the `got` that
  # separates this pin from the REPORT-set pin below.
  # The Slice ① sweep: also satisfied by "verify: zero-progress detection never
  # fires" and "verify: the zero-progress WALK does not follow a zero-width node"
  # -- the value-terminated loop runs through a branch and an action, so any
  # mutant that breaks the walk at those kinds empties the same record. By
  # construction of the fixture, which needs all three edges to close.
  FIND [[              ((counted-consume-node? n) (list (counted-consume-node-next n)))]]
  REPLACE [[              ((counted-consume-node? n) '())]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "rejected: the three nodes of the loop -- expected ..zero-progress-cycle . br. .zero-progress-cycle . body. .zero-progress-cycle . dec.., got .[)]")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the zero-progress REPORT set excludes the counted-consume kind"
  # The REPORT half. The branch and the action still reach themselves through
  # the counted node's `next`, so the loop's record loses exactly the counted
  # node -- and the self-targeting-next fixture goes empty, which the walk pin
  # above also produces; the loop record is what separates them.
  FIND [[                                         (span-start-node? n) (span-end-node? n)
                                         (counted-consume-node? n))]]
  REPLACE [[                                         (span-start-node? n) (span-end-node? n))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "rejected: the three nodes of the loop -- expected ..zero-progress-cycle . br. .zero-progress-cycle . body. .zero-progress-cycle . dec.., got ..zero-progress-cycle . br. .zero-progress-cycle . dec..")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: eof-successors answers nothing for a counted consume"
  # `join-over` raises on an empty list, so the arm's loss is a RAISE out of
  # verification -- the accumulate-arm precedent's failure mode, pinned on the
  # raise the same way.
  # The Slice ① sweep, the OTHER direction: this mutant's raise satisfies the
  # shipped pin "verify: eof-terminal chains through a pause continuation", whose
  # regex is a case-raised record; the empty-join raise reaches that case too. The
  # shipped pin is the coarse one; recorded.
  FIND [[    (cond ((counted-consume-node? n) (list (counted-consume-node-next n)))
          (else (zero-width-successors n))))]]
  REPLACE [[    (cond ((counted-consume-node? n) '())
          (else (zero-width-successors n))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the flow-through zero-count stop at the ENTRY is rejected .0030 item 5.: case raised")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: classify drops the next half of the counted join"
  # A dispatch-shaped arm: the entry zero-count stop verifies CLEAN -- the hole
  # 0030 item 5 closes.
  # The Slice ① sweep: also satisfied by "verify: an EOF-reachable stop terminal
  # is accepted", "verify: default-error is promoted out of the benign tier",
  # "verify: eof-reachable-stop is promoted into the benign tier" and "verify: the
  # :909 walk does not start at the entry (D-1)" -- each unreports the entry
  # zero-count stop by a tier or start-set change that sits above this arm in the
  # walk. By construction.
  FIND [[                 (eof-verdict-join (dispatch-arm (counted-consume-node-eof-target n) path)
                                   (join-over (eof-successors n) path)))]]
  REPLACE [[                 (dispatch-arm (counted-consume-node-eof-target n) path))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the flow-through zero-count stop at the ENTRY is rejected .0030 item 5.: eof-reachable-stop, at the entry -- expected ..eof-reachable-stop . body.., got .[)]")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: classify drops the eof half of the counted join"
  # A zero-width-shaped arm: the self-targeting eof-target is no longer a cycle
  # but the stop behind `next`, a DIFFERENT wrong verdict from the arm's absence.
  # The Slice ① sweep: also satisfied by "verify: an eof-target cycle is
  # classified as a finish terminal" and "verify: cycle no longer outranks
  # eof-reachable-stop in the join" -- both turn the self-eof cycle into the stop
  # this half's absence turns it into. By construction (the join's ranking).
  FIND [[                 (eof-verdict-join (dispatch-arm (counted-consume-node-eof-target n) path)
                                   (join-over (eof-successors n) path)))]]
  REPLACE [[                 (join-over (eof-successors n) path))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a self-targeting eof-target is an EOF zero-progress cycle: eof-zero-progress-cycle, at the node -- expected ..eof-zero-progress-cycle . body.., got ..eof-reachable-stop . body..")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a parked counted consume is classified from its own name"
  # 0030 item 6's arm answering the node itself: the one-shot "length, body,
  # stop" grammar -- the design's first-draft rejection -- goes red.
  FIND [[           (counted-consume-node-eof-target n))
          (else (node-name n))))]]
  REPLACE [[           (node-name n))
          (else (node-name n))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the one-shot length, body, stop grammar is ACCEPTED .0030 item 6.: no diagnostics -- expected .., got .eof-reachable-stop.")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: pass 4 walks the retired relation instead of the occupiable one"
  # Decision 0031's own decision, as a mutant: `pass-reachability` reads
  # `occupiable` and not the walk that crosses an eof-target and then keeps
  # taking byte edges. The retired walk is reproduced inline because 0031
  # deleted the name.
  #
  # Comparison-caught, not raise-caught: the mutant verifies the whole `E
  # ->(eof) T ->(byte) Z` family clean, so the new group's three REJECTED
  # checks and its transitive one fail with `got ()` against a non-empty
  # expectation, and the three re-baselined cases fail with the pre-0031
  # verdicts.
  FIND [[    (let ((nodes (machine-nodes m)) (reached (occupiable m)))]]
  REPLACE [[    (let ((nodes (machine-nodes m)) (reached (map car (reach-from m (lambda (n) (append (node-out-targets n) (let ((t (node-eof-target n))) (if (symbol? t) (list t) '()))))))))]]
  EXPECT_STATUS 1
  # SUBSUMED except for one record, and that record is why the fixture exists.
  # Measured on this tree: every OTHER check this mutant reddens is also
  # reddened by "verify: reachability never reports an unreachable node", whose
  # suppression of the emission is a superset of this walk's widening on every
  # machine -- whole-set containment, so no family-only check can separate them.
  # The separating fixture is `an orphan beside the family`, which carries a
  # node dead under BOTH relations beside one dead only under the narrowing:
  # this mutant leaves the orphan reported, the emission mutant leaves nothing,
  # and the two `got` lists differ. AGENTS.md's count-don't-witness remedy.
  EXPECT_OUTPUT_MATCHES
    "reachability is the occupiable relation .decision 0031..an orphan beside the family, so the two ways of breaking pass 4 differ: both unoccupiable nodes, the family's and the orphan's -- expected ..unreachable-node . z. .unreachable-node . orphan.., got ..unreachable-node . orphan..")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the parked set loses the pause disjunct"
  # One of the two disjuncts that had NO pin before decision 0031 unified the
  # two hand-written copies: every shipped `(pause-node? n)` FIND sat in
  # `pass-zero-progress`, `zero-width-edges`, `node-out-edges`,
  # `parked-eof-start` or `span-transfer`, and none in the membership.
  # Measured: a byte-reachable pause stops starting a walk, so the counted
  # case whose stop sits behind a pause continuation loses its finding.
  FIND [[             (pause-node? n)
             (callback-node? n)]]
  REPLACE [[             (callback-node? n)]]
  EXPECT_STATUS 1
  # A CONJUNCTION of two whole records, because neither is unique alone: the
  # first is shared with "verify: an EOF-reachable stop terminal is accepted"
  # and the second with three cycle/out-target mutants, and the intersection of
  # those containing sets is empty. Measured; the `.*` joins two complete
  # records and never sits between an `expected` and its own `got`.
  EXPECT_OUTPUT_MATCHES
    "pause nodes .Slice 3..a byte-reachable pause into a stop would leak stopped through EOF .§16.2:909.: rejected -- expected a true value.*an EOF cycle through pause continuations is attributed to the pause .Slice ⓪..an eof-zero-progress-cycle is reported AT A PAUSE NODE: at least one, at a pause -- expected a true value")

# --- Milestone 7 Slice ①: the diagnostic record's four new fields ------------
# Eleven mutations. Each EXPECT_OUTPUT_MATCHES is measured from the staged
# mutant (never predicted) and pins a single-firing record: a case-name tail,
# a check label, and the measured got in full. The nine below run on the verify
# lane; the two census mutations (a path site made pathless, a path site
# relabelled out of the set) live in the diagnostic-census pass, because a
# mutation is witnessed only by its own SPEC lane's program.

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the stamping map is dropped, so severity and machine are #f"
  # Decision 0032 item 2: no map, no stamp. Separated from the constant and warning mutations below by its got #f (they give a symbol).
  FIND [[(map (lambda (d) (stamp-diagnostic d nm)) ds)]]
  REPLACE [[ds]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "non-machine severity -- expected error, got #f")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the machine stamp answers a constant instead of the machine name"
  # NOT #f (which would be a subset of the dropped-map mutant, subsumed by construction) -- a wrong NAME, so its got separates it. Pinned on the single-finding case so the record fires exactly once.
  FIND [[(nm (and (machine? machine) (machine-name machine)))]]
  REPLACE [[(nm (and (machine? machine) 'wrong))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "single machine stamp -- expected solo, got wrong")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the diagnostic severity is a warning rather than an error"
  # The `error` constant in stamp-diagnostic. Separable from the dropped map by got warning vs #f.
  FIND [[(diagnostic-edge d) 'error machine-name]]
  REPLACE [[(diagnostic-edge d) 'warning machine-name]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "non-machine severity -- expected error, got warning")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the EOF path is not reversed, so it runs from the node to the start"
  # Decision 0032 item 5's 'starting at the walk's start', as a first/last comparison. SITES=1: all six verdict sites route through this one helper (Task 4 Step 1).
  FIND [[(define (verdict v path) (list v (reverse path)))]]
  REPLACE [[(define (verdict v path) (list v path))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "eof-reachable-stop: path starts at the walk start -- expected start, got stop")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the EOF verdict join keeps the right operand on a tie"
  # Measured UNCAUGHT in all nine verify-driving programs before the widening (F10); the path is what makes decision 0032 item 5's tie-break observable. On the two-distinct-stop fixture the winner's path moves from s1 to s2.
  FIND [[(if (>= (eof-verdict-rank (car a)) (eof-verdict-rank (car b))) a b)]]
  REPLACE [[(if (> (eof-verdict-rank (car a)) (eof-verdict-rank (car b))) a b)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "path last is the LEFT branch's stop -- expected s1, got s2")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the zero-progress cycle path is empty"
  # Separated from 'zero-progress detection never fires' by the finding COUNT: this mutant keeps the finding with an empty path (got #f), the deleting one removes it and the case's 'is emitted' check fails instead.
  FIND [[((eq? (caar frontier) start) (cons start (reverse (cdar frontier))))]]
  REPLACE [[((eq? (caar frontier) start) '())]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "zero-progress-cycle: path starts at the walk start -- expected start, got #f")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a byte parent is not recorded, so the :908 path is truncated"
  # reach-from's parent alist. Caught only by a two-hop fixture whose source is not the entry (Task 6 Step 7); a source==entry fixture is unchanged.
  FIND [[(cons name parent)]]
  REPLACE [[(cons name #f)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "non-eof-into-finish \\(edge\\): path starts at the walk start -- expected start, got mid")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a span parent is not recorded, so span paths are truncated"
  # edge-parents' equivalent, kept separate from the byte map above because they are two maps and each reddens a family the other does not.
  FIND [[(cons (cons (car succ) (car frontier)) parents)]]
  REPLACE [[(cons (cons (car succ) #f) parents)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "invalid-span-state: path starts at the walk start -- expected start, got op2")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a two-name declarations list loses its second name"
  # invalid-span-callback's two-element list (decision 0032 item 3). Witness: the two-name declarations case.
  FIND [["span data callback is not of kind span-data" (list (span-declaration-name sd) dn)]]
  REPLACE [["span data callback is not of kind span-data" (list (span-declaration-name sd))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "span then callback -- expected \\(body ondata\\), got \\(body\\)")

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
#
# WHOLE-PASS PIN AUDIT, Milestone 3 Slice ③ Task 1. This pass declares no new
# mutation, but the task edits its SPEC-lane PROGRAM -- interpret-tests.sps
# gains three §16.2:894 diagnostic cases and its guard group is rewritten
# around a forged verification -- and a changed check set widens pins exactly
# as a changed mutation set does. Re-swept whole, in both directions:
# 12 mutations, 132 ordered pairs, every pin re-judged through
# byte_machine_mutation_verdict against every other mutant's captured output,
# plus a self-check that each pin still catches its own. No collisions, at
# HEAD or on the merge-base control (49c8cc4). The two guard pins below were
# the ones closest to being orphaned; see their own comment.

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/interpret-tests.sps")

# Re-anchored in Milestone 3 Slice ① Task 1: the interpreter's membership test is
# now `memv` over the canonical byte set, not `=` against a single exact byte.
# Same decision, same witness, same signature -- re-measured, not merely retyped.
byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.interpret.chez.source
  LABEL "interpret: dispatch matches every byte to the first case"
  FIND [[((memv byte (matcher-bytes (byte-case-matcher (car cs))))]]
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
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "finish with no input is idle completion -> finished: finished")

# Milestone 3 Slice ② Task 3: sequence prefix tracking through a compound
# current (name . path). interpret-tests.sps grows a "sequence prefix tracking
# through the interpreter" group, an AB/XY group naming the corrected §0 D1
# defect, the two internal guards (mirroring normal-ir-tests.sps's own two),
# an advance-mode group, and an EOF-through-a-compound group added specifically
# to give eof-target-of's compound branch a witness -- none of Step 1's own
# fixtures ever call parser-finish! while `current` is a compound. Re-measured
# the three pre-existing mutations above against the enlarged file: none of
# their pins moved (each still produces exactly its original FAIL text; the
# new groups add no line any of the three touches).
byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.interpret.chez.source
  LABEL "interpret: kind of a compound current is not reported as dispatch"
  # kind's `(if (pair? name) 'dispatch ...)` branch is what lets the runtime
  # keep reading bytes once `current` becomes a mid-sequence compound. Without
  # it, the compound is reported as a stop -- and the dispatch loop reaches
  # that check on the very same call that just built the compound (a
  # single-byte slice hits end-of-slice exactly there), so every multi-byte
  # sequence stops dead after its first byte. Comparison-caught.
  # Re-anchored in Slice ③: `kind`'s compound branch now has to separate TWO
  # compounds -- a mid-sequence (name . byte-list) from a span end's
  # (name . completion-pending) -- so the bare `'dispatch` line became an inner
  # `if`. The mutant is the same one: the mid-sequence compound stops reading.
  FIND [[            (if (completion? name) 'span-completion 'dispatch)]]
  REPLACE [[            (if (completion? name) 'span-completion 'stop)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "the full sequence stops after four bytes: stopped -- expected \\(stopped 1 1 4 #f\\), got \\(stopped 0 0 1 #f\\)")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.interpret.chez.source
  LABEL "interpret: seq-step filters live alternatives by position, not the accumulated path (§0 D1)"
  # This IS design §4.2's own defect, reproduced deliberately: §4.2 illustrates
  # the compound as (s . k), a bare position index. Replacing prefix?'s
  # full-path walk with a position-k comparison against the CURRENT byte alone
  # reproduces exactly that defect -- with AB and XY, after consuming A a
  # position index finds Y at position 1 in XY and accepts it, even though A
  # never matched X. The AB/AC fixture does not witness this (both share byte
  # 0, so a position check and a path check agree there); only AB/XY, which
  # diverges at position 0, can tell the two representations apart.
  # Comparison-caught. Pin sweep: this mutation's two failing checks are each
  # individually reproduced by a DIFFERENT sibling mutation alone (the
  # "mismatch" line by the kind-of-compound mutation above, byte-identical;
  # the "at offset 1" line by the mismatch-edge-not-taken mutation below,
  # byte-identical) -- neither line alone separates this mutation from its
  # neighbor. The pin below requires both, in this order, from the SAME run;
  # verified by matching it against every sibling mutation's own captured
  # output in this pass and confirming it resolves to this mutation alone.
  FIND [[                                (and (> (length bs) k) (prefix? new bs))))]]
  REPLACE [[                                (and (> (length bs) k) (= byte (list-ref bs k)))))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "A then Y mismatches rather than following the XY alternative: mismatch -- expected error, got stopped.*at offset 1 -- expected 1, got 2")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.interpret.chez.source
  LABEL "interpret: the mismatch edge is not taken when no alternative matches"
  # Disabling the null-hit clause (via an unreachable `#f` conjunct, the same
  # idiom normal-ir.sls's own guard mutations below use) falls through to the
  # final `else`, so a byte that matches nothing still gets folded into a new
  # compound state instead of routing to the declared mismatch edge -- the
  # mismatching byte is silently accepted into the sequence rather than
  # rejected. Comparison-caught; pinned to "pos 0", not "at offset 1" in the
  # AB/XY case, because "at offset 1" is byte-identical to the position-index
  # mutation's own output above (measured) and "pos 0" is this mutation's
  # alone (measured against every sibling in this pass).
  FIND [[          (cond ((null? hit)]]
  REPLACE [[          (cond ((and (null? hit) #f)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "a wrong byte at each position errors at that between-byte offset: pos 0 -- expected \\(error 0 0 0 unexpected-byte\\), got \\(need-input 1 1 1 #f\\)")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.interpret.chez.source
  LABEL "interpret: a completed alternative routes to another prefix instead of its declared target"
  # The `(pair? ends)` clause is what lands a fully-consumed alternative on
  # its OWN declared target; folding it into the same "extend the compound"
  # shape the `else` clause uses instead means a complete sequence never
  # actually terminates -- it just grows a compound state forever, so the
  # parser reports need-input after the sequence's own last byte rather than
  # stopping. Comparison-caught, pinned to the same four-byte fixture as the
  # kind-of-compound mutation above but discriminated by the "got" value
  # (need-input here, stopped there) -- verified distinct by direct
  # cross-check against that sibling's captured output.
  FIND [[                ((pair? ends) (cons (sequence-case-target (car ends)) 'advance))]]
  REPLACE [[                ((pair? ends) (cons (cons (sequence-dispatch-node-name n) new) 'advance))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "the full sequence stops after four bytes: stopped -- expected \\(stopped 1 1 4 #f\\), got \\(need-input 1 1 4 #f\\)")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.interpret.chez.source
  LABEL "interpret: eof-target-of does not dereference a compound back to its source node"
  # Passing `cur` straight through instead of extracting `(car cur)` sends a
  # (name . path) pair to `lookup`, whose `eq?` name comparison can never
  # match a pair against any declared node name -- lookup returns #f, and the
  # unguarded byte-dispatch-node-eof-target accessor then vector-refs #f.
  # Raise-caught, not comparison-caught: there is no representable "wrong but
  # valid" node name to fall back to here (every alternative extraction --
  # `cur` raw, `(cdr cur)`, an inverted pair? test -- feeds a non-node-name
  # into the same unguarded accessor chain), so every variant of this defect
  # crashes the same way. This is the value Task 2's review pattern warns
  # about (an internal value with no witness): none of the brief's own Step 1
  # fixtures ever call parser-finish! on a compound current, so this test
  # group was added specifically to give this value one.
  # Re-anchored by Slice ③ task 4: `eof-target-of` became a `cond` with a LOUD
  # else when the accumulate kind joined it -- §4.7 item 4's hazard, which was
  # live: the old two-way `if` fell through into `byte-dispatch-node-eof-target`,
  # a bare slot read, and on an accumulate node slot 4 is `digit-target`, a
  # symbol. The compound dereference this pin names is unchanged.
  FIND [[        (let ((n (lookup nodes (if (pair? cur) (car cur) cur))))]]
  REPLACE [[        (let ((n (lookup nodes cur)))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
  # The SIGNATURE moved with Slice ③ task 4, and moved in the right direction:
  # `eof-target-of` became a `cond` with a LOUD else (§4.7 item 4's hazard, which
  # was live -- the old two-way `if` fell through into a bare slot read, and on
  # an accumulate node that slot is `digit-target`, a symbol). Undereferencing a
  # compound now reaches that else and raises a CONTRACT VIOLATION rather than a
  # vector-ref type error. Same decision, same case, louder failure.
    "EOF mid-sequence routes through the sequence node's own eof-target, not the machine default: case raised -- Exception occurred with condition components")

# The same two internal invariants normal-ir.sls's own trie asserts (decision
# 0015 point 2), disabled the same way normal-ir.sls's own guard mutations
# disable them (an unreachable `#f` conjunct) -- see "the duplicate-alternative
# guard is dropped" and "the ambiguous-prefix guard is dropped" in Pass 35
# below for the shared idiom and its own rationale. check-raises cases are not
# vacuous (without the guard, the malformed hit set is silently accepted
# instead of raising) -- and per the fix-wave finding recorded in this task's
# report, the predicate is raises-interpret-assertion? (structured: who is
# 'interpret, message is the exact string), not (lambda (e) #t), so a mutation
# swapping which message either guard raises would also be caught; no such
# mutation is declared here because the two messages are literal string
# constants no earlier pass in this file already exercises swapping.
#
# Milestone 3 Slice ③ Task 1 correction: both witnesses now reach seq-step
# through a FORGED verification, and this paragraph used to describe them as
# built the ordinary way. §16.2:894's pass-sequence-ambiguity rejects both of
# these shapes at verify-machine and make-interpreted-machine refuses an
# unverified machine, so interpret-tests.sps's plain `interp` helper can no
# longer carry either machine this far. The two cases below build theirs with
# that program's `interp-unverified`, which wraps make-verification-result
# (from (byte-machine private ir)) around an ok? #t result the verifier would
# never produce -- exactly the caller-who-skips-verification these guards
# exist for, which is why they are defense-in-depth rather than dead. Measured
# after that rewrite: both mutants still fail with byte-identical details, so
# both FIND/REPLACE pairs and both pins below are unchanged.
byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.interpret.chez.source
  LABEL "interpret: the ambiguous-terminal-prefix guard is dropped"
  FIND [[                ((and (pair? ends) (pair? conts))
                 (assertion-violation 'interpret "ambiguous terminal prefix"
                                      (sequence-dispatch-node-name n)))]]
  REPLACE [[                ((and (pair? ends) (pair? conts) #f)
                 (assertion-violation 'interpret "ambiguous terminal prefix"
                                      (sequence-dispatch-node-name n)))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "an ambiguous terminal prefix is an assertion violation: AB\\|ABC -- expected a raise, but the thunk returned \\(stopped 1 1 2 #f\\)")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.interpret.chez.source
  LABEL "interpret: the duplicate-sequence-alternative guard is dropped"
  FIND [[                ((> (length ends) 1)
                 (assertion-violation 'interpret "duplicate sequence alternative"
                                      (sequence-dispatch-node-name n)))]]
  REPLACE [[                ((and (> (length ends) 1) #f)
                 (assertion-violation 'interpret "duplicate sequence alternative"
                                      (sequence-dispatch-node-name n)))]]
  # Pinned with the trailing " -- expected" immediately after "AB|AB", not
  # "AB|AB" alone: "AB|AB" is a literal substring of the sibling mutation's own
  # "AB|ABC", so an unanchored pin on the bare alternatives text would match
  # both mutants' output (measured). Requiring " -- expected" right after
  # forces the fifth character to be the case-name delimiter, not "C".
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "two identical alternatives are an assertion violation: AB\\|AB -- expected a raise, but the thunk returned \\(stopped 1 1 2 #f\\)")

# Value audit (task report): kind's and dispatch's own recognition of a BARE
# (not-yet-entered) sequence-dispatch-node name are two more decisions distinct
# from the compound-current branches above -- every seq-m fixture's entry is a
# bare symbol on its first byte, so disabling either one reproduces exactly
# Step 2's original red (the sixth node kind unhandled), but from two different
# sites. Measured to be genuinely separable, not merely assumed so: disabling
# kind's arm raises interpret's own byte-machine-contract condition (code
# internal, who* interpret, detail seq) before dispatch is ever reached;
# disabling dispatch's arm leaves kind correct, so dispatch falls into the
# byte-dispatch loop instead -- byte-dispatch-node-cases and sequence-dispatch-
# node-cases both read vector slot 2, so it silently reads the sequence's OWN
# case list, and byte-case-matcher (vector slot 1) then reads back the FIRST
# case's byte list as though it were a matcher, which matcher-bytes' own guard
# then refuses (code invalid-argument, who* matcher-bytes, detail matcher) --
# a different condition, from a different site, confirmed by direct comparison
# of the two captured outputs.
byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.interpret.chez.source
  LABEL "interpret: kind does not recognize a bare (not yet entered) sequence node"
  FIND [[                    ((sequence-dispatch-node? n) 'dispatch)]]
  REPLACE [[                    ((and (sequence-dispatch-node? n) #f) 'dispatch)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "the full sequence stops after four bytes: case raised.*code: internal.*who\\*: interpret.*detail: seq")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.interpret.chez.source
  LABEL "interpret: dispatch does not recognize a bare (not yet entered) sequence node"
  # RE-ANCHORED by Milestone 11 Slice ①: the bare-node `if` became a `cond` to
  # admit the keyword-table arm above the sequence arm. The edit this LABEL names
  # is unchanged -- neuter the sequence arm so a bare sequence node falls to the
  # else (the byte-dispatch loop, itself untouched), where matcher-bytes rejects
  # it -- and so is the witness.
  FIND [[               ((sequence-dispatch-node? n) (seq-step n '() byte))]]
  REPLACE [[               ((and (sequence-dispatch-node? n) #f) (seq-step n '() byte))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "the full sequence stops after four bytes: case raised.*code: invalid-argument.*who\\*: matcher-bytes.*detail: matcher")

# --- Milestone 6 Slice ① task 2: count-step, decision 0030 item 1's table ------
byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.interpret.chez.source
  LABEL "interpret: count-step tests exhaustion before the zero count"
  FIND [[          (if (= v 0)
              (cons 0 (counted-consume-node-next n))]]
  # The wrong order: exhaustion answered first, so a zero count over an empty
  # slice takes the EOF route instead of transitioning (decision 0030 item 1).
  REPLACE [[          (if (or (>= pos end) (= v 0))
              (cons 0 (if (>= pos end) #f (counted-consume-node-next n)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the zero-count test comes first: .0 . next. -- expected .0 . done., got .0 . #f.")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.interpret.chez.source
  LABEL "interpret: count-step commits (- end pos) instead of the min"
  FIND [[              (let ((k (min v (- end pos))))]]
  REPLACE [[              (let ((k (- end pos)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "surplus input commits the count only and continues: .3 . next. -- expected .3 . done., got .5 . #f.")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.interpret.chez.source
  LABEL "interpret: count-step never subtracts"
  FIND [[                (vector-set! fv slot (- v k))]]
  REPLACE [[                (vector-set! fv slot v)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "exact input completes the count and continues -- count completion wins: the count reaches zero -- expected 0, got 3")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.interpret.chez.source
  LABEL "interpret: count-step continues only when input remains"
  # The count-completion-wins mutant (decision 0030 item 2): `pos + k >= end`
  # tested before `k = v`, so the exact case parks instead of continuing.
  FIND [[                (cons k (if (= k v) (counted-consume-node-next n) #f))))))]]
  REPLACE [[                (cons k (if (and (= k v) (< (+ pos k) end)) (counted-consume-node-next n) #f))))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "exact input completes the count and continues -- count completion wins: .3 . next. -- expected .3 . done., got .3 . #f.")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 35: the normalizer (Milestone 1 Phase 3 Slice A) --------------------
#
# normal-ir-tests.sps pins the IR fingerprint of the one-byte machine (a golden
# value) and the structural decisions (entry id, transition sort, error-code
# resolution). This pass proves those checks are not vacuous. Verify command
# uses both library roots, an empty object guard, the normal-ir program.
#
# WHOLE-PASS PIN AUDIT, Milestone 3 Slice ③ Task 3 (the multi-alternative
# fixture). No mutation joined this pass. Three CASES and nine checks joined
# normal-ir-tests.sps -- the "two alternatives over a shared prefix lower to one
# trie" group, which lowers the §21.2 `version` production -- and adding a check
# widens every existing pin exactly as adding a mutation does (AGENTS.md), so
# the whole pass was re-measured in BOTH directions by the method Pass 33's
# audit blocks describe: apply each mutation to a staged copy, capture the SPEC
# lane's full stdout+stderr, then re-judge every pin through
# byte_machine_mutation_verdict against every OTHER mutant's captured output,
# plus a self-check that each pin still catches its own. 22 mutations, 462
# ordered pairs, ZERO collisions, and all 22 pins still catch their own mutant.
# "Ordered pairs" is n(n-1) throughout this file -- ordered pairs of DISTINCT
# mutants, one pin judged against one OTHER mutant's capture; the 22 self-
# checks are a separate count and are reported separately in the same sentence.
# (Corrected from 484 by the whole-branch review fix wave: 484 is 22 squared,
# which counts each pin against its own capture a second time under the pair
# heading. The sweep itself is unchanged -- every judgement was run, and the
# self-checks all passed -- only the arithmetic reported for it.)
# Control, because a colliding pass has to be told apart from an inherited one:
# the identical sweep run against the pre-change normal-ir-tests.sps
# (`git show c14bbc6:test/common/normal-ir-tests.sps` -- the base commit by
# name, because HEAD stopped resolving to the pre-change file the moment this
# group was committed) is also 462 pairs and also zero. Nothing inherited,
# nothing introduced.
#
# RE-MEASURED 2026-09-02, Slice ①b task 5, for the same reason and by the same
# method: SIX cases joined normal-ir-tests.sps (the field table group) and five
# mutations joined this pass, and a check widens every existing pin exactly as a
# mutation does. 30 pins, 870 ordered pairs, ZERO collisions, and all 30 pins
# still catch their own mutant. Control at 51fd5f3, this slice's baseline: 25
# pins, 600 pairs, also zero. Nothing inherited, nothing introduced -- this pass
# has now been collision-free across three separate audits.
#
# The new group is not inert under this pass's own mutants -- four of the 22
# redden it, measured on the same captures: "normal-ir: the trie does not merge
# alternatives sharing a byte" (state count 39 rather than 11 -- NOT the count
# for two separate chains, which is 18, measured by normalizing two eight-byte
# alternatives sharing nothing; 39 is trie-put's disabled equal-byte arm
# appending a second alist entry at every one of the seven shared levels, so
# the duplicated subtree compounds down the chain), "normal-ir: trie children
# are not kept ascending by byte", "normal-ir: internal prefix states do not
# append after the declared block", and "normal-ir: a terminal trie child
# consumes an id it should not" (state count 13). Named by LABEL, not by line
# number: this branch has already caught three stale line citations into this
# file.

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
  LABEL "normal-ir: a callback's required? flag is left out of the encoding"
  # Milestone 5 Slice ①b's FINAL REVIEW found this defect and this pins the fix.
  # The section originally encoded only the NAME while the emitter rendered name,
  # kind, required? and default-branch into ABI member 1 -- so two machines
  # differing only in `required?` shared fingerprint 4858454120852933155 and
  # emitted DIFFERENT libraries, one raising `missing-required-callback` from
  # make-parser and the other building. Decision 0019 item 2: a datum "must enter
  # the *encoding*, not merely be read from the source machine".
  #
  # A pin on the SECTION TAG was tried first and is deliberately not here: the
  # fix made the tag redundant for discrimination, because a callback record and
  # a span record no longer have the same shape, so collapsing the two tags is
  # UNCAUGHT and the suite said so. A mutation whose decision has been subsumed
  # gets retired, not weakened.
  FIND [[                     (put-u8 p (if (callback-declaration-required? c) 1 0))]]
  REPLACE [[                     (put-u8 p 1)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "EVERY part the ABI carries is in the fingerprint")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the FNV offset basis is changed"
  FIND [[(define fnv-offset 14695981039346656037)]]
  REPLACE [[(define fnv-offset 14695981039346656038)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "fingerprint -- expected 14095574568398596535, got 2974960947541485368")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the FNV prime is changed"
  FIND [[(define fnv-prime  1099511628211)]]
  REPLACE [[(define fnv-prime  1099511628212)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "fingerprint -- expected 14095574568398596535, got 16123314695484888068")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the byte is never mixed into the hash"
  FIND [[(* (bitwise-xor h (bytevector-u8-ref bv i)) fnv-prime)]]
  REPLACE [[(* h fnv-prime)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "fingerprint -- expected 14095574568398596535, got 1284000904169526997")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the entry id is hard-wired to node 0"
  FIND [[(entry (id-of (machine-entry machine)))]]
  REPLACE [[(entry 0)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "entry is the id of the entry node, not node 0: entry")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: dispatch cases are not sorted ascending by byte"
  # Re-anchored by Task 4's Pass 35 collision sweep: the bare "bytes" pin was
  # sound when written (one dispatch case, one FAIL line), but Task 4's
  # per-byte expansion runs through this SAME list-sort call, so reversing it
  # now also breaks two of the new byte-class checks ("bytes" is their check
  # name too) -- measured 3 FAIL lines in this mutant's own output where the
  # rule (AGENTS.md; "a sound pin resolves to exactly one (case, check) pair")
  # allows 1. Pinned to the full FAIL line of the ORIGINAL witness instead.
  FIND [[(list-sort (lambda (a b) (< (car a) (car b)))]]
  REPLACE [[(list-sort (lambda (a b) (> (car a) (car b)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "transitions are sorted ascending by byte: bytes -- expected \\(2 5\\), got \\(5 2\\)")

# Slice ① Task 4 (decision 0014): the per-byte expansion itself. The first
# keeps only each class's lowest byte, so a range of four bytes lowers to one
# transition instead of four. The second makes a vacuous class -- a
# complement whose canonical set is empty, e.g. the complement of the full
# range -- still emit one transition (on byte 0), which the vacuous-
# complement case (decision 0017 point 2) catches; matcher-bytes's own
# de-duplication (ir.sls, out of scope for this task) is untouched by either.
byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a byte class lowers to only its lowest byte"
  # Re-anchored by the whole-branch review (a9de657..c302cdd): the prior pin
  # "one transition per byte, ascending: transitions" was under-anchored --
  # the sibling mutation above ("dispatch cases are not sorted ascending by
  # byte") fails the SAME (case, check) pair, because Task 4's sweep
  # re-anchored that sibling's pin without checking it against the pin being
  # added here. Both mutants touch the transition list this pass's fixtures
  # build, so both redden the "a range lowers to one transition per byte,
  # ascending" case's "transitions" check.
  #
  # Re-measured both mutants' whole output on this SPEC lane and picked a
  # record that only THIS mutant produces: this mutant keeps one byte per
  # class, so the "a complement lowers to 254 transitions covering the
  # universe minus two" case's "count" check goes 254 -> 1; the sibling only
  # reverses order, so that case's length is unchanged (254 -> 254, "count"
  # passes) and it instead fails at check "first" (0 -> 255). Separable in
  # both directions: this pin does not occur anywhere in the sibling's
  # output, and the sibling's own pin ("transitions are sorted ascending by
  # byte: bytes -- expected (2 5), got (5 2)", on the "entry and transition
  # order" group) does not occur in this one's output either -- not because
  # this mutant skips that group (it runs there too, same as everywhere
  # else), but because that group's fixture ("two") uses only exact-byte
  # matchers, whose matcher-bytes is already a one-element list, so taking
  # the car of it is a no-op and the check still passes.
  FIND [[(bs (matcher-bytes (byte-case-matcher c)))]]
  REPLACE [[(bs (list (car (matcher-bytes (byte-case-matcher c)))))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "a complement lowers to 254 transitions covering the universe minus two: count -- expected 254, got 1")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a class matching no bytes still contributes a transition"
  # Re-anchored by Task 2 (decisions 0015/0016): the trie-lowering rewrite of
  # lower-machine's let* moved the byte-dispatch-node branch out of
  # `states (list->vector (let loop ...))` into its own `declared` binding, two
  # indent levels shallower. FIND is whitespace-sensitive by design (disambiguating
  # this closing `bs)))` from others), so it goes stale on ANY reindentation of
  # this branch even though the branch's own code is untouched by Task 2 -- update
  # the indentation rather than deleting the mutation.
  FIND [[                                                           bs)))]]
  REPLACE [[                                                           (if (null? bs) (list 0) bs))))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "zero transitions \\(decision 0017 point 2\\): none")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: an error node resolves to the declaration name, not its code"
  # Re-anchored by Task 2's pin sweep (decisions 0015/0016): the bare
  # "unexpected-byte" pin was sound when written, but Task 2's check-raises
  # cases ("the two unrepresentable trie shapes fail loudly") fail by printing
  # their whole returned normal-machine, whose error state carries this SAME
  # resolved code -- 'unexpected-byte is rej-decl's code in every seq-machine
  # fixture too -- so the bare substring now also occurs in two unrelated
  # mutants' output. Anchored to the full check line instead, which resolves
  # to the one (case, check) pair this mutation actually witnesses.
  FIND [[(error-declaration-code (car es)) (loop (cdr es))]]
  REPLACE [[(error-declaration-name (car es)) (loop (cdr es))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "code -- expected unexpected-byte, got rejected")

# Milestone 4 Slice ①a task 4 (decision 0019). Three decisions the encoding
# gained here, none of which had a witness before: the format version byte, the
# reserved field count, and the declaration's static reason.
#
# The version byte could not be pinned on its own text. `(put-u8 p 2)` occurs
# TWICE after the bump -- the version byte and the error-state tag -- and
# `(put-u8 p 1)` occurred three times before it, so a bare literal FIND reports
# SITES 2 or 3 and fails at declaration. Each FIND below carries enough
# surrounding text to be unique in the file.
byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the format version byte names the wrong format"
  # The obvious mutant -- put the byte back to 1 -- was measured and REJECTED: it
  # produces the identical one-byte digest as the shipped "FNV offset basis is
  # changed" mutation (2974960947541485368, confirmed by a control run of each).
  # The two are arithmetically equivalent at FNV-1a's first mix step, since
  # flipping the basis's low bit and flipping the first hashed byte's low bit
  # reach the same state, so neither pin could discriminate the other's mutant.
  # Version 3 has never been emitted and collides with nothing.
  FIND [[       (put-u8 p 2)
       (put-u32be p entry)]]
  REPLACE [[       (put-u8 p 3)
       (put-u32be p entry)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the IR fingerprint is the measured golden value: fingerprint -- expected 14095574568398596535, got 14172632155698282590")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the field count is written zero instead of the real count"
  # RE-ANCHORED, Slice ①b task 5. This pin was "the reserved field count is not
  # written" and FOUND `(put-u16be p 0)` -- ①a's literal zero. Task 5 replaces
  # that literal with the real count, which takes the old FIND to ZERO sites: a
  # pin killed BY CONSTRUCTION, not by an edit that could have been avoided, so
  # it is re-anchored in the same commit that kills it rather than deleted.
  #
  # The decision it names is unchanged -- the count byte must carry the table's
  # length -- but its witness had to change with it. It is pinned on the
  # two-field GOLDEN and could not be pinned on any of the inequality cases: with
  # the per-field records still written, zeroing the count leaves every
  # differing-field pair still unequal, so not one of them reddens. That is the
  # reason the slice measures a golden of its own instead of resting on the
  # "differ in fingerprint" family.
  FIND [[       (put-u16be p (length fields))]]
  REPLACE [[       (put-u16be p 0)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the IR fingerprint of a two-field machine is the measured golden value: fingerprint -- expected 5570336114768739383, got 14125028976508365705")

# Slice ①b task 5 adds FIVE more to this pass, one per remaining decision in the
# field record: its three components, the order the records are written in, and
# the slot number the table itself carries. Each is pinned on a DISTINCT golden
# value, all measured.

# Slice ② task 5 adds SIX for the two zero-width kinds' encoding. Each is pinned
# on a DISTINCT measured golden value, which is this file's shipped discipline
# for a new encode arm: an inequality pair cannot see a dropped count or a
# transposed pair, only a wrong value can.

# Slice ③ task 3 adds SIX for integer accumulate's lowering and encoding at
# tag 7. Each on its own measured golden value -- the four that share a CASE are
# separated by their distinct `got` digests, which is what an exact-value pin
# buys over an inequality.

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the accumulate encode tag collides with field-branch"
  FIND [[                (put-u8 p 7)]]
  REPLACE [[                (put-u8 p 6)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "integer accumulate in the normalized IR \\(Slice ③\\).a base-10 accumulate machine's fingerprint is the measured golden value: fingerprint -- expected 14659003778876959304, got 6374358628100294515")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: an accumulate node's base is dropped from the encoding"
  # The base decides which bytes are digits, so a generated parser observes it
  # and two machines differing only in it are different machines.
  FIND [[                (put-u8 p (normal-field-selector s))
                (put-symbol p (car (normal-field-arguments s)))]]
  REPLACE [[                (put-symbol p (car (normal-field-arguments s)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "integer accumulate in the normalized IR \\(Slice ③\\).a base-10 accumulate machine's fingerprint is the measured golden value: fingerprint -- expected 14659003778876959304, got 9369177108359133434")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the accumulate nondigit edge's MODE is dropped"
  # §10.6:567's non-digit edge is normally a reexecute, so the mode is the
  # whole point of it being an edge rather than a bare target.
  FIND [[                  (put-u8 p (mode->byte (cdr (cadr tg))))
]]
  REPLACE [[                  ]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "integer accumulate in the normalized IR \\(Slice ③\\).a base-10 accumulate machine's fingerprint is the measured golden value: fingerprint -- expected 14659003778876959304, got 13335447011493986019")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the accumulate overflow target is dropped"
  FIND [[                  (put-u32be p (caddr tg)))]]
  REPLACE [[                  )]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "integer accumulate in the normalized IR \\(Slice ③\\).a base-10 accumulate machine's fingerprint is the measured golden value: fingerprint -- expected 14659003778876959304, got 5178054717376752018")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: an accumulate node's EOF edge is read as absent"
  # §4.7 item 4's hazard, in the normalizer: `eof-of` reads
  # `byte-dispatch-node-eof-target`, a bare slot read with NO tag guard, so
  # handing it an accumulate node returns a plausible value from the wrong slot.
  # `acc-eof-of` exists so that cannot happen, and this pins it.
  FIND [[(let ((t (integer-accumulate-node-eof-target n)))]]
  REPLACE [[(let ((t #f))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "integer accumulate in the normalized IR \\(Slice ③\\).the EOF routing reaches the encoding: node routing -- expected 11426950116850452563, got 14659003778876959304")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: an accumulate state is not widened to the declared layout"
  # The check Slice ②'s `seq-state` miss earned, applied to the kind added
  # after it: total over the states a fixture produces, so a kind short of the
  # declared layout cannot hide behind a kind-guarded reader.
  FIND [[                                        (list (id-of (integer-accumulate-node-digit-target n))]]
  REPLACE [[                                        #f #f (list (id-of (integer-accumulate-node-digit-target n))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "integer accumulate in the normalized IR \\(Slice ③\\).a base-10 accumulate machine's fingerprint is the measured golden value: case raised -- Exception in car")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a sequence-dispatch state is not widened to the declared layout"
  # *** The defect Slice ②'s whole-branch review found. *** The vector went from
  # eight slots to eleven and `seq-state` -- which builds EVERY sequence-dispatch
  # node's state -- was missed. The miss was invisible: sequence states carry
  # kind `dispatch`, the only readers of slots 8-10 are kind-guarded, and all 92
  # lanes stayed green while four of six states in the sequence-node fixture were
  # three slots short of the layout this file declares.
  #
  # Its witness is deliberately TOTAL over the state kinds a fixture can produce.
  # A case naming one kind would have passed throughout, which is why the miss
  # survived task 5's own six mutations and its whole-pass sweep.
  FIND [[                        (seq-eof-of n) (eof-reason-of (seq-eof-of n))
                        #f #f #f))))]]
  REPLACE [[                        (seq-eof-of n) (eof-reason-of (seq-eof-of n))))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "every normalized state has the declared layout length.across every fixture and every state kind: no state is the wrong length -- expected \\(\\), got \\(8 8 8 8\\)")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the field-action and field-branch encode tags collide"
  # Tags 5 and 6. Two machines identical but for the kind must differ.
  FIND [[                (put-u8 p 5)]]
  REPLACE [[                (put-u8 p 6)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a field-action machine's IR fingerprint is the measured golden value: fingerprint -- expected 1386504585301950044, got 15366307625511038639")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a field node's selector is dropped from the encoding"
  # `store` and `add` differ only here, and both are observable to a generated
  # parser, so two machines the fingerprint calls identical would emit different
  # behaviour without this.
  # Anchored on the field-ACTION arm specifically: the two arms open with the
  # same two lines, so the bare pair resolves to two sites -- the
  # SITES-fails-both-directions trap again, and the third time this slice has hit
  # it. The tag byte above is what distinguishes them.
  FIND [[                (put-u8 p 5)
                (put-symbol p (normal-field-selector s))
                (put-operands p (normal-field-arguments s))]]
  REPLACE [[                (put-u8 p 5)
                (put-operands p (normal-field-arguments s))]]
  EXPECT_STATUS 1
  # Pinned on the GOLDEN, not on the inequality case: a bare "these two differ"
  # record is also broken by every mutation that makes ALL fingerprints equal --
  # measured, it collided with both "the FNV prime is changed" and "the byte is
  # never mixed into the hash". An exact value is the only pin an inequality
  # cannot be confused with.
  EXPECT_OUTPUT_MATCHES
    "a field-action machine's IR fingerprint is the measured golden value: fingerprint -- expected 1386504585301950044, got 7772389593278784940")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a field node's operand count is dropped"
  # Without the count the operand list has no boundary, so `(count 7)` followed
  # by the next record is indistinguishable from a three-operand list.
  FIND [[    (put-u16be p (length args))
]]
  REPLACE [[    ]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a field-branch machine's IR fingerprint is the measured golden value: fingerprint -- expected 13536979658827033743, got 16908098597654702240")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: an operand's kind is not tagged"
  # The reason each operand carries a tag byte: without it a field literally
  # named `7` and the constant 7 could share bytes, and two different machines
  # would share a fingerprint.
  FIND [[                (cond ((symbol? a) (put-u8 p 0) (put-symbol p a))]]
  REPLACE [[                (cond ((symbol? a) (put-symbol p a))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a field-action machine's IR fingerprint is the measured golden value: fingerprint -- expected 1386504585301950044, got 5142341432422259152")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: an absent error target is encoded as state zero"
  # The reason the error target is written with a PRESENCE TAG rather than a
  # sentinel id: `clear` cannot fail and carries no target, and state 0 is a
  # perfectly ordinary state id, so a sentinel would make those two machines
  # share a fingerprint.
  FIND [[                  (if e (begin (put-u8 p 1) (put-u32be p e)) (put-u8 p 0))))]]
  REPLACE [[                  (if e (put-u32be p e) (put-u32be p 0))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a field-action machine's IR fingerprint is the measured golden value: fingerprint -- expected 1386504585301950044, got 6902603388614441453")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a field branch's false target is not encoded"
  # §9.1:305 requires an explicit target for every possible result; an encoding
  # carrying only one of them describes a machine that does not exist.
  FIND [[                (put-u32be p (car (normal-field-targets s)))
                (put-u32be p (cdr (normal-field-targets s))))]]
  REPLACE [[                (put-u32be p (car (normal-field-targets s))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a field-branch machine's IR fingerprint is the measured golden value: fingerprint -- expected 13536979658827033743, got 7453673270761194114")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a field's name is dropped from the encoding"
  FIND [[                   (put-symbol p (car f))
]]
  REPLACE [[                   ]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the IR fingerprint of a two-field machine is the measured golden value: fingerprint -- expected 5570336114768739383, got 10230586532598973635")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a field's width is dropped from the encoding"
  FIND [[                   (put-u8 p (cadr f))
]]
  REPLACE [[                   ]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the IR fingerprint of a two-field machine is the measured golden value: fingerprint -- expected 5570336114768739383, got 8284907101070913187")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a field's initial value is dropped from the encoding"
  FIND [[                   (put-u64be p (caddr f)))]]
  REPLACE [[                   )]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the IR fingerprint of a two-field machine is the measured golden value: fingerprint -- expected 5570336114768739383, got 11089340831069462813")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: field records are written in reverse slot order"
  # Slot IS the record's position -- the slot number is deliberately not written
  # -- so record order is the whole of the slot assignment as far as the stream
  # is concerned, and a reversal is a different machine wearing the same bytes
  # everywhere else.
  FIND [[                 fields)]]
  REPLACE [[                 (reverse fields))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the IR fingerprint of a two-field machine is the measured golden value: fingerprint -- expected 5570336114768739383, got 3973801163924336519")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: every field is assigned slot zero"
  # The table's own slot number, which is what every consumer downstream indexes
  # by. Not witnessed by any fingerprint: the slot is not encoded, by design, so
  # this mutation moves no golden and the table assertion is its only witness --
  # the reason that assertion states each entry WHOLE, (name width initial slot),
  # rather than checking the length and the names.
  FIND [[                            slot)]]
  REPLACE [[                            0)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "slots are declaration indices, and the table carries name, width and initial: second -- expected \\(limit 16 65535 1\\), got \\(limit 16 65535 0\\)")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: an error state's reason is dropped from the encoding"
  # decision 0019 item 2: the reason must enter the ENCODING, not merely be
  # readable from the source machine, or two machines differing only in a reason
  # share a fingerprint and the fingerprint stops identifying what was emitted.
  FIND [[               ((error) (put-u8 p 2) (put-symbol p (normal-error-code s))
                        (put-reason p (normal-error-reason s)))]]
  REPLACE [[               ((error) (put-u8 p 2) (put-symbol p (normal-error-code s)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the IR fingerprint is the measured golden value: fingerprint -- expected 14095574568398596535, got 3064965786472452921")

# Milestone 2 Slice ②b-2 (Task 2): the dispatch eof routing is now part of the
# canonical encoding, so a dispatch state's resolved eof (the one-byte machine
# routes to the default-eof error, code 'eof) is mixed into the fingerprint.
# Dropping the default-eof code from the encoding moves the one-byte golden, so
# normal-ir-tests.sps's fingerprint case reddens against the re-baselined value.
byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a dispatch's default-eof routing is not encoded into the fingerprint"
  # Re-anchored in Milestone 4 Slice ①a task 4: the arm gained the declaration's
  # static reason (decision 0019 item 2), so the old FIND occurs zero times. The
  # decision this witnesses is unchanged -- the default-eof CODE must reach the
  # encoding -- so the REPLACE drops put-symbol and keeps the rest.
  # Re-anchored by Slice ③ task 3: the dispatch and accumulate arms wrote this
  # routing identically, taking every pin on it to SITES 2, so it was factored
  # into `put-eof-routing`. The decision and the expectation are unchanged; only
  # the text it sits on moved, and it now covers BOTH arms -- which is why each
  # arm's CALL stays its own separately mutable line.
  FIND [[        (begin (put-u8 p 1) (put-symbol p (cdr eof))
               (put-reason p reason))))]]
  REPLACE [[        (begin (put-u8 p 1)
               (put-reason p reason))))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "fingerprint -- expected 14095574568398596535, got 11628869637435983804")

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
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "fingerprint -- expected 13828870821654800916, got 15387434986975117383")

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
# mixing and error-code resolution -- the four that pin "14095574568398596535"
# -- node-eof routing, which pins "13828870821654800916", the pause lower arm,
# and the tag-value mutation below) moves the pause golden too, because the
# pause machine is hashed by the same algorithm. So the bare label said only
# "some fingerprint moved". What separates the siblings is the got value, which is
# distinct for each -- so both pause-encoding mutations below carry theirs.
# That is the same convention as the five above, applied where it is now
# measured to be necessary, and the re-baseline cost is real but bounded: a
# future IR-encoding move already re-baselines the pause golden itself
# (17903327606435836645, in normal-ir-tests.sps), and these two move with it.
byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the pause encode arm hashes tag and continuation"
  FIND [[((pause) (put-u8 p 4) (put-u32be p (normal-pause-target s)))]]
  REPLACE [[((pause) (put-u8 p 4))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "pause fingerprint -- expected 17903327606435836645, got 355204278510953480")

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
  EXPECT_OUTPUT_MATCHES "pause fingerprint -- expected 17903327606435836645, got 15135366215981961045")

# Milestone 3 Slice ② Task 2 (decisions 0015, 0016): the sequence prefix trie
# and its two-phase state-id allocation. Each mutation witnesses one decision
# the trie section rests on; the two-guard pair proves normal-ir-tests.sps's
# check-raises cases are not vacuous (without the guard, the malformed trie
# node is silently built and normalize-machine returns instead of raising).
byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the trie does not merge alternatives sharing a byte"
  # trie-put's equal-byte arm is what makes AB/AC share one root state instead
  # of the last-inserted alternative silently winning a byte-key tie (the
  # slice's whole reason to exist). Disabling only the "=" arm -- via a bound
  # no real byte value can cross -- leaves "<" and "else" untouched, so a
  # repeated byte falls through to "else" and is appended as a SECOND alist
  # entry instead of replacing the first: two (65 . _) transitions out of one
  # state where the trie should hold one.
  FIND [[          ((= b (caar cs)) (cons (cons b child) (cdr cs)))]]
  REPLACE [[          ((< b (- (caar cs) 1000000)) (cons (cons b child) (cdr cs)))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "a shared first byte becomes ONE transition into ONE state: root has a single transition -- expected \\(\\(65 4 advance\\)\\), got \\(\\(65 4 advance\\) \\(65 5 advance\\)\\)")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: trie children are not kept ascending by byte"
  # trie-put's "<" arm is the insert-before-if-less test that keeps a trie
  # node's children alist sorted ascending -- decision 0016 point 1's
  # pre-order depends on this, and decision 0014's ascending-by-byte sort
  # needs it too, on the lowered states. Flipping "<" to ">" sorts descending
  # instead: two alternatives diverging at position 0 (65, 88) come out of the
  # root in the wrong order.
  FIND [[          ((< b (caar cs)) (cons (cons b child) cs))]]
  REPLACE [[          ((> b (caar cs)) (cons (cons b child) cs))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "alternatives that diverge at position 0 get separate states: root -- expected \\(\\(65 4 advance\\) \\(88 5 advance\\)\\), got \\(\\(88 4 advance\\) \\(65 5 advance\\)\\)")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: internal prefix ids are allocated breadth-first, not depth-first"
  # allocate-prefix-ids's own recursion is what makes id assignment DEPTH-first
  # pre-order (decision 0016 point 1): before moving to the next sibling, it
  # fully numbers the current child's whole subtree. The replacement below is a
  # level-order (breadth-first) walk over a queue of trie nodes instead:
  # every node's DIRECT interior children get consecutive ids before any
  # grandchild does. Over the A->{B terminal, C->D}, X->Y fixture this still
  # gives A id 5 (both walks visit the root's own children first), but C (A's
  # nested child) and X (A's root-level sibling) swap: depth-first finishes
  # A's subtree before X (C=6, X=7); breadth-first finishes the whole root
  # level before descending (X=6, C=7).
  FIND [[  (define (allocate-prefix-ids t next)
    (let walk ((cs (trie-children t)) (acc '()) (next next))
      (if (null? cs) (values (reverse acc) next)
          (let ((child (cdar cs)))
            (if (trie-interior? child)
                (let-values (((sub next2) (allocate-prefix-ids child (+ next 1))))
                  (walk (cdr cs) (append (reverse sub) (cons (cons child next) acc)) next2))
                (walk (cdr cs) acc next))))))]]
  REPLACE [[  (define (allocate-prefix-ids t next)
    (let loop ((queue (list t)) (next next) (acc '()))
      (if (null? queue) (values (reverse acc) next)
          (let* ((cs (trie-children (car queue)))
                 (interior (filter (lambda (kv) (trie-interior? (cdr kv))) cs)))
            (let assign ((items interior) (next next) (acc acc) (kids '()))
              (if (null? items)
                  (loop (append (cdr queue) (reverse kids)) next acc)
                  (let ((child (cdr (car items))))
                    (assign (cdr items) (+ next 1) (cons (cons child next) acc) (cons child kids)))))))))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "depth-first pre-order, not breadth-first: root -- expected \\(\\(65 5 advance\\) \\(88 7 advance\\)\\), got \\(\\(65 5 advance\\) \\(88 6 advance\\)\\)")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: internal prefix states do not append after the declared block"
  # prefix-blocks threads id allocation starting at declared-count, which is
  # decision 0016 point 1's "declared nodes keep their declaration index; every
  # internal state appends after the whole declared block". Starting at 0
  # instead collides internal ids with the declared nodes' own ids (0 is
  # 'seq's own id), corrupting the positional states vector.
  FIND [[            (let loop ((ns nodes) (next declared-count) (acc '()))]]
  REPLACE [[            (let loop ((ns nodes) (next 0) (acc '()))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "the declared node keeps its declaration index and the prefix states append: root -- expected \\(\\(1 3 advance\\)\\), got \\(\\(1 0 advance\\)\\)")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a terminal trie child consumes an id it should not"
  # allocate-prefix-ids's non-interior branch is what makes a TERMINAL child
  # (an alternative's own byte-run end) consume no id -- its byte routes
  # straight to the alternative's declared target, never to a lowered prefix
  # state. Making it allocate one anyway grows the four-byte single-alternative
  # fixture from 6 states to 7 and shifts every id after the first terminal.
  FIND [[                (walk (cdr cs) acc next))))))]]
  REPLACE [[                (walk (cdr cs) (cons (cons child next) acc) (+ next 1)))))))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "three declared nodes plus three internal prefix states: count -- expected 6, got 7")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the duplicate-alternative guard is dropped"
  # trie-insert's bs-null branch is where an alternative's OWN path ends;
  # trie-terminal already set there means some earlier alternative ended at
  # the exact same byte run (decision 0015 point 2's unrepresentable shape,
  # direction 1). Disabling this guard silently overwrites the earlier
  # target instead of raising, so "two identical alternatives are an
  # assertion violation" (normal-ir-tests.sps) goes from a raise to a normal
  # return -- proving that check-raises case is not vacuous.
  FIND [[          (when (trie-terminal t)
            (assertion-violation 'normalize-machine "duplicate sequence alternative" target))
]]
  REPLACE [[          (when #f
            (assertion-violation 'normalize-machine "duplicate sequence alternative" target))
]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "two identical alternatives are an assertion violation: AB\\|AB -- expected a raise, but the thunk returned")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the ambiguous-prefix guard is dropped"
  # trie-insert's bs-non-null branch is where a LATER alternative's path tries
  # to descend past a node an earlier alternative already terminated at
  # (decision 0015 point 2's unrepresentable shape, direction 2 -- AB is a
  # strict prefix of ABC). Disabling this guard lets insertion continue,
  # silently producing a trie node that is both terminal and interior; later
  # code treats it as interior only, so the earlier alternative's target
  # becomes unreachable with nothing failing -- exactly the miscompile the
  # slice exists to prevent -- instead "AB|ABC" goes from a raise to a normal
  # return.
  FIND [[        (begin
          (when (trie-terminal t)
            (assertion-violation 'normalize-machine "ambiguous terminal prefix" target))
]]
  REPLACE [[        (begin
          (when #f
            (assertion-violation 'normalize-machine "ambiguous terminal prefix" target))
]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "an ambiguous terminal prefix is an assertion violation: AB\\|ABC -- expected a raise, but the thunk returned")

# Fix wave 1, Important 2: seq-state's own `id` argument (the internal prefix
# state's own state-id field, distinct from its POSITION in the states
# vector) had no witness -- normal-state-id was asserted for every declared
# state but no internal one, so the `internal` binding's call site could pass
# the wrong id and nothing would notice (every other check reads a state by
# its vector position, never its own id field). normal-ir-tests.sps now
# asserts normal-state-id on the four-byte fixture's three internal states
# (ids 3, 4, 5) and the depth-first fixture's three (ids 5, 6, 7). Zeroing
# every internal state's id (the reviewer's own mutation) collides ids 3, 4
# and 5 all onto 0. Anchored to "id 4", not "id 3": id 3 also reads
# "expected 3, got 0" in the sibling "internal prefix states do not append
# after the declared block" mutation's own output above (that mutation
# renumbers the whole internal block starting at 0, so ITS first internal
# state's id is also, coincidentally, 0) -- measured by running both mutants
# and cross-checking pairwise, per the both-directions pin sweep.
byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: an internal prefix state's own id field is wrong"
  # Re-anchored by Slice ③: `internal` now walks TWO families, so the prefix arm
  # sits inside an `if` on the block's kind and its tail moved.
  FIND [[(map (lambda (kv) (seq-state n (car kv) ids (cdr kv))) ids)]]
  REPLACE [[(map (lambda (kv) (seq-state n (car kv) ids 0)) ids)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "internal prefix states carry their own id, not a placeholder: id 4 -- expected 4, got 0")

# Fix wave 1, Minor 3: trie-insert's bs-null branch carries a THIRD guard --
# (when (trie-interior? t) ...) -- distinct from the bs-non-null branch's own
# trie-terminal guard the "ambiguous-prefix guard is dropped" mutation above
# witnesses. It fires only when a LONGER alternative is inserted BEFORE its
# own prefix (every fixture above inserts short-first, so nothing reached this
# clause). normal-ir-tests.sps gains a reverse-order fixture (ABC before AB)
# to witness it; disabling the guard lets that fixture's ambiguous prefix
# build silently instead of raising.
byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the bs-null-branch ambiguous-prefix guard is dropped"
  FIND [[          (when (trie-interior? t)
            (assertion-violation 'normalize-machine "ambiguous terminal prefix" target))
]]
  REPLACE [[          (when #f
            (assertion-violation 'normalize-machine "ambiguous terminal prefix" target))
]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "an ambiguous terminal prefix inserted in reverse order is also caught: ABC\\|AB -- expected a raise, but the thunk returned")

# Milestone 5 Slice ② tasks 3+5: the callback state's encoding. Decision 0019
# item 2 is what these witness, and Slice ①b shipped its converse -- a callback
# declaration encoded by NAME alone, so two machines differing in `required?`
# shared a fingerprint and emitted different libraries. The separability group
# in normal-ir-tests.sps varies one encoded part at a time; these three prove
# that group is not vacuous.
byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the callback encode tag collides with field-action"
  # Pinned on the GOLDEN, not on a pairwise inequality: a tag change moves every
  # callback fingerprint together, so every inequality in that group survives it
  # and only a fixed value can see it. The same argument the accumulate tag's
  # own mutation makes one kind earlier.
  FIND [[               ((callback)
                (put-u8 p 10)]]
  REPLACE [[               ((callback)
                (put-u8 p 5)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the base machine verifies and normalizes: fingerprint -- expected 4714737223744993991")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a callback node's resolved slot is dropped from the encoding"
  # The slot is what the ABI carries -- the emitted arm indexes `cbv` with it --
  # so two machines whose nodes invoke different declarations would share a
  # fingerprint and call different procedures. The following line rides along in
  # both halves because the runner refuses an empty REPLACE.
  FIND [[                (put-u16be p (normal-field-selector s))
                (let ((tg (normal-field-targets s)))]]
  REPLACE [[                (let ((tg (normal-field-targets s)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "each part varied alone moves the fingerprint: and every one moved the fingerprint -- expected \\(\\), got \\(slot\\)")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a callback branch's KEY is dropped from the encoding"
  # Only the targets would remain, so a machine whose declaration renames a key
  # -- and whose emitted arm therefore matches a different returned symbol --
  # would share a fingerprint with the original.
  FIND [[                              (put-symbol p (car b))
                              (put-u32be p (cdr b)))]]
  REPLACE [[                              (put-u32be p (cdr b)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "each part varied alone moves the fingerprint: and every one moved the fingerprint -- expected \\(\\), got \\(branch-key\\)")

# Milestone 5 Slice ③ task 4: the span states' encoding, and the SECOND family of
# internal states -- the one that makes decision 0026 item 1 non-inert.
byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the span-end encode tag collides with span-start"
  # Pinned on the GOLDEN, for the reason the callback tag's own mutation states:
  # a tag change moves every span fingerprint together, so every pairwise
  # inequality in that group survives it and only a fixed value can see it.
  FIND [[               ((span-end)
                (put-u8 p 12)]]
  REPLACE [[               ((span-end)
                (put-u8 p 11)]]
  EXPECT_STATUS 1
  # RE-MEASURED at task 8: the golden moved when the span fixture's tail had to
  # route through a dispatch -- its span end continued straight into a stop, and
  # a span end is a parked state, so §16.2:909 now rejects that shape.
  EXPECT_OUTPUT_MATCHES "the base machine verifies and normalizes: fingerprint -- expected 8308402030897048213")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a span node's slot is not resolved against the declarations"
  # The slot is what the ABI carries, so two machines whose nodes name different
  # spans would share a fingerprint and open different spans.
  #
  # Anchored on the RESOLUTION rather than on one arm's `put-u16be`: dropping the
  # span-start arm's write alone leaves the span-end's, so the `span-slot` row --
  # which moves BOTH nodes -- still separates and only the golden would notice,
  # which is the tag mutation's pin. Collapsing the resolution moves the row
  # itself, and the two mutations stay distinguishable.
  FIND [[                      ((eq? (span-declaration-name (car sp)) nm) i)]]
  REPLACE [[                      ((eq? (span-declaration-name (car sp)) nm) 0)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "and every one moved the fingerprint -- expected \\(\\), got \\(span-slot\\)")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a span end lowers to a fused state instead of two"
  # Decision 0026 item 2: §14:838 resumes "at the next undelivered substep",
  # which a fused state cannot express because it has ONE resume point. Caught
  # by the state count, which is what makes the claim checkable rather than
  # asserted.
  FIND [[                      ((span-end-node? n)
                       (loop (cdr ns) (+ next 1) (cons (list n 'span-end #f next) acc)))]]
  REPLACE [[                      ((and #f (span-end-node? n))
                       (loop (cdr ns) (+ next 1) (cons (list n 'span-end #f next) acc)))]]
  EXPECT_STATUS 1
  # A RAISE, and it is the decision's own consequence rather than an incidental
  # crash: with no block allocated, `completion-id-of` cannot answer and says so
  # by name. There is no opposite constant to try.
  EXPECT_OUTPUT_MATCHES "span end has no continuation state")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the debug map skips the second internal family"
  # §17:963's map must stay TOTAL, and §13:820 requires the public parser state
  # to name the source span node rather than a generated continuation. Slice ②
  # raised the stakes: the map crosses the seam as ABI payload member 2, so an
  # incomplete one is an index error in the generated lane.
  FIND [[                                        (list (cons ids (node-name n))))))]]
  REPLACE [[                                        '())))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "every state id has a source name -- expected \\(\\), got \\(6\\)")

# --- Milestone 6 Slice ① task 2: the counted-consume state's lowering and encoding
byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the counted-consume encode tag collides with span-completion"
  FIND [[                (put-u8 p 14)]]
  REPLACE [[                (put-u8 p 13)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "a counted-consume machine's fingerprint is the measured golden value: fingerprint -- expected 8698736890881894294, got 16257961618954127535")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a counted consume's field name is dropped from the encoding"
  # The accumulate arm writes the same put-symbol line; the FIND is unique
  # through its second line, which only this arm has.
  # The Slice ① sweep: the three drift-pair pins here ("… field name …",
  # "… successor …", "… EOF routing …") are also satisfied by "normal-ir: the
  # FNV prime is changed" and "normal-ir: the byte is never mixed into the hash",
  # which degenerate the hash so every pair collides; and the EOF-routing pin by
  # "normal-ir: a counted consume's EOF edge is read as absent", which makes the
  # node-routed variant encode as the base. By construction of a drift pair: any
  # mutant that collapses two fingerprints satisfies a pin that expects them apart.
  FIND [[                (put-symbol p (car (normal-field-arguments s)))
                (put-u32be p (car (normal-field-targets s)))]]
  REPLACE [[                (put-u32be p (car (normal-field-targets s)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the field, the successor and the EOF routing each reach the encoding: the field differs -- expected a true value")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a counted consume's successor is dropped from the encoding"
  FIND [[                (put-u32be p (car (normal-field-targets s)))
                (put-eof-routing p (normal-dispatch-eof s) (normal-error-reason s)))
               ((field-branch)]]
  REPLACE [[                (put-eof-routing p (normal-dispatch-eof s) (normal-error-reason s)))
               ((field-branch)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the field, the successor and the EOF routing each reach the encoding: the successor differs -- expected a true value")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a counted consume's EOF routing is dropped from the encoding"
  FIND [[                (put-u32be p (car (normal-field-targets s)))
                (put-eof-routing p (normal-dispatch-eof s) (normal-error-reason s)))
               ((field-branch)]]
  REPLACE [[                (put-u32be p (car (normal-field-targets s))))
               ((field-branch)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the field, the successor and the EOF routing each reach the encoding: the EOF routing differs -- expected a true value")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a counted consume lowers a second successor"
  FIND [[                                        (list (id-of (counted-consume-node-next n))))))]]
  REPLACE [[                                        (list (id-of (counted-consume-node-next n)) 0))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "one successor -- expected 1, got 2")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a counted consume's EOF edge is read as absent"
  # `count-eof-of` reads the machine default for every node, so the node-routed
  # variant encodes exactly like the base machine -- a predictable `got`.
  FIND [[                           (let ((t (counted-consume-node-eof-target n)))]]
  REPLACE [[                           (let ((t #f))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "node EOF routing -- expected 11703601680155498763, got 8698736890881894294")

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
  LABEL "compile: emitted exec loses a Milestone 5 reserved parameter"
  # Milestone 5 Slice ①a task 6, closing a gap the slice's own planning MEASURED:
  # across all 366 declarations, no FIND anchored on the emitted `exec` parameter
  # list, so a change to the emitted signature was invisible to this suite. The
  # plan proposed carrying that to Slice ②, on the ground that a pin belongs with
  # the slice that gives the parameters meaning. It is closed HERE instead,
  # because a demonstrated gap gets closed rather than documented, and the
  # witness already exists: compile-tests.sps's "exec carries its three reserved
  # parameters" is the only assertion naming that line as TEXT, and the only one
  # that runs in this mutation's own SPEC lane. It is not the only thing in the
  # tree that would notice -- the four goldens carry the same line at `:5` and
  # the determinism lanes compare them byte for byte -- and an earlier draft of
  # this comment said "the only assertion in the tree", which was false.
  #
  # Dropping `cbv` -- the last parameter -- rather than mangling the whole list:
  # a caught-by-COMPARISON failure of the signature assertion, not a raise from
  # some later arity mismatch, which is what AGENTS.md prefers and what makes the
  # record name this decision.
  FIND [["  (define (exec state offset bv start end finish? fieldv psr cbv)\n"]]
  REPLACE [["  (define (exec state offset bv start end finish? fieldv psr)\n"]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "exec carries its three reserved parameters: the full parameter list")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: a non-empty option list is accepted"
  FIND [[(unless (null? options)]]
  REPLACE [[(unless #t]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "a non-empty option list is refused: refused")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: an invalid machine is reported as compiled ok"
  FIND [[(if (verification-ok? v)]]
  REPLACE [[(if #t]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "an invalid machine does not compile and carries diagnostics: not ok")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: an unverified compilation is rendered anyway"
  FIND [[(unless (compilation-ok? compilation)]]
  REPLACE [[(unless #t]]
  # The detail is part of the pin, not decoration: the invalid-machine mutation
  # above breaks this same check, but there render RETURNS bytes ("expected a
  # raise, but the thunk returned ..."), while dropping the guard here makes it
  # raise the wrong object. Without the detail the two are indistinguishable.
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "render refuses a compilation that failed verification: not ok -- raised object did not satisfy the predicate")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: the binding grammar check is dropped"
  # Re-anchored by Milestone 6 Slice ⓪: the grammar is one call into names.sls
  # now, so the mutant drops that call rather than the length-and-first-char
  # half of an inline loop. Same observation -- a grammar-invalid binding
  # renders -- and the same expectation.
  FIND [[(and (portable-name? sym)]]
  REPLACE [[(and #t]]
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
  FIND [[(string-append "(loop (+ pos 1) " (number->string target) " (+ off 1) (quote boundary))")]]
  REPLACE [[(string-append "(loop pos " (number->string target) " off (quote byte))")]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "advance arm")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: the reexecute fallback is lowered as an advance"
  FIND [[(string-append "(loop pos " (number->string target) " off (quote byte))")]]
  REPLACE [[(string-append "(loop (+ pos 1) " (number->string target) " (+ off 1) (quote boundary))")]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "the accepted byte advances and the fallback reexecutes: fallback")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: the error arm omits the resolved code"
  # Re-anchored in Slice ①a task 5: the arm renders a parser-error record, so
  # the resolved code now reaches it through the errs-table INDEX rather than as
  # a rendered symbol. Dropping the index to a constant 0 makes every error
  # report the first declaration's code -- the same decision, the same failed
  # comparison in the same case.
  FIND [[(number->string (index-of (normal-error-code s)
                                                  (normal-error-reason s))) ") (quote "]]
  REPLACE [["0" ") (quote "]]
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
  # Re-anchored in Slice ①a task 5: the default-eof arm renders a parser-error
  # record, so the resolved code reaches it through the errs-table index.
  # NOT "0": the default-eof declaration IS index 0 in every shipped fixture, so
  # that REPLACE is a no-op and the mutation shipped UNCAUGHT on its first run.
  # Index 1 is the `rejected` declaration, so the arm reports the wrong code.
  FIND [[(number->string (index-of (cdr eof) reason)) ") (quote " (symbol->string name)]]
  REPLACE [["1" ") (quote " (symbol->string name)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "eof routes to the default-eof error")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: the exhausted dispatch does not branch on finish?"
  # Anchored on the DISPATCH arm's own preceding line: Slice ③'s accumulate arm
  # renders the same `(if finish?` guard, so a bare FIND matches twice.
  # Re-anchored by Slice ③ task 4 onto `render-exhausted-preamble`: the dispatch
  # and accumulate arms rendered this identically, and no anchor separated them
  # because the two preambles ARE the same decision. The pin now covers both.
  FIND [[     "       (if (>= pos end)\n"
     "           (if finish?\n"]]
  REPLACE [[     "       (if (>= pos end)\n"
     "           (if #f\n"]]
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
  # Re-anchored by Milestone 5 Slice ②: the callback arm's own pause branch
  # renders the same outcome constructor, so the bare form now occurs twice.
  # Anchored on the PAUSE ARM's `") (` prefix, which the callback arm -- whose
  # branch opens `((pause) (` inside a `case` -- does not share.
  FIND [[") (byte-machine-make-feed-outcome/v1 (quote paused) pos #f "]]
  REPLACE [[") (byte-machine-make-feed-outcome/v1 (quote stopped) pos #f "]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "pause arm p1 -- expected \"paused 2\", got \"stopped 2\"")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: the pause arm's next-state is the continuation"
  FIND [[(number->string (normal-pause-target s)) " off))\n"))]]
  REPLACE [[id " off))\n"))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "pause arm p1 -- expected \"paused 2\", got \"paused 1\"")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: member 0 is emitted empty regardless of the declarations"
  # Slice ①b task 6 fills decision 0019 item 3(b). The zero-field rendering is
  # already pinned by the case one above this one -- `(quote #(#()))`, unchanged
  # since ①a -- so what needed a mutation is the NON-empty rendering, which no
  # existing check could have noticed.
  FIND [[           (fields (let loop ((fs (normal-machine-fields normal)) (acc "")]]
  REPLACE [[           (fields (let loop ((fs '()) (acc "")]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a field-declaring machine renders its declarations in member 0: pairs in slot order -- expected a true value")


# --- Milestone 6 Slice ① task 3: the structural witness for §25:1607 ------------
byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: the emitted counted arm renders a per-byte self-loop"
  # Behaviour-identical: one byte per iteration through the same state, the count
  # decremented each time, the zero-count and exhausted clauses unchanged -- so
  # every behavioural lane passes, and within this SPEC only the datum walk over
  # the emitted arm (no `min`, a `(+ pos 1)`) can see it -- the committed counted
  # golden, being bytes, would see the changed text too. That is design §4.7's
  # argument: a differential is blind to it by construction.
  FIND [[            "                (let ((n (min v (- end pos))))\n"
            "                  (vector-set! fieldv " slot " (- v n))\n"
            "                  (if (= n v)\n"
            "                      (loop (+ pos n) " (num next-id) " (+ off n) (quote boundary))\n"
            "                      (byte-machine-make-feed-outcome/v1 (quote need-input) (+ pos n) #f " id " (+ off n))))))))\n")))]]
  REPLACE [[            "                (begin (vector-set! fieldv " slot " (- v 1))\n"
            "                       (loop (+ pos 1) " id " (+ off 1) (quote boundary)))))))\n")))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the emitted arm applies min exactly once and never advances by one: exactly one min -- expected 1, got 0")

# Milestone 7 Slice ④ Task 9 Step 4: the §16.2:910 witness's two pins. Each drops a
# quote wrapper in one render-state-arm arm, so a DECLARED name is emitted in
# identifier position; the identifier-position walk over the every-construct witness
# catches it (the leftover is no longer exactly the binding and the machine name).
byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "the span-open arm emits the span name unquoted (identifier position)"
  FIND [[            "       (begin (byte-machine-span-open/v1 psr (quote "]]
  REPLACE [[            "       (begin (byte-machine-span-open/v1 psr ("]]
  EXPECT_OUTPUT_MATCHES "only the binding and the machine name remain -- expected .ecw ecw-parser., got .ecw")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "the error arm emits the source-node name unquoted (identifier position)"
  FIND [[                                                  (normal-error-reason s))) ") (quote "]]
  REPLACE [[                                                  (normal-error-reason s))) ") ("]]
  EXPECT_OUTPUT_MATCHES "only the binding and the machine name remain -- expected .ecw ecw-parser., got .ecw")

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

# Milestone 6 Slice ⓪ (design §4.12 item 2) RE-HOMED the two grammar pins below
# from verify.sls onto names.sls, where the one `portable-name?` body now lives,
# and RETIRED the third -- "compile: any interior binding character is
# accepted", which mutated compile.sls's textually identical copy of
# `name-char?`. There is no copy: valid-binding? calls the same body these two
# mutate, so that mutant's text no longer exists and its observation (a binding
# `a.b` accepted) is exactly the interior-character pin's, one FILE over. The
# per-file anchor trick these two used ("anchor on the definition that follows,
# to stay unique per file") is gone with the twin; each FIND is unique in
# names.sls on its own. Both keep their verify-site expectations: the
# identifier-repertoire lane still drives the verify site AND the compile site,
# and the verify-site record is the first the harness prints.
byte_machine_mutation(
  FILE src/byte-machine/private/names.sls SPEC byte-machine.verify.identifier-repertoire.chez.source
  LABEL "names: a name with a non-lowercase first char is accepted"
  FIND [[(lower-alpha? (string-ref s 0))
           (let loop ((i 1))]]
  REPLACE [[#t
           (let loop ((i 1))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "every rejected name is refused: reject 9a")

byte_machine_mutation(
  FILE src/byte-machine/private/names.sls SPEC byte-machine.verify.identifier-repertoire.chez.source
  LABEL "names: any interior character is accepted"
  FIND [[(or (lower-alpha? c) (and (char>=? c #\0) (char<=? c #\9)) (char=? c #\-)))]]
  REPLACE [[#t)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "every rejected name is refused: reject a_b")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.verify.identifier-repertoire.chez.source
  LABEL "compile: the emitted library line's terminator is CRLF"
  # Re-anchored in Slice ①a task 3. The pin's FIND is compile.sls's render TAIL,
  # which the metadata PAYLOAD's placement rewrote -- not the constructor rename
  # one line above it, which is what the design's own die-list attributed the
  # death to (§5, the "Five compile.sls emitter-text pins" bullet -- cited by
  # content because a line number into that file is stale the moment anything
  # is inserted above it, which this branch's own merge demonstrated).
  # RE-ANCHORED AGAIN, Slice ①b task 6, and for the same reason as last time: the
  # FIND is the render tail, and this slice fills decision 0019 item 3(b)'s
  # member 0, so the literal payload `#(#())` became an interpolation. That is
  # the second consecutive slice to move this pin without touching the decision
  # it names -- the tail is where every payload change lands, and any pin
  # anchored there will keep moving. Its REPLACE and its expectation are
  # unchanged; only the text it sits on moved.
  # Re-anchored by Milestone 5 Slice ①a task 3, and MOVED OFF THE TAIL for good.
  # This pin has now been broken by three consecutive slices without any of them
  # touching the decision it names, and the comment above predicted this one.
  # The library line is the new anchor: no payload change reaches it, every
  # machine renders it, and a CRLF injected there satisfies the same expectation
  # ("no carriage return byte appears and the last byte is LF"). Do not move it
  # back to the tail -- the tail is where every payload change lands.
  FIND [["(library (generated " mname ")\n"]]
  REPLACE [["(library (generated " mname ")\r\n"]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "no carriage return byte appears and the last byte is LF: carriage return present")

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
  LABEL "compile: the errs table carries declarations the graph never reaches"
  # Resolving decision 0022 item 7's open question. The encoding carries a
  # reason only where one is resolved, so a declaration nothing names never
  # reaches the IR fingerprint; emitting it anyway made two machines the
  # fingerprint calls identical emit different bytes. Witnessed by the
  # determinism lane's own equal-fingerprints-equal-bytes case, which is where
  # the property belongs: §20:1043 makes the fingerprint what the determinism
  # checks compare.
  #
  # RE-ANCHORED by Slice ①b's whole-branch review, which found the fix this pin
  # names was INCOMPLETE. The filter tests a (code . reason) PAIR, because the
  # normalizer resolved each site's declaration name to its code and reason
  # before the emitter sees it -- so an UNREACHED declaration duplicating a
  # reached one passed the membership test and was emitted, and two machines with
  # equal IR fingerprints still emitted different bytes. The filter now also
  # drops a pair it has already emitted.
  #
  # *** The dedup half is SUBSUMED by this mutation and is not written
  # separately. Measured, with the separating attempt recorded, which is what
  # AGENTS.md requires before the word is used. *** Suppressing only the dedup
  # (`(and (member pair reached) (not (member pair …)))` -> `(member pair
  # reached)`) fails exactly two cases, and this mutation fails both of them plus
  # "equal fingerprints emit equal bytes", so the narrow set is a strict subset
  # of this one's. THREE separating constructions were tried and all three fail:
  #   * A machine with an unreached DISTINCT pair separates them in behaviour but
  #     not in records -- the dedup mutant is CORRECT there, so it reddens
  #     nothing a pin could name.
  #   * A machine whose every declaration is reached with two sharing a pair
  #     makes the two mutants emit IDENTICAL text.
  #   * Both together: this mutation emits one more entry than the dedup mutant,
  #     but every record the dedup mutant produces, this one produces too.
  # The dedup is strictly less permissive than this mutation on every machine, so
  # no fixture can redden it while leaving this one green. The BEHAVIOUR is
  # witnessed -- determinism-one-byte-tests.sps's two new cases fail against the
  # dedup mutant, measured -- it is the separate PIN that no fixture supports.
  FIND [[                                (if (and (member pair reached)
                                         (not (member pair
                                                      (map (lambda (d)
                                                             (cons (error-declaration-code d)
                                                                   (error-declaration-reason d)))
                                                           acc))))
                                    (cons (car ds) acc) acc))))))]]
  REPLACE [[                                (cons (car ds) acc))))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "equal fingerprints emit equal bytes: and so do the emitted bytes")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.determinism.one-byte.chez.source
  LABEL "compile: the writer's export line spacing changes"
  FIND [["  (export " bstr ")\n"]]
  REPLACE [["  (export  " bstr ")\n"]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the emitted bytes equal the committed golden: golden")

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
#
# --- Slice ② Task 11 sweep (2026-09-11, scratchpad sweep.py over all 27 property
# mutations; re-run after any change here). RESULT: the per-pin match-count matrix
# has an all-ONE diagonal (every pin matches its own mutant's output exactly once)
# and an all-ZERO off-diagonal EXCEPT four cells -- the floor check
# ("the accepted count is at least the floor") co-firing on the four floor-dropping
# removals (exact-byte, byte-set, integer-accumulate, mask-none). That containment
# is BY CONSTRUCTION: a draw that drops acceptance below 32 always trips the floor,
# and holding the floor at 32 (the owner's call) makes it unavoidable; each dropper
# is still uniquely discriminated by its own totality-row pin (member-specific
# got-list), so no mutant lacks a unique witness. counted-consume was moved off its
# fragile counter onto its totality node row to clear the only other collisions
# (sequence-dispatch and clear-mask removals incidentally zero the counted-consume
# counter). Base control (Task 1 Step 8, diagonal 40/1/2/1/1/1 with three inherited
# off-diagonal cells pause/accp/init x bytetest): those three are ABSENT at HEAD
# (the F13 re-anchors fixed them, confirmed -- the re-anchored pins show zero
# off-diagonal); the four HEAD cells are introduced-by-construction (the four
# mutations do not exist at the base), so the base was not independently rebuilt --
# noted for the Task 13 review. Step 3 literals: the property verify command is the
# only "--program …/property-differential-tests.sps" in this file (its
# set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND …) just below), MutationRunner ignores SPEC when VERIFY_COMMAND is set (48
# set() sites), so a pin is judged only against this program's output. Step 4 label
# audit: no check label is matched by any pin except its owner. Step 0: both
# retirements below re-confirmed over the full set -- `accp` survives only in a
# header comment and the fixed `'n 8 25` field is gone, so neither mutation has a
# FIND site; verdict RETIRE, unchanged from Task 9.
#
# WHAT A CLEAN SWEEP DOES NOT SAY (AGENTS.md): a whole-pass sweep re-judges the pins
# that EXIST; it cannot notice a decision no pin names -- not the two retirements
# above, and not a construct in the rewritten generator that no pin covers. The
# per-member pins here are a REPRESENTATIVE subset, not one-per-member: the eight
# structural node kinds (byte-dispatch, stop, error, field-action, field-branch,
# callback, span-start, span-end), five of seven field operations (clear, increment,
# decrement, add, set-mask), five of seven field predicates (zero, nonzero, range,
# mask-any, mask-all), one of four callback outcomes (continue), and the derived
# accumulate-overflow / declares-field counters have NO dedicated mutation pin. For
# a DRAWN family every one of those removals is still caught by its totality row's
# set-equal (source-vs-table), and for the two DECLARED families with no draw table
# (span events, schedule shapes) the totality row compares the driver's family to a
# cited literal, unexercisable by a table removal. "Not a counter" is exact only for
# byte-dispatch/stop/error/field-action/field-branch, whose counters are fed
# unconditionally (entry, fixed terminals, coverage prefix); removing callback,
# span-start or span-end WOULD also zero their counters, since the coverage segment
# that feeds them is gated on the draw table -- but no pin removes them either way.
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/property-differential-tests.sps")

# Milestone 7 Slice ②: the property lane is rewritten over the driver
# ((byte-machine test property-driver)) and the generator now draws over every
# §10.6 construct. Four of the six mutations below re-anchor onto the new
# constructs (their decisions still exist); two are RETIRED (their decisions no
# longer exist -- a later fix made them unobservable, not a refactor that
# relocated them), with tombstones at the site. LABELs decided by F13.

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.property.differential.chez.source
  LABEL "compile: the dispatch byte test is inverted, diverging from the oracle"
  FIND [[(number->string (car tr)) ") "]]
  # The emitted dispatch's `case` key is the source byte, unshifted, so the
  # generated executor agrees with the interpreter oracle; inverting it diverges
  # on every machine. RE-ANCHORED (F13 LABEL 1): compile.sls is unchanged by this
  # slice, so FIND/REPLACE stand; only the pin moves. The rewritten lane's Layer-1
  # comparison fails per machine as "machine <i> (seed <s>) byte agreement", and
  # the pin now names ONE accepted machine index (machine 0 is accepted at seed
  # 20260823, re-measured after the rewrite) with its parens escaped, so it
  # matches exactly one record. The whole-machine "byte agreement" substring would
  # match all 36.
  REPLACE [[(number->string (mod (+ 1 (car tr)) 256)) ") "]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[machine 0 \(seed 20260823\) byte agreement]])

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/property-driver.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "property-differential: resume-pair! stops calling parser-resume!"
  # RE-ANCHORED (F13 LABEL 2): the pause protocol moved into the driver, so the
  # resume site relocated from property-differential-tests.sps to property-driver.sls.
  # Skipping the real resume leaves both parsers at paused-feed; the driver's next
  # feed then trips runtime.sls's lifecycle-violation guard. The drive runs inside
  # the lane's accounting harness-case, so the raise is recorded as "case raised"
  # with the condition's own detail (status 1), not an uncaught exit-255. Pinned to
  # the measured detail tuple "paused-feed feed" -- metacharacter-free, and printed
  # by nothing else in this program.
  FIND [[(list (parser-resume! pr) (parser-resume! pg))]]
  REPLACE [[(list 'feed-ready 'feed-ready)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "paused-feed feed")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-gen.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "machine-gen: the pause node kind is dropped from the draw table"
  # RE-ANCHORED (F13 LABEL 3): the generator no longer has a pause "coin"; it
  # draws node kinds from node-kind-draw-table, and the coverage segment's pause
  # node is gated on that table too. Removing `pause` from the table means no
  # generated machine can reach a pause node, so the interpreter-only pause
  # counter reads zero. Pinned to the full interpreter-only label plus the detail
  # (F11) -- the half no cross-lane divergence can zero, and not the bare
  # "observes a pause" substring, which matches two labels.
  FIND [[error finish pause]]
  REPLACE [[error finish]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the interpreter alone observes a pause -- expected a true value]])

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-gen.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "machine-gen: the eof route stops offering a finish terminal"
  # RE-ANCHORED (F13 LABEL 4): the eof draw's `done`/finish member is now the
  # `tfin` finish terminal offered by eof-route!. F7: the EOF route is the only
  # accepted producer of a REACHABLE finish, so removing it zeros the finish
  # counter. Pinned to the full interpreter-only label plus the detail (F11).
  FIND [[((= r 1) (use-term! 'tfin))]]
  REPLACE [[((= r 1) (use-term! 'terr))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the interpreter alone observes an idle-completion finish -- expected a true value]])

# --- RETIRED (F13 LABELs 5 and 6): two decisions the rewrite made UNOBSERVABLE,
# not a refactor that relocated them (AGENTS.md: "only one a later fix makes
# unobservable is retired"). Tombstones, so the next reader does not re-add them.
#
# RETIRED: "machine-gen: the pinned accumulate case advances instead of
# reexecuting". The construct is gone: there is no `accp`, no pinned digit case,
# and every inbound mode is drawn. The mutation's OWN stated reason -- "byte-trial
# feeds ONE byte to a fresh pair, so advancing consumes it and accp is entered
# with the slice exhausted" -- no longer holds: §4.4 keeps the 256 single-byte
# trials AND adds eight drawn inputs of length 0-6 under every split point, so an
# advance inbound edge leaves the accumulate node a byte to read and the digit arm
# runs either way. The decision the pin named (reexecute is load-bearing) is
# unobservable because the premise that made it load-bearing is removed. Not
# re-anchored: no construct in the new generator carries it.
#
# RETIRED: "machine-gen: the accumulate field's initial is one below the only
# workable value". `(make-uint-field 'n 8 25 #f)` is gone: §4.4 draws one or two
# uint fields at drawn widths and drawn initials, so there is no chosen constant
# to move by one. Not a re-anchor in either direction: forcing a drawn initial to
# 0 does NOT zero the overflow counter (six base-10 digits overflow a u8 from 0,
# and inputs run to six bytes), and forcing it to (- (expt 2 width) 1) zeros the
# COMMIT counter instead -- a different decision. Both would be new pins with new
# decisions, not this one relocated.

# --- Slice ② additions (Task 10): pins for the new counters. Each removes what
# PRODUCES an observed value and is caught by a failed COMPARISON. Placed between
# Pass 39's reset() and its run() so they join Pass 39 (F16), not Pass 40. Pins
# are the interpreter-only half's full label plus the detail (F11). The node kinds
# produced by fixed terminals, the entry, or the coverage prefix/segment
# (byte-dispatch, stop, error, field-action, field-branch, callback, span-start/-end,
# and the span-event/callback-outcome families they gate) need per-construct
# mutations and are tracked as remaining work ("cover every construct"). The six
# Layer-3 invariant pins are below -- each inverts one row of check-invariants and
# reddens the driver's single Layer-3 oracle check, whose detail names the row.

byte_machine_mutation(
  FILE test/common/property-differential-tests.sps
  SPEC byte-machine.property.differential.chez.source
  LABEL "property-differential: the verifier filter is dropped, executing rejected draws"
  FIND [[(verification-ok? v)]]
  REPLACE [[#t]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES [[no draw reached an executor unverified]])

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-gen.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "machine-gen: the entry names a node that is never built (rejects everything)"
  FIND [[(make-machine 'gen 'cova]]
  REPLACE [[(make-machine 'gen 'no-such-entry]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES [[the accepted count is at least the floor]])

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-gen.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "machine-gen: the sequence-dispatch node kind is dropped from the draw table"
  FIND [[byte-dispatch sequence-dispatch]]
  REPLACE [[byte-dispatch]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the interpreter alone reaches node kind sequence-dispatch -- expected a true value]])

# counted-consume is pinned on its TOTALITY node row, not its counter: the
# counted-consume counter is fragile -- removing sequence-dispatch OR clear-mask
# from a draw table shifts the free draw and incidentally zeros it, so a counter
# pin here would also be satisfied by those two mutants (measured in the Task 11
# sweep). The totality row's member-specific got-list is unique to this removal.
# sequence-dispatch's own counter is NOT fragile this way (measured 0 off-diagonal),
# so it keeps its counter pin above.
byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-gen.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "machine-gen: the counted-consume node kind is dropped from the draw table"
  FIND [[span-end counted-consume]]
  REPLACE [[span-end]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the node-kind draw table covers exactly ir.sls.s node. kinds -- expected .byte-dispatch callback error field-action field-branch finish integer-accumulate keyword-table pause sequence-dispatch span-end span-start stop., got .byte-dispatch callback counted-consume error field-action field-branch finish integer-accumulate keyword-table pause sequence-dispatch span-end span-start stop.]])

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/property-driver.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "property-driver: the callback script never answers pause"
  FIND [[((1) 'pause)]]
  REPLACE [[((1) 'continue)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the interpreter alone observes callback outcome pause -- expected a true value]])

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/property-driver.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "property-driver: the callback script never answers a declared branch key"
  FIND [[((2) (if (pair? keys) (car keys) 'continue))]]
  REPLACE [[((2) 'continue)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the interpreter alone observes callback outcome declared-branch-key -- expected a true value]])

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/property-driver.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "property-driver: the callback script never answers an explicit failure"
  FIND [[(else (cons 'boom #f))]]
  REPLACE [[(else 'continue)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the interpreter alone observes callback outcome explicit-failure -- expected a true value]])

# The counter set is a FIXED literal list in the driver, decoupled from the
# generator's draw tables, so removing a matcher/operation/predicate from a draw
# table leaves its counter CHECK standing to read zero (caught by comparison).
# The matcher coverage dispatch covmd and the coverage accumulate covacc make
# these robust -- the removal zeros ONLY the intended counter without the free
# draw shifting a different one. Members whose removal HOLDS the floor are pinned
# on their COUNTER label here (byte-range/byte-complement/store/equal, measured
# 37-40 accepted). Members whose removal DROPS the floor (exact-byte 30, byte-set
# 17, mask-none 31, integer-accumulate 28) cannot use a counter label -- the floor
# fails first and the counter case is skipped (F12) -- so they are pinned on the
# TOTALITY row below (Task 7 Step 2), whose source-vs-table comparison catches any
# draw-table member removal INDEPENDENT of the floor. clear-mask holds the floor
# but its removal incidentally zeros the counted-consume counter (a draw-shift
# fragility this slice does not carry robust coverage for), so it too is pinned on
# a totality row -- and counted-consume itself is pinned on its totality node row
# above for the same reason, so no counter pin is left for the clear-mask (or
# sequence-dispatch) fragility to collide with. Each totality pin's regex carries
# the member-specific got-list, so it matches only its own removal. The Task 11
# sweep's ONLY remaining off-diagonal is the shared floor check co-firing on the
# four floor-droppers -- a by-construction containment (a sub-floor draw always
# trips the floor), each dropper still discriminated by its own totality pin.

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-gen.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "machine-gen: the byte-range matcher kind is dropped from the draw table"
  FIND [['(exact-byte byte-set byte-range byte-complement)]]
  REPLACE [['(exact-byte byte-set byte-complement)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the interpreter alone matches matcher byte-range -- expected a true value]])

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-gen.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "machine-gen: the byte-complement matcher kind is dropped from the draw table"
  FIND [['(exact-byte byte-set byte-range byte-complement)]]
  REPLACE [['(exact-byte byte-set byte-range)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the interpreter alone matches matcher byte-complement -- expected a true value]])

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-gen.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "machine-gen: the store field operation is dropped from the draw table"
  FIND [['(store clear increment decrement add set-mask clear-mask)]]
  REPLACE [['(clear increment decrement add set-mask clear-mask)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the interpreter alone runs field operation store -- expected a true value]])

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-gen.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "machine-gen: the equal field predicate is dropped from the draw table"
  FIND [['(equal zero nonzero range mask-any mask-all mask-none)]]
  REPLACE [['(zero nonzero range mask-any mask-all mask-none)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the interpreter alone evaluates field predicate equal -- expected a true value]])

# The floor-dropping / fragile removals, pinned on the TOTALITY rows (Task 7 Step
# 2). The row's set-equal fails source-vs-table on the removed member; the got-list
# (sorted by the row) names which member is gone, so each pin matches only its own
# removal. `.` stands in for parens and for the `?` in `node?`; no `.*`.

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-gen.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "machine-gen: the exact-byte matcher kind is dropped from the draw table"
  FIND [['(exact-byte byte-set byte-range byte-complement)]]
  REPLACE [['(byte-set byte-range byte-complement)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the matcher draw table covers exactly ir.sls.s matcher kinds -- expected .byte-complement byte-range byte-set., got .byte-complement byte-range byte-set exact-byte.]])

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-gen.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "machine-gen: the byte-set matcher kind is dropped from the draw table"
  FIND [['(exact-byte byte-set byte-range byte-complement)]]
  REPLACE [['(exact-byte byte-range byte-complement)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the matcher draw table covers exactly ir.sls.s matcher kinds -- expected .byte-complement byte-range exact-byte., got .byte-complement byte-range byte-set exact-byte.]])

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-gen.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "machine-gen: the integer-accumulate node kind is dropped from the draw table"
  FIND [[field-branch integer-accumulate callback]]
  REPLACE [[field-branch callback]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the node-kind draw table covers exactly ir.sls.s node. kinds -- expected .byte-dispatch callback counted-consume error field-action field-branch finish keyword-table pause sequence-dispatch span-end span-start stop., got .byte-dispatch callback counted-consume error field-action field-branch finish integer-accumulate keyword-table pause sequence-dispatch span-end span-start stop.]])

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-gen.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "machine-gen: the mask-none field predicate is dropped from the draw table"
  FIND [['(equal zero nonzero range mask-any mask-all mask-none)]]
  REPLACE [['(equal zero nonzero range mask-any mask-all)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the field-predicate draw table covers exactly ir.sls.s field-predicates -- expected .equal mask-all mask-any nonzero range zero., got .equal mask-all mask-any mask-none nonzero range zero.]])

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-gen.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "machine-gen: the clear-mask field operation is dropped from the draw table"
  FIND [['(store clear increment decrement add set-mask clear-mask)]]
  REPLACE [['(store clear increment decrement add set-mask)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the field-operation draw table covers exactly ir.sls.s field-operations -- expected .add clear decrement increment set-mask store., got .add clear clear-mask decrement increment set-mask store.]])

# One callback-kind removal, so the callback-kind totality row is exercised too
# (the node/matcher/operation/predicate totality rows each already have a removal
# pin; without this the callback-kind row would be the only draw-table totality row
# no mutation proves load-bearing). Holds the floor; caught by the row's set-equal.
byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-gen.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "machine-gen: the event callback kind is dropped from the draw table"
  FIND [['(event decision span-data span-complete)]]
  REPLACE [['(decision span-data span-complete)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the callback-kind draw table covers exactly make-callback-declaration.s kinds -- expected .decision span-complete span-data., got .decision event span-complete span-data.]])

# The six Layer-3 invariant pins (Task 5 Step 3 / Task 10 Step 3). Each inverts one
# row's comparison in check-invariants; the row then reports a violation on the
# drawn machines, folded into the driver's inv-verdict and asserted by the SINGLE
# lane check "no accepted machine's trial violated a Layer-3 invariant". That check
# is a check-equal, so its FAIL detail carries the verdict -- (invariant IDX (rowN
# ...)) -- and each pin's regex names its own row, matching exactly that one record
# (a second, undiscriminating record -- the fixture "layers" case's boolean check --
# also reddens; the pin does not match it). Rows read the tuple independently and
# hold on every drawn trial, so inverting one reddens exactly itself. `.` stands in
# for each paren, the suite's convention; no `.*` between `expected` and `got`.

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/property-driver.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "property-driver: Layer-3 row 1 (the lifecycle x operation table) inverted"
  FIND [[(if (eq? st life) #f]]
  REPLACE [[(if (not (eq? st life)) #f]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[no accepted machine's trial violated a Layer-3 invariant -- expected none, got .invariant [0-9]+ .row1]])

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/property-driver.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "property-driver: Layer-3 row 2 (the feed cursor arithmetic) inverted"
  FIND [[(if (= cn (- nx (step-start s))) #f]]
  REPLACE [[(if (not (= cn (- nx (step-start s)))) #f]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[no accepted machine's trial violated a Layer-3 invariant -- expected none, got .invariant [0-9]+ .row2]])

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/property-driver.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "property-driver: Layer-3 row 3 (sticky feeds consume nothing) inverted"
  FIND [[(= (tup-consumed t) 0)]]
  REPLACE [[(not (= (tup-consumed t) 0))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[no accepted machine's trial violated a Layer-3 invariant -- expected none, got .invariant [0-9]+ .row3]])

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/property-driver.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "property-driver: Layer-3 row 4 (fields stay in [0, 2^width)) inverted"
  FIND [[(or (< x 0) (>= x (expt 2 w)))]]
  REPLACE [[(not (or (< x 0) (>= x (expt 2 w))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[no accepted machine's trial violated a Layer-3 invariant -- expected none, got .invariant [0-9]+ .row4]])

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/property-driver.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "property-driver: Layer-3 row 5 (finished from a feed only if already finished) inverted"
  FIND [[(and (eq? (step-op s) 'feed) (not (eq? (step-life s) 'finished)))]]
  REPLACE [[(not (and (eq? (step-op s) 'feed) (not (eq? (step-life s) 'finished))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[no accepted machine's trial violated a Layer-3 invariant -- expected none, got .invariant [0-9]+ .row5]])

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/property-driver.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "property-driver: Layer-3 row 6 (the span end anchor) inverted"
  # RE-PINNED by Milestone 11 Slice ①: the keyword-table entry in the node-kind
  # draw table (required by the totality row) shifts the generator's PRNG stream,
  # so at this seed no ACCEPTED machine reaches a completing span and the
  # accepted-machine invariant check the other rows use no longer witnesses row 6.
  # The FIXED fixture always does, so this row now pins the deterministic
  # fixture-schedule check -- which this slice also taught to name the violated
  # row (expected none, got (row6 ...)) rather than report a bare boolean, so the
  # witness still names row 6. The edit and decision are unchanged.
  FIND [[(not (= (cadr (last-elt frags)) coff))]]
  REPLACE [[(= (cadr (last-elt frags)) coff)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[check-invariants holds on every fixture schedule -- expected none, got .row6 span-end-anchor]])

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "runtime: span-close does not reset the delivered flag"
  # decision 0042 item 1: the delivered flag is reset only in
  # byte-machine-span-close/v1, so a prior span's "has delivered" state cannot leak
  # into the next span opened on the same parser. This is the only lane whose one
  # machine runs TWO spans in sequence: the coverage machine's covx (a nonempty
  # span -- flag set) then covy (an EMPTY span). Dropping the reset leaves covy's
  # flag stale #t, so covy is suppressed and the empty-fragment counter reads zero.
  FIND [[    (parser-set-span-delivered?! parser #f)]]
  REPLACE [[    #t]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "at least one agreed trial observes span event empty-fragment -- expected a true value")

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

# --- Pass 42: matcher canonicalization and the tag-guarded accessor (M3 Slice
# ① Task 1), plus the class-matcher constructors and ascii-bytes (M3 Slice ①
# Task 2) ---------------------------------------------------------------------
#
# ir-tests.sps is the first program to reach (byte-machine private ir)'s
# canonicalization spine directly, and no pass has ever mutated ir.sls: every
# earlier pass reaches it only through a consumer. The first mutation swaps
# the exact-byte arm's returned byte for a constant 0, so an exact matcher
# canonicalizes to the wrong one-element set instead of its own byte; the
# second removes the accessor's tag guard, so a foreign vector reads slot 1
# and returns instead of raising -- the exact defect design §5 says must not
# be allowed to reach pass-overlap or list-sort. Verify command uses both
# library roots, an empty object guard, the ir program.
#
# FIND is matched as a literal substring (MutationRunner.cmake), not a regex
# and not whitespace-insensitive; it is written without leading whitespace,
# which is what tolerates indentation drift in the matched line. SITES
# defaults to 1 and is asserted exactly.
#
# Task 2 adds five mutations to this same pass rather than opening a new one,
# since they exercise the same canonicalization spine the first two already
# prove ir-tests.sps can reach: the byte-set and byte-range constructors'
# degenerate-shape guards (decision 0017), ascii-bytes' non-ASCII guard, and
# matcher-bytes' new byte-set-canonical and complement arms. Passes stay at
# 39; mutations become 167 + 5 = 172.
#
# Task 2's review fix wave 1 adds six more, still in this same pass, still
# against ir-tests.sps: the tag guards on the four remaining class-matcher
# accessors this task's own review found uncaught, decision 0014's ordering
# half, and matcher-bytes' else arm (carried open from Task 1's own report).
# See each mutation's own comment for what it measures. Two pre-existing pins
# in this pass -- "the exact-byte accessor reads slot 1 of any vector" and "a
# byte set is canonicalized without de-duplication" -- were re-anchored in the
# same commit: adding mutations here widened both pins' collision sets (a
# full Pass 42 pin sweep -- byte_machine_mutation_verdict, every pin against
# every other mutant's captured output, 156 ordered pairs across all 13
# mutations -- found exactly these two, both now carrying the case's full
# name or its own measured "got" instead of the bare check label). No other
# pair in the pass collides.

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/ir-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: an exact-byte matcher does not canonicalize to its own byte"
  FIND [[(list (exact-byte-matcher-byte m))]]
  REPLACE [[(list 0)]]
  # Comparison-caught, not raise-based: the exact-byte arm still runs, so
  # matcher-bytes returns a set instead of raising, and check-equal's "set"
  # comparison is what catches the wrong byte. Measured (not predicted):
  # this also leaves "canonicalizing a foreign vector is a contract
  # violation" passing under the mutant, since that case's else branch is
  # untouched -- unlike the prior raise-based mutation, which routed every
  # case through the same else and made that third case pass for the wrong
  # reason.
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "one-element set: set -- expected \\(7\\), got \\(0\\)")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: the exact-byte accessor reads slot 1 of any vector"
  FIND [[(byte-machine-contract-violation 'exact-byte-matcher-byte 'invalid-argument 'matcher)]]
  REPLACE [[#f]]
  # Re-anchored in Fix wave 1: bare "refuses a foreign vector: refused" cross-
  # matched the four new tag-guard mutations below, since every accessor in
  # that guard class shares the same check label and case-name tail. Re-
  # measured (byte_machine_mutation_verdict against all 12 other Pass 42
  # mutants' captured output): the full case name is unique in the pass.
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the exact-byte accessor refuses a foreign vector: refused")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: an empty byte set is accepted"
  # Re-anchored in M3 Slice ② Task 1: make-sequence-case's own empty-list
  # guard (added by this task) is byte-for-byte the same shape as this one,
  # so the bare `(unless (and (list? bytes) (pair? bytes)` FIND stopped being
  # unique in this file (SITES=1, asserted exactly) the moment that
  # constructor landed -- exactly the "module was refactored" case the SITES
  # check exists to catch loudly. Anchored to the preceding `define` line,
  # which the sequence-case constructor's does not share.
  FIND [[(define (make-byte-set-matcher bytes)
    (unless (and (list? bytes) (pair? bytes)]]
  REPLACE [[(define (make-byte-set-matcher bytes)
    (unless (and (list? bytes)]]
  # Comparison-caught via check-raises' own expected-vs-actual assertion, not
  # an incidental raise: dropping (pair? bytes) lets '() satisfy the rest of
  # the guard (for-all over '() is vacuously true), so construction succeeds
  # and check-raises reports "expected a raise, but the thunk returned ...".
  # Measured (not predicted): this mutant also fails the ascii-bytes empty-
  # string case ("and cannot become a byte set"), since that check-raises
  # reaches the same guard; the pin below is the first FAIL line only.
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "an empty byte set is rejected: empty set")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: a reversed byte range is accepted"
  FIND [[(unless (<= low high)]]
  REPLACE [[(unless #t]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "low greater than high is rejected: reversed")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: ascii-bytes admits a non-ASCII character"
  FIND [[(unless (<= 0 c 127)]]
  REPLACE [[(unless #t]]
  # Measured (not predicted): the case name is lowercase ("a non-ASCII
  # character is rejected"), not the plan's predicted "A non-ASCII...".
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "a non-ASCII character is rejected: non-ascii")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: a byte set is canonicalized without de-duplication"
  FIND [[((and (pair? acc) (= (car s) (car acc))) (loop (cdr s) acc))]]
  REPLACE [[((and (pair? acc) (< (car s) (car acc))) (loop (cdr s) acc))]]
  # Re-anchored in Fix wave 1: the bare case+check pin cross-matched the new
  # ordering mutation below, which breaks the same check ("ascending and
  # de-duplicated: set") with a different measured "got". Each of the two
  # sibling mutations now carries its own measured "got" tuple, the same
  # trade the pre-existing one-byte-fingerprint pins made (see the header
  # note above EXPECTED_PASSES/EXPECTED_MUTATIONS).
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "ascending and de-duplicated: set -- expected \\(0 1 2 254 255\\), got \\(0 1 1 2 254 255\\)")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: a complement is not the universe minus the inner set"
  FIND [[((memv b inner) (loop (- b 1) acc))]]
  REPLACE [[((memv b inner) (loop (- b 1) (cons b acc)))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "minus the inner set: count")

# --- Fix wave 1 (Task 2 review): the four remaining tag-guarded class-matcher
# accessors, decision 0014's ordering half, and matcher-bytes' else arm -----
#
# The mutation-count cap that stopped Task 2 from closing these is withdrawn
# (see the Global Constraints note this fix wave was dispatched under); every
# mutation below is measured, not predicted, against this file's own tree.
#
# The first four are one instance per class-matcher accessor of the same tag-
# guard defect Pass 42's second mutation already proves for
# exact-byte-matcher-byte: dropping the tag check lets the accessor read
# whatever slot N of a foreign vector without raising. Four mutations, not
# one, because each guard sits at its own source line -- deleting
# byte-range-matcher-low's `unless` does not touch byte-range-matcher-high's,
# so a single representative mutation would leave three of the four exactly
# as unguarded as before this fix wave. Each is caught by check-raises' own
# expected-vs-actual assertion (comparison-caught, not raise-based): the
# guard's replacement is `#f`, not a raise, so execution falls through to the
# bare vector-ref and the thunk returns instead of raising.
byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: byte-set-matcher-bytes reads slot 1 of any vector"
  FIND [[(byte-machine-contract-violation 'byte-set-matcher-bytes 'invalid-argument 'matcher)]]
  REPLACE [[#f]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "byte-set-matcher-bytes refuses a foreign vector: refused")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: byte-range-matcher-low reads slot 1 of any vector"
  FIND [[(byte-machine-contract-violation 'byte-range-matcher-low 'invalid-argument 'matcher)]]
  REPLACE [[#f]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "byte-range-matcher-low refuses a foreign vector: refused")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: byte-range-matcher-high reads slot 2 of any vector"
  FIND [[(byte-machine-contract-violation 'byte-range-matcher-high 'invalid-argument 'matcher)]]
  REPLACE [[#f]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "byte-range-matcher-high refuses a foreign vector: refused")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: byte-complement-matcher-matcher reads slot 1 of any vector"
  FIND [[(byte-machine-contract-violation 'byte-complement-matcher-matcher
                                       'invalid-argument 'matcher)]]
  REPLACE [[#f]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "byte-complement-matcher-matcher refuses a foreign vector: refused")

# Decision 0014's ordering half (Minor 4): the existing de-duplication
# mutation above proves the `=` comparison in byte-set-canonical's loop is
# load-bearing, but nothing proved `list-sort` itself is. Dropping it leaves
# input-order bytes with no adjacent duplicates untouched by the loop, so the
# result comes back in the caller's order instead of ascending --
# comparison-caught by the same check the de-duplication mutation uses,
# distinguished from it by its own measured "got" (see that mutation's
# re-anchored pin comment above).
byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: a byte set canonicalizes without ascending order"
  FIND [[(list-sort < bs)]]
  REPLACE [[bs]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "ascending and de-duplicated: set -- expected \\(0 1 2 254 255\\), got \\(254 1 0 1 255 2\\)")

# matcher-bytes' contract-violation else arm (Minor 5, carried from Task 1):
# REPLACE returns the empty list instead of raising, witnessed by the
# existing "canonicalizing a foreign vector is a contract violation" case.
# Comparison-caught via check-raises' own expected-vs-actual assertion.
byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: matcher-bytes canonicalizes a foreign vector instead of raising"
  FIND [[(byte-machine-contract-violation 'matcher-bytes
                                                 'invalid-argument 'matcher)]]
  REPLACE [['()]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a contract violation: refused -- expected a raise, but the thunk returned \\(\\)")

# Milestone 3 Slice ② Task 1: the sequence node kind and its cases (§9.1:
# 297-298), still on this same Pass 42 -- ir-tests.sps already proves this
# lane can reach ir.sls's own constructors directly, and these four mutations
# exercise the same file. Every FIND/REPLACE and EXPECT_OUTPUT_MATCHES is
# measured against this file's own tree, not predicted. Passes stay at 41;
# mutations become 193 + 4 = 197 (with the seven verify.sls arm mutations
# above, this pass's own share rose from 13 to 17).
#
# Fix wave 1 (Minor finding 2) adds three more, still in this same pass:
# make-sequence-dispatch-node's three guards -- empty cases, a non-edge?
# mismatch, a bad eof-target -- had harness cases (the eof-target guard's own
# rejection case did not even exist yet; added below, beside its existing
# "an eof-target of #f is legal" sibling) but no mutation proving those
# check-raises were non-vacuous. All three measured against this file's own
# tree; all three comparison-caught via check-raises' own expected-vs-actual
# assertion, none raise-based. Passes stay at 41; mutations become 197 + 3 =
# 200.
byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: node? does not admit a sequence node"
  FIND [[(or (byte-dispatch-node? x) (sequence-dispatch-node? x)
        (keyword-table-node? x) (stop-node? x)]]
  REPLACE [[(or (byte-dispatch-node? x)
        (keyword-table-node? x) (stop-node? x)]]
  # Comparison-caught: with the disjunct removed, node? is false for a
  # sequence node (which would also make make-machine reject it outright),
  # and the case's own `check "node?"` reports "expected a true value".
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "a sequence node is a node, and reports its own name: node\\?")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: node-name does not report a sequence node's name"
  FIND [[((sequence-dispatch-node? x) (sequence-dispatch-node-name x))]]
  REPLACE [[((sequence-dispatch-node? x) 'wrong-name)]]
  # Comparison-caught, not raise-based: the clause still returns a value
  # (the opposite-constant form AGENTS.md prefers over one that falls through
  # to the else arm's raise), so check-equal reports the wrong symbol instead
  # of the call failing to return at all.
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a sequence node is a node, and reports its own name: node-name -- expected seq, got wrong-name")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: make-sequence-case accepts an empty byte list"
  # Anchored to the preceding `define` line: make-byte-set-matcher's own
  # empty-list guard (mutated above, in this same pass) is byte-for-byte the
  # same shape, so the bare `(unless (and (list? bytes) (pair? bytes)` text
  # is not unique in this file on its own (SITES=1, asserted exactly).
  FIND [[  (define (make-sequence-case bytes target source-label)
    (unless (and (list? bytes) (pair? bytes)]]
  REPLACE [[  (define (make-sequence-case bytes target source-label)
    (unless (and (list? bytes)]]
  # Comparison-caught via check-raises' own expected-vs-actual assertion:
  # dropping (pair? bytes) lets '() satisfy the rest of the guard (for-all
  # over '() is vacuously true), so construction succeeds and check-raises
  # reports the thunk returned instead of raising.
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "an empty sequence is rejected \\(decision 0017 point 1\\): empty")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: sequence-case-bytes returns the stored chain rather than a copy"
  FIND [[(append (vector-ref c 1) '())]]
  REPLACE [[(vector-ref c 1)]]
  # Comparison-caught: without the copy, two calls return the SAME pair
  # chain, so `(not (eq? ...))` is false and the case's own "not eq" check
  # reports "expected a true value".
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the bytes accessor returns a copy, not the stored chain: not eq")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: make-sequence-dispatch-node accepts an empty case list"
  FIND [[(unless (and (list? cases) (pair? cases) (for-all sequence-case? cases))]]
  REPLACE [[(unless (and (list? cases) (for-all sequence-case? cases))]]
  # Comparison-caught via check-raises' own expected-vs-actual assertion:
  # dropping (pair? cases) lets '() satisfy the rest of the guard (for-all
  # over '() is vacuously true), so construction succeeds and check-raises
  # reports the thunk returned instead of raising. FIND is unique on its own:
  # byte-dispatch-node's own cases guard has no (pair? cases) conjunct at all
  # (an empty case list is legal there -- the fallback alone can dispatch).
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "an empty case list is rejected: no cases")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: make-sequence-dispatch-node accepts a non-edge mismatch"
  FIND [[(unless (edge? mismatch)]]
  REPLACE [[(unless #t]]
  # Comparison-caught: the guard's test is forced true, so a bare target
  # handed in as the mismatch edge is accepted and stored verbatim; the
  # thunk returns instead of raising.
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a bare target handed in as the mismatch edge is rejected: not an edge")

# Milestone 4 Slice ①b task 1: the uint field descriptor. Three decisions --
# the closed width set, the initial's range, and the machine guard that makes
# the descriptor load-bearing at all.
byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: the uint field width set is not closed"
  FIND [[    (unless (memq width '(8 16 32 64))]]
  REPLACE [[    (unless #t]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the width set is closed at 8, 16, 32 and 64: refused")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: a uint field initial is not range-checked against its width"
  # Comparison-caught on the upper bound, which is what §25:1568's
  # declaration-time share turns on: 2^w is accepted where it must be refused.
  FIND [[                 (<= 0 initial (- (expt 2 width) 1)))]]
  REPLACE [[                 (<= 0 initial (expt 2 width)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the initial is an exact integer inside the declared width: over the top")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: make-machine accepts fields that are not field descriptors"
  # Without this guard the collection loop checks only list?, so any proper list
  # passes -- measured before the guard landed, a machine could carry
  # (junk 42 "string") as its fields and nothing read it. This is the mutation
  # that says the descriptor is load-bearing rather than decorative.
  FIND [[    (unless (for-all uint-field? fields)]]
  REPLACE [[    (unless #t]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "and refuses a list of anything else: junk fields")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: make-sequence-dispatch-node accepts a malformed eof-target"
  # The bare guard condition `(unless (or (symbol? eof-target) (eq? eof-target
  # #f))` is byte-identical to byte-dispatch-node's own eof-target guard
  # (:230); FIND includes the following contract-violation line, which names
  # make-sequence-dispatch-node and is not shared, to stay unique (SITES=1,
  # asserted exactly).
  FIND [[    (unless (or (symbol? eof-target) (eq? eof-target #f))
      (byte-machine-contract-violation 'make-sequence-dispatch-node 'invalid-argument 'eof-target))]]
  REPLACE [[    (unless #t
      (byte-machine-contract-violation 'make-sequence-dispatch-node 'invalid-argument 'eof-target))]]
  # Comparison-caught: the guard's test is forced true, so a non-symbol,
  # non-#f eof-target is accepted and stored verbatim; the thunk returns
  # instead of raising. This harness case did not exist before this fix wave
  # (added above, beside the pre-existing "an eof-target of #f is legal"
  # case) -- until now nothing proved the eof-target guard rejects anything.
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a non-symbol, non-#f eof-target is rejected: bad eof-target")

# Slice ② task 1 adds SEVEN for the two zero-width node kinds. The
# constructor/verifier boundary they encode is decision 0020's, and the mutations
# are of the CONSTRUCTOR half only -- arity, declared-field references, operand
# range and `low <= high` are pass 6a's and are Task 4's mutations, not these.
#
# No mutation is written for `graph.sls`'s two export lists, following Slice ①b's
# precedent ("the facade being two export lists with no decision of its own").
# Measured anyway, so the precedent is followed knowingly rather than assumed:
# dropping either list's names fails at EXPAND time with exit 255 -- an unbound
# identifier for the export list, "missing definition for multiple exports" for
# the import list -- and graph-tests.sps's own case cannot load at all. That is a
# louder witness than a pin, and pinning it would cost a whole new pass (there is
# no graph-tests verify command in this suite) for two decisions already fatal.

# Slice ③ task 1 adds SEVEN for the integer-accumulate node -- the milestone's
# last kind, and its only INPUT-READING one.
#
# The constructor/verifier boundary here is 0017's, not 0020's: 0020 item 2
# keeps the constructor out of `arguments` because that is a LIST whose length it
# may not assume, and this kind has no `arguments` -- its operands are NAMED
# PARAMETERS, the situation 0017 point 1 addresses. So `base` is closed here and
# gets a mutation; the FIELD REFERENCE is the verifier's and gets one too, in the
# restrictive direction, because closing it here would be the boundary error.

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: the accumulate base set admits an unsupported base"
  # §16.2:904's base half, discharged at construction rather than as a
  # diagnostic: a base is evaluable from the one node being built, so a verifier
  # arm would be dead code whose permissive mutation survives (0020's
  # one-rejection-site rule).
  FIND [[  (define accumulate-bases '(10 16))]]
  REPLACE [[  (define accumulate-bases '(10 16 8))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "integer-accumulate nodes.both bases are accepted and nothing else is: base 8 -- expected a raise")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: an accumulate node's nondigit fallback need not be an edge"
  # It is an EDGE, not a bare target, because §10.6:567's non-digit "takes an
  # explicit fallback edge, normally reexecuting the delimiter" -- the MODE is
  # the whole point and a bare symbol cannot carry one.
  FIND [[    (unless (edge? nondigit-edge)
]]
  REPLACE [[    (unless #t
]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "integer-accumulate nodes.the nondigit edge must be an edge: a bare symbol -- expected a raise")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: an accumulate node's overflow-error may be absent"
  # Never #f, unlike a field action's `error`: accumulation can ALWAYS overflow,
  # so there is nothing for the can-it-fail rule to decide and §10.6:568's
  # "explicit error edge" is unconditional.
  FIND [[    (require-symbol 'make-integer-accumulate-node 'overflow-error overflow-error)
]]
  REPLACE [[    ]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "integer-accumulate nodes.the overflow-error is a mandatory symbol: absent -- expected a raise")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: an accumulate node's eof-target is unchecked"
  # Symbol or #f, the byte-dispatch convention (§9.1:318), where #f means the
  # machine default-eof error.
  FIND [[    (unless (or (eq? eof-target #f) (symbol? eof-target))
]]
  REPLACE [[    (unless #t
]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "integer-accumulate nodes.the eof-target is a symbol or #f: a number -- expected a raise")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: node? does not admit an integer-accumulate node"
  # The two census sites every new kind must join. One mutation per site, so a
  # half-taught pair cannot pass.
  FIND [[        (integer-accumulate-node? x) (callback-node? x)
        (span-start-node? x) (span-end-node? x) (counted-consume-node? x)))]]
  REPLACE [[        (callback-node? x)
        (span-start-node? x) (span-end-node? x) (counted-consume-node? x)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "integer-accumulate nodes.it is a node and answers node-name: node\\? -- expected a true value")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: node-name does not answer for an integer-accumulate node"
  FIND [[          ((integer-accumulate-node? x) (integer-accumulate-node-name x))
]]
  REPLACE [[          ]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "integer-accumulate nodes.it is a node and answers node-name: case raised")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: the constructor closes the field REFERENCE, which is the verifier's"
  # The RESTRICTIVE direction, and the boundary itself. Closing the field
  # reference here would need the declaration list, which one node cannot see --
  # this mutant fakes it with a fixed set, and the case that catches it is the
  # one asserting an undeclared name still BUILDS.
  FIND [[    (require-symbol 'make-integer-accumulate-node 'field field)]]
  REPLACE [[    (unless (memq field '(count)) (byte-machine-contract-violation 'make-integer-accumulate-node 'invalid-argument 'field))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "integer-accumulate nodes.the field reference is NOT checked here: case raised")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: the field operation set admits a name outside the closed enumeration"
  # §9.1:348's "it rejects arbitrary operation names" -- the ONE clause of that
  # sentence pass 6a does not carry (decision 0020 item 4), because a closed set
  # is evaluable from the node alone.
  FIND [[  (define field-operations '(store clear increment decrement add set-mask clear-mask))]]
  REPLACE [[  (define field-operations '(store clear increment decrement add set-mask clear-mask multiply))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "an operation outside the closed set is refused: not an operation")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: the field predicate set admits a name outside the closed enumeration"
  FIND [[  (define field-predicates '(equal zero nonzero range mask-any mask-all mask-none))]]
  REPLACE [[  (define field-predicates '(equal zero nonzero range mask-any mask-all mask-none greater))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a predicate outside the closed set is refused: not a predicate")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: a field action's arguments are not checked as a proper list"
  # The whole of what 0020 item 2 permits here. The paired assertion -- that a
  # WRONG ARITY still builds -- has no mutation, by design: making the
  # constructor read the schema is the defect this line's comment forbids, and a
  # mutation that ADDS a check is not a mutation this suite can express.
  FIND [[    (require-proper-list 'make-field-action-node 'arguments arguments)
]]
  REPLACE [[    ]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "arguments must be a proper list, and nothing more is read: improper")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: the error-slot rule is inverted"
  # Design §4.4's rule: `error` is #f EXACTLY when the operation cannot fail.
  # Pinned on a VALID construction failing, which is the record the permissive
  # direction below cannot produce.
  FIND [[      (when (eq? safe (and (symbol? error) #t))]]
  REPLACE [[      (when (not (eq? safe (and (symbol? error) #t)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a field action carries its six parts: case raised")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: the error-slot rule never fires"
  # *** SUBSUMED BY the inverted mutation above, BY CONSTRUCTION, and written
  # anyway. *** Measured in both directions: this mutant never raises, so on
  # every combination it fails to reject, the inverted one fails to reject too --
  # its record set is a strict subset, and no fixture can separate them, because
  # "never raises" is contained in "raises only on the valid combinations". The
  # conjunction below is therefore matched by the inverted mutant as well; that
  # is a collision in attribution, not in detection, and it is recorded rather
  # than papered over. The two name distinct decisions -- that the rule exists at
  # all, and that it points the right way -- so both are kept.
  FIND [[      (when (eq? safe (and (symbol? error) #t))
        (byte-machine-contract-violation 'make-field-action-node 'invalid-argument 'error))]]
  REPLACE [[      (when #f
        (byte-machine-contract-violation 'make-field-action-node 'invalid-argument 'error))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the error slot is #f exactly when the operation cannot fail: safe op with a target -- expected a raise.*failing op without one -- expected a raise")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: node? does not admit a field action"
  # `node?` and `node-name` are the two census sites EVERY new kind must join,
  # and missing either is silent at construction and loud much later. One
  # mutation per site, per kind, so a half-taught pair cannot pass.
  # Re-anchored by Slice ③ task 1: `node?` gained the integer-accumulate kind and
  # the disjunction reflowed onto three lines. The decision and the pin are
  # unchanged -- this still drops the field-action disjunct.
  FIND [[        (field-action-node? x) (field-branch-node? x)
        (integer-accumulate-node? x) (callback-node? x)
        (span-start-node? x) (span-end-node? x) (counted-consume-node? x)))]]
  REPLACE [[        (field-branch-node? x)
        (integer-accumulate-node? x) (callback-node? x)
        (span-start-node? x) (span-end-node? x) (counted-consume-node? x)))]]
  EXPECT_STATUS 1
  # `?` is a regex metacharacter -- unescaped, `node? --` matches "nod --",
  # which no output contains, and the runner reports a wrong-reason catch.
  EXPECT_OUTPUT_MATCHES
    "field-action nodes.it is a node and answers node-name: node\\? -- expected a true value")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: node-name does not answer for a field branch"
  FIND [[          ((field-branch-node? x) (field-branch-node-name x))
]]
  REPLACE [[          ]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "field-branch nodes.it is a node and answers node-name: case raised")

# Milestone 5 Slice ② task 1: the TENTH node kind. The two census sites every
# kind must join (`node?` and `node-name`), and the four local-shape decisions
# `make-callback-node` owns. Its three CROSS-references -- the callback name,
# the branch keys, and whether the declaration is a decision -- get no mutation
# here on purpose: this constructor makes none of those judgements, and the
# ir-tests case that asserts it makes none of them is the witness for that.
byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: node? does not admit a callback node"
  FIND [[        (integer-accumulate-node? x) (callback-node? x)
        (span-start-node? x) (span-end-node? x) (counted-consume-node? x)))]]
  REPLACE [[        (integer-accumulate-node? x)
        (span-start-node? x) (span-end-node? x) (counted-consume-node? x)))]]
  EXPECT_STATUS 1
  # `?` is a regex metacharacter -- unescaped, `node? --` matches "nod --", which
  # no output contains, and the runner reports a wrong-reason catch.
  EXPECT_OUTPUT_MATCHES
    "callback-invocation nodes.it is a node and answers node-name: node\\? -- expected a true value")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: node-name does not answer for a callback node"
  # `node-name`'s cond has a RAISING else and nothing derives it, so the mutant
  # crashes rather than answering wrongly -- which is why the pin is on the
  # raise here and on the comparison in the sibling above.
  FIND [[          ((callback-node? x) (callback-node-name x))
]]
  REPLACE [[          ]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "callback-invocation nodes.it is a node and answers node-name: case raised")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: a callback node's continue target may be absent"
  # A SWAP PAIR with the mutation below: each REPLACE is the other's surviving
  # line, so the two move in lockstep. §10.6:586 makes both mandatory.
  FIND [[    (require-symbol 'make-callback-node 'continue-target continue-target)
    (require-symbol 'make-callback-node 'pause-continuation pause-continuation)]]
  REPLACE [[    (require-symbol 'make-callback-node 'pause-continuation pause-continuation)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "mandatory symbols: continue-target absent -- expected a raise")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: a callback node's pause continuation may be absent"
  FIND [[    (require-symbol 'make-callback-node 'continue-target continue-target)
    (require-symbol 'make-callback-node 'pause-continuation pause-continuation)]]
  REPLACE [[    (require-symbol 'make-callback-node 'continue-target continue-target)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "mandatory symbols: pause-continuation absent -- expected a raise")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: a callback node's branch entries need not be two-element lists"
  # §9.1:318's convention, and the one Slice ①b's review caught being
  # implemented as pairs. Narrowed to `list?` alone, the pair form and the
  # three-element form both build.
  FIND [[                            (and (list? b) (= (length b) 2)
                                 (symbol? (car b)) (symbol? (cadr b))))]]
  REPLACE [[                            (list? b))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "branch targets are two-element lists, not pairs: a three-element list -- expected a raise")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: a callback node's branch list is stored rather than copied"
  # §9.1:322's immutable-by-API descriptor, on the make-sequence-case
  # precedent. Witnessed by identity, so the mutant is observationally
  # different even though every stored VALUE is equal.
  FIND [[            (map (lambda (b) (list (car b) (cadr b))) branch-targets)]]
  REPLACE [[            branch-targets]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the branch list is copied at construction: a fresh spine -- expected a true value")

# Milestone 5 Slice ③ task 1: the ELEVENTH and TWELFTH node kinds. `node?` and
# `node-name` are the two census sites every kind must join; the mandatory `next`
# is the only local-shape decision either constructor owns.
byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: node? does not admit a span-start node"
  FIND [[        (span-start-node? x) (span-end-node? x) (counted-consume-node? x)))]]
  REPLACE [[        (span-end-node? x) (counted-consume-node? x)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "and each carries all four parts -- expected .., got .span-start.")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: node? does not admit a span-end node"
  FIND [[        (span-start-node? x) (span-end-node? x) (counted-consume-node? x)))]]
  REPLACE [[        (span-start-node? x) (counted-consume-node? x)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "and each carries all four parts -- expected .., got .span-end.")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: node-name answers for neither span kind"
  # BOTH arms in one mutation, and the reason is recorded rather than left to a
  # reader: `node-name`'s else RAISES, so dropping either arm alone stops the
  # table-driven case at the same point with the same record. Two mutations
  # would be indistinguishable; the pair is one decision -- the kinds joined the
  # cond -- and it gets one mutation.
  FIND [[          ((span-start-node? x) (span-start-node-name x))
          ((span-end-node? x) (span-end-node-name x))
]]
  REPLACE [[          ]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "span nodes.each carries its four parts and is a node: case raised")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: a span-start node's next may be absent"
  # §10.6:590 gives the kind no route of its own, so there is no #f arm to
  # defend. Its sibling below is the same decision for the other kind, and they
  # are separable because the case names the kind that failed.
  FIND [[    (require-symbol 'make-span-start-node 'next next)]]
  REPLACE [[    (require-symbol 'make-span-start-node 'span span)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "start next -- expected a raise")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: a span-end node's next may be absent"
  FIND [[    (require-symbol 'make-span-end-node 'next next)]]
  REPLACE [[    (require-symbol 'make-span-end-node 'span span)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "end next -- expected a raise")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: the two span kinds share one tag"
  # The defect a table driven by predicates cannot see: if both builders make
  # the same thing and both predicates answer for it, every part-by-part row
  # passes. Only the distinguishability case notices.
  FIND [[  (define span-end-node-tag (tag 'byte-machine-span-end-node))]]
  REPLACE [[  (define span-end-node-tag span-start-node-tag)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the two kinds are distinguishable")

# Milestone 6 Slice ⓪: `node-source-label`'s arm for one kind answers ABSENCE.
# Caught by comparison in the twelve-kind case (and again by the verifier lane's
# stop row, under another SPEC). NOT pinned: an arm swapped for a same-slot
# sibling's accessor -- `stop` and `finish` both store the label at slot 2 and
# every `-source-label` accessor is an unguarded `vector-ref`, so that mutant is
# observationally identical and would ship UNCAUGHT. The arm-DELETION mutant is
# the census pass's, where the derived S2b row is what sees it.
byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: node-source-label answers #f for a stop node"
  FIND [[((stop-node? x) (stop-node-source-label x))]]
  REPLACE [[((stop-node? x) #f)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "each answers its own label -- expected .., got .stop.")


# --- Milestone 6 Slice ① task 1: the thirteenth kind's constructor and dispatch --
byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: a counted-consume node's next may be absent"
  FIND [[    (require-symbol 'make-counted-consume-node 'next next)
]]
  REPLACE [[    ]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "fourteenth constructor refusal: absent -- expected a raise")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: a counted-consume node's eof-target is unchecked"
  # The `or` is written in the byte-dispatch operand order on purpose: the
  # accumulate constructor's order is pinned at one site and a verbatim copy
  # would take that FIND to two. This FIND is unique through its second line,
  # which names this constructor.
  FIND [[    (unless (or (symbol? eof-target) (eq? eof-target #f))
      (byte-machine-contract-violation 'make-counted-consume-node]]
  REPLACE [[    (unless #t
      (byte-machine-contract-violation 'make-counted-consume-node]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "meaning the machine default .§9.1:318.: a number -- expected a raise")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: node? does not admit a counted-consume node"
  FIND [[        (span-start-node? x) (span-end-node? x) (counted-consume-node? x)))]]
  REPLACE [[        (span-start-node? x) (span-end-node? x)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "counted-consume nodes .Milestone 6 Slice ①..it is a node and answers node-name and node-source-label: node\\? -- expected a true value")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: node-name does not answer for a counted-consume node"
  # `node-name`'s cond has a RAISING else, so the mutant crashes rather than
  # answering wrongly; the pin is on the raise, as for every sibling arm.
  FIND [[          ((counted-consume-node? x) (counted-consume-node-name x))
]]
  REPLACE [[          ]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "counted-consume nodes .Milestone 6 Slice ①..it is a node and answers node-name and node-source-label: case raised")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: node-source-label answers #f for a counted-consume node"
  # The Slice ① sweep: also satisfied by "ir: node? does not admit a
  # counted-consume node" -- node-builders' one check conjoins node? with the
  # label answer, so a kind node? refuses fails it the same way. By construction.
  FIND [[((counted-consume-node? x) (counted-consume-node-source-label x))]]
  REPLACE [[((counted-consume-node? x) #f)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "each answers its own label -- expected .., got .counted-consume.")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# Milestone 4 Slice ①b task 2 declares NO mutation, deliberately, and this note
# is the record of why rather than an omission.
#
# The decision is that graph.sls's export list and its mirrored `only` import
# list move together. A mutation dropping a name from one of them was written
# and MEASURED: under this suite's launcher it exits 255 with no harness output
# at all, because a missing export is an expand-time failure -- the library never
# loads, so no case runs and there is nothing to match. That is the bare
# nonzero-exit catch AGENTS.md forbids, wearing no signature.
#
# What actually guards the decision is stronger than a mutation: an identifier
# in one list and not the other makes (byte-machine graph) unloadable, so EVERY
# lane importing it fails at once, loudly, at build time. There is no input that
# reaches a half-edited façade and survives.
#
# (Measured aside: run OUTSIDE the launcher the same mutant surfaces as a
# harness case raise with status 1, because the reference is inside a lambda.
# Pinning that would have recorded a signature this suite never produces.)


# --- Pass 43: class membership and recursive canonicalization (M3 Slice ①
# Task 5) --------------------------------------------------------------------
#
# byte-class-interpret-tests.sps drives five class fixtures over all 256 bytes
# with ABSOLUTE expected outcomes. Two decisions here are unreachable from every
# earlier lane, because every earlier fixture's matcher is a one-element set:
# `memv` over the whole canonical set (for a singleton, `memv` and `= (car ...)`
# agree, so Pass 34's one-byte machine cannot separate them), and the recursion
# through a nested complement. The first mutation matches only a class's lowest
# byte; the second stops complement canonicalization recursing, so a
# complement-of-a-complement is read as its own inner matcher. Verify command
# uses both library roots, an empty object guard, the byte-class program.

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/byte-class-interpret-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.byte-class.chez.source
  LABEL "interpret: class membership matches only the class's lowest byte"
  FIND [[((memv byte (matcher-bytes (byte-case-matcher (car cs))))]]
  REPLACE [[((= byte (car (matcher-bytes (byte-case-matcher (car cs)))))]]
  # The brief's own predicted pin, "accepted exactly the class size", was a
  # bare check label the brief flagged as possibly colliding. At the time
  # this pass was first written, it did not merely collide, it never fired at
  # all: `hits` counted membership in the test's own precomputed `accepted`
  # list (memv b accepted), not whether the byte actually stopped, so that
  # check passed unchanged under this mutant regardless of matcher behaviour.
  # A whole-branch review fix wave made `hits` a genuine behavioural count
  # (observed stopped/consumed = 1, not list membership), and re-measuring
  # this mutation against the fixed test shows "accepted exactly the class
  # size" now reddens as originally predicted: with only the class's lowest
  # canonical byte still matching the dispatch case, exactly one byte ever
  # stops, so `hits` collapses to 1 for every fixture while the class size it
  # is compared against (5, 26, 254, 10, 3) differs per fixture. Pinned to
  # this check, not "no byte misbehaved" (which also still reddens here), so
  # this pass demonstrates the fixed sentinel is the one doing the catching.
  # Measured FAIL line: "FAIL all 256 byte values, per class.byte-set accepts
  # exactly its class: accepted exactly the class size -- expected 5, got 1".
  # Each fixture's "expected N" is unique across the whole run, so the bare
  # detail alone would already resolve to one (case, check) pair, but the
  # case-name prefix is kept for robustness against a future fixture whose
  # class size happens to coincide.
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "byte-set accepts exactly its class: accepted exactly the class size -- expected 5, got 1")

# The REPLACE below canonicalizes a complement's inner matcher normally UNLESS
# that inner matcher is itself a complement, in which case it reads as the empty
# set -- so a nested complement becomes the full universe while every
# single-level complement is untouched. That isolates the recursion specifically,
# and it is caught by a failed comparison rather than by a raise (AGENTS.md):
# handing `memv` a vector instead of a list would crash somewhere incidental
# rather than redden the assertion that names the decision.
byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.byte-class.chez.source
  LABEL "ir: complement canonicalization does not recurse"
  FIND [[(let ((inner (matcher-bytes (byte-complement-matcher-matcher m))))]]
  REPLACE [[(let ((inner (if (byte-complement-matcher? (byte-complement-matcher-matcher m)) (quote ()) (matcher-bytes (byte-complement-matcher-matcher m)))))]]
  # The prior pin, "nested-complement accepts exactly its class", matched only
  # the case-name segment. That case carries three checks, so the pin was
  # case-scoped, not signature-scoped -- any of the three failing would have
  # satisfied it, not just the one this mutation is meant to demonstrate.
  # Extended to the full measured line so the pin names exactly one
  # (case, check) pair. Re-measured after the `hits` fix wave: the
  # mis-canonicalized nested complement now reads as accepting the whole
  # universe, so both "no byte misbehaved" (byte 0 is the first byte that
  # wrongly stops) and "accepted exactly the class size" (hits climbs to 256)
  # redden on this same case; pinned to "no byte misbehaved" because it fires
  # first in check order and is the more direct statement of the defect --
  # the matcher accepting bytes it must reject -- while "accepted exactly the
  # class size" is downstream arithmetic on the same wrong behaviour. No
  # CMake-regex metacharacters in the pin, so no escaping is needed.
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "nested-complement accepts exactly its class: no byte misbehaved -- expected none, got 0")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 44: the byte-class differential is non-vacuous (M3 Slice ① Task 6) --
#
# differential-byte-class-tests.sps compares the interpreter against the emitted
# library over all 256 bytes for five class fixtures. Shifting every rendered
# transition byte by one makes the generated executor accept a class shifted one
# byte up, so the comparison diverges at the class's first byte. Verify command
# uses both library roots, an empty object guard, the differential program.

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/differential-byte-class-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.byte-class.chez.source
  LABEL "compile: every rendered transition byte is shifted by one"
  FIND [[(string-append "               ((" (number->string (car tr)) ") "]]
  REPLACE [[(string-append "               ((" (number->string (+ 1 (car tr))) ") "]]
  # Measured against a scratch tree: byte-set is the first fixture in
  # class-machines, so it is the first case in "interpreter and generated agree
  # on every byte, for every class" to run, and its lowest class byte (0) is the
  # one whose rendered arm is shifted away from key 0 to key 1 -- so the
  # generated side stops matching it and falls through to the dispatch node's
  # own reject/reexecute default, diverging from the (unmutated) interpreter at
  # byte 0. Measured FAIL line: "byte-machine-harness: FAIL interpreter and
  # generated agree on every byte, for every class.byte-set agrees on all 256
  # bytes: no byte disagreed -- expected none, got 0". Pinned to byte-set's own
  # case name plus the check label so the pin resolves to one (case, check)
  # pair, not the five fixtures' shared case-name tail ("agrees on all 256
  # bytes: no byte disagreed") the brief flagged as needing narrowing.
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "byte-set agrees on all 256 bytes: no byte disagreed -- expected none, got 0")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 45: the sequence-node absolute interpreter lane is non-vacuous (M3 --
# Slice ② Task 4) ---------------------------------------------------------------
#
# sequence-interpret-tests.sps is the first fixture anywhere in this tree built
# with mismatch mode 'advance (make-advance-mismatch-machine, 'advseq) --
# every other shipped sequence fixture (sequence-machine.sls, pause-machine.sls,
# and Task 3's own interpret-tests.sps fixtures) uses 'reexecute, so the
# advance-mode arithmetic (consumed=1, next=1, offset=k+1 rather than
# consumed=0, next=0, offset=k) has had no witness anywhere before this pass.
# Both mutations below hardcode seq-step's `(edge-mode mm)` read to a fixed
# symbol, so the interpreter answers with one mode's arithmetic regardless of
# what the machine actually declared; the third re-witnesses the completed-
# alternative-target decision through this lane's own single-alternative
# fixture. Verify command uses both library roots, an empty object guard, the
# new absolute program.

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/sequence-interpret-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.sequence-node.chez.source
  LABEL "interpret: the mismatch edge's declared mode is ignored in favour of reexecute"
  # Hardcoding to 'advance leaves the REEXECUTE fixture (seqnode) wrong -- a
  # mismatching byte gets consumed and every position shifts by one -- while
  # the ADVANCE fixture (advseq) is left coincidentally correct, so only
  # seqnode's own checks can catch this. Measured against a scratch stage, not
  # the committed tree: cases=10 checks=25 failures=5, failing seqnode's
  # all-256 case (one check) and all four k= checks in "reexecute leaves next
  # and consumed at zero and the offset at the prefix". Comparison-caught.
  # Pin sweep: this pin's exact tuple pair is the mirror image of the
  # 'reexecute mutation below's own pin (0 0 0 / 1 1 1 vs 1 1 1 / 0 0 0) and
  # absent from that mutation's captured output and from the completed-
  # alternative-target mutation's output (both re-measured and grepped).
  # RE-ANCHORED by Milestone 11 Slice ①: the keyword-table walk added a second
  # `(cons (edge-target mm) (edge-mode mm))` (its no-match edge, bound through
  # keyword-table-node-no-match), so the bare cons now occurs twice. Anchored on
  # seq-step's own `sequence-dispatch-node-mismatch` binder to stay unique; the
  # edit and witness are unchanged.
  FIND [[(let ((mm (sequence-dispatch-node-mismatch n)))
                   (cons (edge-target mm) (edge-mode mm))))]]
  REPLACE [[(let ((mm (sequence-dispatch-node-mismatch n)))
                   (cons (edge-target mm) 'advance)))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "k=0 -- expected \\(error 0 0 0 unexpected-byte\\), got \\(error 1 1 1 unexpected-byte\\)")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.sequence-node.chez.source
  LABEL "interpret: the mismatch edge's declared mode is ignored in favour of advance"
  # The opposite hardcode: the ADVANCE fixture (advseq) is now wrong and the
  # REEXECUTE fixture (seqnode) is coincidentally correct, so only advseq's own
  # checks catch it -- proving 'reexecute is genuinely read too, not merely
  # the default every machine happens to declare. Measured against a scratch
  # stage: cases=10 checks=25 failures=5, failing advseq's all-256 case and all
  # four k= checks in "advance consumes the offending byte and shifts every
  # position by one". Comparison-caught.
  # RE-ANCHORED by Milestone 11 Slice ① for the same reason as the sibling above:
  # anchored on seq-step's `sequence-dispatch-node-mismatch` binder so the FIND
  # is unique against the keyword-table walk's own no-match cons.
  FIND [[(let ((mm (sequence-dispatch-node-mismatch n)))
                   (cons (edge-target mm) (edge-mode mm))))]]
  REPLACE [[(let ((mm (sequence-dispatch-node-mismatch n)))
                   (cons (edge-target mm) 'reexecute)))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "k=0 -- expected \\(error 1 1 1 unexpected-byte\\), got \\(error 0 0 0 unexpected-byte\\)")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.sequence-node.chez.source
  LABEL "interpret: a completed alternative routes to another prefix instead of its declared target"
  # Same defect, same FIND/REPLACE, as Pass 34's Task 3 mutation of the same
  # name -- deliberately: that mutation's witness runs through
  # interpret-tests.sps's multi-alternative AB/XY trie fixtures under a
  # DIFFERENT SPEC (byte-machine.unit.interpret.chez.source); this lane's own
  # single-alternative fixture needs its own witness of the same decision
  # (AGENTS.md: a mutation's witnessing test lives in its own SPEC lane's
  # program). Folding a completed alternative into the "extend the compound"
  # shape means the four-byte sequence never terminates: the parser reports
  # need-input at stream-offset 4 instead of stopping. Measured against a
  # scratch stage: cases=10 checks=25 failures=1, only "the full sequence
  # stops at stream-offset 4" failing -- the all-256 group and the mismatch-
  # mode group are untouched by this mutation (re-measured and grepped against
  # both mode mutations' captured output above: this pin appears in neither).
  # Comparison-caught.
  FIND [[((pair? ends) (cons (sequence-case-target (car ends)) 'advance))]]
  REPLACE [[((pair? ends) (cons (cons (sequence-dispatch-node-name n) new) 'advance))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "the full sequence stops at stream-offset 4: stopped -- expected \\(stopped 1 1 4 #f\\), got \\(need-input 1 1 4 #f\\)")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 46: the sequence-node differential is non-vacuous (M3 Slice ② -----
# Task 5) ------------------------------------------------------------------
#
# differential-sequence-node-tests.sps is the slice's independent oracle: a
# single-alternative sequence node must reproduce sequence-machine.sls's four
# CHAINED DISPATCH NODES exactly, over tuples measured before this node kind
# existed. Both executors read the same source IR (the normalizer lowers a
# sequence-dispatch node to an ordinary trie of dispatch nodes before the
# emitter ever sees it -- decision 0015 point 1), so agreement alone cannot
# prove the lane is worth its runtime: a divergence has to be reachable, and
# the interpreter never reads compile.sls, so the emitter is the only module a
# mutation here can touch and still make the two sides disagree. Verify
# command uses both library roots, an empty object guard, the new
# differential program.
#
# AMENDMENT, whole-branch review fix wave (2026-08-30): this program's baseline
# CHECK count moved, so every measurement recorded below and in Pass 49's
# header that quotes it is quoting the tree it was taken against, not this one.
# The exhaustive group's case ("256 x 4 positions match, in both mismatch
# modes") shipped a vacuous sentinel -- a `positions` counter incremented from
# the literal '(0 1 2 3) the for-each walks, so 4 by construction, and a
# `last-byte` slot shared across the four positions, so 255 as soon as any one
# inner loop finished. Both were replaced by one (position byte) drive counter
# asserted at 1024, which is three checks becoming two. Measured after the
# change on a scratch stage: baseline cases=14 failed-cases=0 CHECKS=29
# failures=0 status=0 (it was checks=30 in every record below). Both mutations
# in this pass were re-measured against it -- the byte shift now reports
# cases=14 failed-cases=14 checks=29 failures=16 status=1, the sticky-stopped
# row cases=14 failed-cases=1 checks=29 failures=2 status=1 -- and both pins
# still catch their own mutant, neither pin naming a check that changed. Pin
# sweep re-run in both directions at 2 mutations / 2 ordered pairs (n(n-1)):
# zero collisions, unchanged from the record at each pin.

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/differential-sequence-node-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.sequence-node.chez.source
  LABEL "compile: every rendered transition byte is shifted by one (sequence-node lane)"
  FIND [[(string-append "               ((" (number->string (car tr)) ") "]]
  REPLACE [[(string-append "               ((" (number->string (+ 1 (car tr))) ") "]]
  # Same FIND/REPLACE as Pass 44's byte-class mutation, and (for the small
  # byte values this lane's sequence uses) functionally the same shift as
  # Pass 39's mod-256 mutation. Legitimate per AGENTS.md/SITES being
  # per-mutation: each byte_machine_mutation() call reads a pristine copy of
  # compile.sls and restores it afterward, so three passes carrying the same
  # render-transition-arm decision under three different SPEC lanes is the
  # same defect re-witnessed where each lane's own fixture can see it, not
  # three copies of one test (AGENTS.md: "a mutation's witnessing test lives
  # in its own SPEC lane's program"). FIND measured unique in the file (one
  # occurrence, confirmed on a scratch copy).
  #
  # Measured against a scratch stage, not the committed tree: baseline
  # cases=12 checks=25 failures=0 status=0; mutant cases=12 failed-cases=12
  # checks=25 failures=13 status=1. Comparison-caught throughout (check-equal
  # failures, no raise).
  #
  # Pin sweep, both directions, against every other pass that also mutates
  # compile.sls (Passes 36-40, 44). The mutant's very FIRST reported failure --
  # "the full sequence in one slice stops after four bytes in both: generated
  # -- expected (stopped 4 4 4 #f), got (error 0 0 0 unexpected-byte)" -- is
  # NOT usable as this mutation's pin: re-measured, Pass 36's "advance
  # transition lowered as reexecute" mutation, run against this same program,
  # reaches the byte-identical line by a different mechanism (state 0's
  # matching transition stops advancing pos/off, so state 1 then fails to
  # match the still-unconsumed byte and lands on the same all-zero error
  # tuple). Re-measured the full output of that mutation and Pass 36's
  # "reexecute fallback lowered as advance" and "error arm omits the resolved
  # code" siblings against this program too: none of the three touches the
  # dispatch CASE key this mutation shifts, so all three diverge first at byte
  # 0 ("(advance 0 0)" / "(reexecute 0 0)" / "(reexecute 0 0)" on the
  # all-256-bytes check) where this mutation diverges first at byte 1
  # ("(reexecute 0 1)", because the shift moves state 0's own accepted byte
  # from 1 to 2). Pinned to that check instead, which the sweep confirms no
  # sibling reaches. Pass 39's mod-256 mutation reproduces this pin exactly
  # when re-measured against this program (expected: `(+ 1 b)` and
  # `(mod (+ 1 b) 256)` agree for b in 1..4, so it is the same decision, not a
  # collision -- and it is declared under a different SPEC, so it never
  # actually runs against this verify command). Control: this lane and
  # mutation do not exist on `main`, so there is no prior baseline to
  # re-measure; the meaningful control is the sweep above, against the
  # sibling passes that already exist on this branch.
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "256 x 4 positions match, in both mismatch modes: no \\(mode position byte\\) disagreed -- expected none, got \\(reexecute 0 1\\)")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.sequence-node.chez.source
  LABEL "runtime: the sticky-stopped row's next is the call's start, not a fixed zero (sequence-node lane)"
  # Re-review, Task 5 fix wave 2: parser-feed!'s sticky-stopped arm is shared
  # code reached before either executor variant is dispatched to, so this
  # decision has nothing to do with the emitter the mutation above targets --
  # it is witnessed here (rather than left to Pass 32, where the sibling
  # error- and pause-arm `next` mutations already live) because this SPEC
  # lane's own new nonzero-start case is what actually reddens for it
  # (AGENTS.md: a mutation's witness lives in its own SPEC lane's program).
  # FIND measured unique in the file (one occurrence).
  #
  # Before this task's new "a nonzero-start trailing empty feed separates
  # next from start, zero, and offset" case existed, this exact mutation was
  # UNCAUGHT by this program: measured directly against the unedited,
  # committed differential-sequence-node-tests.sps (git show HEAD), status=0,
  # no FAIL lines -- the pre-existing "a trailing empty feed after the
  # sequence completes stays stopped" case feeds from start 0, so a next
  # hardcoded to the literal 0 reads identically to the correct start there.
  # (A DIFFERENT mutation of the same arm -- swapping `start` for
  # `(parser-offset parser)` instead of a literal 0 -- was already caught by
  # that same pre-existing case, and separately by runtime-tests.sps's
  # pre-existing "a repeat feed on a terminal parser" case: both happen to
  # reach the sticky arm with a nonzero persisted offset even though their
  # own slice starts at 0, so offset and start already disagreed there. Only
  # the plain literal-0 hardcode needed a new witness.)
  #
  # Measured against a scratch stage with this task's new case added: cases=14
  # failed-cases=1 checks=30 failures=2 status=1, both failures on the new
  # case's own two checks ("interpreter after completion" and "generated
  # after completion"), each "expected (stopped 5 0 4 #f), got
  # (stopped 0 0 4 #f)". Comparison-caught (check-equal failures, no raise).
  #
  # Pin sweep against the sibling compile.sls mutation above, both directions,
  # re-measured on a scratch stage: that mutation never fails this case's
  # "interpreter after completion" check at all (cm-ref never reads
  # compile.sls, so no compile.sls mutation in this pass can produce that
  # check's FAIL line), and its own "generated after completion" failure
  # reads "got (error 5 0 0 unexpected-byte)" -- disjoint from this
  # mutation's "got (stopped 0 0 4 #f)". Pinned to the "interpreter after
  # completion" check for exactly that reason: it is structurally immune to
  # every mutation this pass's sibling entry could ever carry. Control: this
  # lane, case, and mutation do not exist on `main`, so there is no prior
  # baseline to re-measure; the meaningful control is the sweep just
  # described, against the one sibling mutation that already exists on this
  # branch under the same verify command.
  FIND [[(make-parser-result 'stopped start 0 (parser-offset parser) #f))]]
  REPLACE [[(make-parser-result 'stopped 0 0 (parser-offset parser) #f))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "a nonzero-start trailing empty feed separates next from start, zero, and offset: interpreter after completion -- expected \\(stopped 5 0 4 #f\\), got \\(stopped 0 0 4 #f\\)")

# Milestone 5 Slice ② task 4: `parser-state-name`, the accessor Slice ①b
# deferred whole. This lane is its SPEC because a lowered sequence is the one
# shape in the tree where the two lanes hold structurally different things at a
# parked position -- the compound `(seq . bytes)` and an integer id naming no
# source node -- which is exactly why ①b could not ship it.
byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.sequence-node.chez.source
  LABEL "compile: the emitted state-name table is rendered empty"
  # ABI payload member 2. Empty, the generated lane has nothing to answer from
  # and `parser-state-name` fails on the index -- so the caught record is a
  # raise, and it is the decision's own consequence rather than an incidental
  # crash: the table's whole purpose is to be indexed by the current state.
  FIND [[           (snames (let sloop ((i 0) (acc ""))
                     (if (>= i (vector-length states)) acc]]
  REPLACE [[           (snames (let sloop ((i 0) (acc ""))
                     (if #t acc]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "both lanes answer the declaring node at every prefix depth: case raised")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.differential.sequence-node.chez.source
  LABEL "interpret: parser-state-name answers the compound mid-sequence"
  # §13:820 requires "the source callback/span node, not a generated internal
  # continuation". Unwrapping the compound is the whole of this lane's half of
  # that sentence, and the mutant answers `(seq 1)` where the generated lane
  # answers `seq` -- a failed COMPARISON naming both sides.
  FIND [[           ((state-name) (let ((c (car args))) (if (pair? c) (car c) c)))]]
  REPLACE [[           ((state-name) (car args))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "both lanes answer the declaring node at every prefix depth: and each names the sequence node")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.sequence-node.chez.source
  LABEL "runtime: parser-state-name reads the entry rather than the current state"
  # The accessor is about WHERE THE PARSER IS. Reading the entry answers
  # correctly for a fresh parser -- which is why the bookend case checks a
  # stopped one too -- and wrongly everywhere else.
  # RE-ANCHORED by Milestone 11 Slice ①: the v2 arm now binds `current` to `c`
  # and unwraps the keyword-table compound (decision 0044); the mutation still
  # reads the entry instead, so the witness is unchanged.
  FIND [[      ((v2) (let ((c (parser-current parser)))]]
  REPLACE [[      ((v2) (let ((c (parser-entry parser)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a fresh parser names the entry, and a finished one its terminal: stopped, both lanes")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 47: the multi-alternative absolute lane is non-vacuous (M3 Slice ③ --
# Task 3) ----------------------------------------------------------------------
#
# http-version-interpret-tests.sps drives TWO alternatives over a shared prefix
# end to end, with absolute tuples: the §21.2 `version` production, whose seven
# shared bytes put the branch far enough in that the chain is fully walked
# before either alternative can be distinguished. Both mutations below truncate
# seq-step's live-alternative filter to a single case, so the interpreter
# answers as though the node had declared one alternative rather than two, and
# between them they witness the loss of either one.
#
# Why the decision needs a lane of its own rather than the single-alternative
# one Pass 45 covers: both mutants were run against sequence-interpret-tests.sps
# (Pass 45's SPEC-lane program) on a scratch stage and BOTH pass it unchanged --
# status=0, cases=10 failed-cases=0 checks=25 failures=0, no FAIL lines --
# because with one declared alternative the truncated list and the whole list
# are the same list (AGENTS.md: a mutation's witnessing test lives in its own
# SPEC lane's program).
#
# Stated rather than implied, because "the first lane to drive a branching
# sequence node" would be false: interpret-tests.sps, under the DIFFERENT SPEC
# byte-machine.unit.interpret.chez.source, has driven AB/AC and AB/XY
# alternatives through the interpreter since Slice ②, and it catches both
# mutations below (measured: cases=21 checks=40, failed-cases=4 for the FIRST
# mutation, 5 for the LAST). What is new here is the shape rather than the node
# kind -- a seven-byte shared prefix instead of a one-byte one, asserted as
# absolute tuples rather than as bare statuses -- and the reason these are
# declared here as well is the SPEC-lane rule, which is the same relationship
# Pass 45's completed-alternative mutation documents against Pass 34. Verify
# command uses both library roots, an empty object guard, the new absolute
# program.

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/http-version-interpret-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.http-version.chez.source
  LABEL "interpret: a branching prefix keeps only the FIRST declared alternative live"
  # seq-step filters the node's WHOLE case list for the alternatives still
  # matching the accumulated path. Truncating that list to its head leaves
  # `HTTP/1.0` -- the first declared alternative -- accepting, and `HTTP/1.1`
  # mismatching on its own last byte, at the branch state the shared prefix
  # ends in. FIND measured unique in the file (one occurrence).
  #
  # Measured against a scratch stage, not the committed tree: baseline cases=12
  # failed-cases=0 checks=19 failures=0 status=0; mutant cases=12
  # failed-cases=2 checks=19 failures=2 status=1, both failures on HTTP/1.1's
  # own accept checks and nothing else. Comparison-caught (check-equal
  # failures, no raise).
  #
  # Pin sweep, both directions, against every other mutation under this pass's
  # verify command -- which is the sibling below and nothing else: 2 mutations,
  # 2 ordered pairs (n(n-1), this file's convention: ordered pairs of DISTINCT
  # mutants; corrected from 4 by the whole-branch review fix wave, which is
  # 2 squared and double-counts the two self-checks under the pair heading).
  # Every pin re-judged through byte_machine_mutation_verdict against both
  # captures. Zero collisions, and -- counted separately -- each pin still
  # catches its own mutant. The two failure sets are mirror images -- this
  # mutant reports only the HTTP/1.1 cases, the sibling only the HTTP/1.0 ones
  # -- so neither pin can match the other's output.
  # Control: this lane and both mutations are new on this branch, so there is
  # no prior baseline to re-measure; the meaningful control is the
  # sequence-interpret-tests.sps run recorded in this pass's header, which
  # shows the mutants surviving the sibling lane they are NOT declared under.
  FIND [[                            (sequence-dispatch-node-cases n)))]]
  REPLACE [[                            (list (car (sequence-dispatch-node-cases n)))))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "HTTP/1\\.1 stops at the one target: one byte at a time -- expected \\(stopped 1 1 8 #f\\), got \\(error 0 0 7 unexpected-byte\\)")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.http-version.chez.source
  LABEL "interpret: a branching prefix keeps only the LAST declared alternative live"
  # The opposite truncation, and the reason both are here: keeping only the
  # head leaves the FIRST alternative coincidentally correct, so on its own it
  # cannot show that `HTTP/1.0` is reached by being matched rather than by
  # being the one alternative the interpreter ever looks at. Keeping only the
  # tail is the mirror -- `HTTP/1.1` accepts, `HTTP/1.0` mismatches -- and the
  # pair is what pins "each alternative reaches its OWN target" to both
  # alternatives. Same FIND as the mutation above (each byte_machine_mutation()
  # call reads a pristine copy of interpret.sls and restores it afterward, so
  # sharing a FIND is a different edit, not a repeated one).
  #
  # Measured against a scratch stage: mutant cases=12 failed-cases=2 checks=19
  # failures=2 status=1, both failures on HTTP/1.0's own accept checks.
  # Comparison-caught. Pin sweep: see the sibling above -- the same two-way
  # re-judgement covers this pin.
  FIND [[                            (sequence-dispatch-node-cases n)))]]
  REPLACE [[                            (list (car (reverse (sequence-dispatch-node-cases n))))))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "HTTP/1\\.0 stops at the zero target: one byte at a time -- expected \\(stopped 1 1 8 #f\\), got \\(error 0 0 7 unexpected-byte\\)")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 48: the multi-alternative differential is non-vacuous (M3 Slice ③ ---
# Task 4) ----------------------------------------------------------------------
#
# differential-http-version-tests.sps drives the §21.2 `version` production
# through BOTH executors and compares their five-field result tuples: at every
# single-cut split, over seeded multi-split schedules, and across all 256 bytes
# at all eight prefix positions in both mismatch modes. Both executors read the
# same source IR, so agreement alone cannot carry the lane -- a divergence has
# to be reachable, and only a module that exactly ONE executor reads can
# produce one: the normalizer and the emitter on the generated side,
# interpret.sls on the reference side (interpret.sls's header, §18). Shared
# code -- runtime.sls, verify.sls -- makes both executors wrong identically and
# leaves the comparison green. The pair below takes the generated side.
#
# The pair below truncates render-state-arm's per-state transition list to its
# FIRST arm and to its LAST. In this fixture the branch state is the only state
# with more than one arm -- the seven shared-prefix states each have exactly one
# -- so each truncation renders one alternative unreachable in the emitted
# library while the interpreter still accepts it. They are the generated-side
# twin of Pass 47's interpreter-side alternative-filter pair, and the pair is
# what pins "the emitter renders EVERY arm of a branching state" to both
# alternatives rather than to whichever one happens to be rendered.
#
# Why this lane's own SPEC, measured rather than asserted (AGENTS.md: a
# mutation's witnessing test lives in its own SPEC lane's program). Both mutants
# were run on a scratch stage against the two neighbouring lanes and leave both
# passing UNCHANGED -- byte-identical summaries to those programs' own
# unmutated baselines on the same stage:
#   differential-sequence-node-tests.sps (Pass 46's SPEC program, the
#   SINGLE-alternative differential): baseline and both mutants all report
#   cases=14 failed-cases=0 checks=30 failures=0 status=0, because with one
#   alternative every dispatch state has exactly one arm and truncating a
#   one-element list is the identity;
#   (AMENDED, whole-branch review fix wave 2026-08-30: that program's check
#   count is now 29, its all-256 case having traded a vacuous two-counter
#   sentinel for one 1024-drive counter. The finding this line makes -- that
#   both mutants leave it green -- is unaffected; see Pass 46's header
#   amendment for the measurement.)
#   http-version-interpret-tests.sps (Pass 47's SPEC program, this same fixture
#   through the interpreter alone): baseline and both mutants all report
#   cases=12 failed-cases=0 checks=19 failures=0 status=0, because that program
#   never emits.
#
# Stated rather than implied, because "no other lane catches this" would be
# false: re-measured on the same stage, two lanes under DIFFERENT SPECs redden
# for both mutants, and they get their many-arm dispatch states by two
# different routes, neither of which is this lane's.
#   differential-byte-class-tests.sps (cases=13 checks=26; failed-cases=5
#   failures=5 for FIRST, failed-cases=10 failures=15 for LAST): a byte class
#   lowers to one transition per byte (decision 0014), so one declared class
#   renders up to 256 sibling arms.
#   property-differential-tests.sps (cases=2 failed-cases=1 checks=83
#   failures=30, both mutants): NOT byte classes -- machine-gen.sls builds no
#   class at all (`rg byte-class` over that file returns nothing). Its nodes
#   are make-byte-dispatch-node over 1 to 2 randomly drawn byte cases across all
#   four matcher kinds (machine-gen.sls's free draw and its coverage prefix; line
#   citations dropped -- the Slice ② rewrite moved them, so construct names, not
#   numbers), so a many-arm state is whatever that draw happened to produce.
# Both routes reach a many-arm state without a shared PREFIX, and both run
# under their own SPEC, so neither can witness this pass's mutations. What is
# specific to this lane is the arm count arising from a BRANCHING PREFIX, which
# is exactly what the single-alternative differential above cannot produce.
#
# Verify command uses both library roots, an empty object guard, the new
# differential program.

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/differential-http-version-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.http-version.chez.source
  LABEL "compile: a branching state renders only its FIRST transition arm"
  # Keeping the head leaves `HTTP/1.0` -- the lower branch byte, 48 -- rendered
  # and `HTTP/1.1` falling through to the state's else fallback, so the
  # generated executor rejects at offset 7 where the interpreter stops at 8.
  # FIND measured unique in the file (one occurrence, confirmed on a scratch
  # copy); SITES therefore stays at its default of 1.
  #
  # Measured against a scratch stage, not the committed tree: baseline cases=8
  # failed-cases=0 checks=19 failures=0 status=0; mutant cases=8
  # failed-cases=4 checks=19 failures=6 status=1. Comparison-caught throughout
  # (check-equal failures, no raise) -- every dispatch state in this fixture
  # has at least one transition, so `car` never sees an empty list.
  #
  # Pinned to the exhaustive group's own sentinel rather than to any of the
  # five other failing checks, because that check reports the FIRST
  # (mode position byte) triple that disagreed and the triple names the defect
  # exactly: (reexecute 7 49) is prefix position 7 -- the branch -- and byte 49,
  # `HTTP/1.1`'s distinguishing byte, the one this truncation drops. The
  # sibling's is the mirror, (reexecute 7 48).
  FIND [[(apply string-append (map render-transition-arm (normal-dispatch-transitions s)))]]
  REPLACE [[(apply string-append (map render-transition-arm (list (car (normal-dispatch-transitions s)))))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "256 x 8 positions match, in both mismatch modes: no \\(mode position byte\\) disagreed -- expected none, got \\(reexecute 7 49\\)")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.http-version.chez.source
  LABEL "compile: a branching state renders only its LAST transition arm"
  # The opposite truncation, and the reason both are here: keeping only the
  # head leaves `HTTP/1.0` coincidentally correct, so on its own it cannot show
  # that the zero alternative is reached by having its OWN arm rendered rather
  # than by being the one arm the emitter ever writes. Keeping only the tail is
  # the mirror -- `HTTP/1.1` accepts, `HTTP/1.0` rejects at offset 7. Same FIND
  # as the mutation above (each byte_machine_mutation() call reads a pristine
  # copy of compile.sls and restores it afterward, so sharing a FIND is a
  # different edit, not a repeated one).
  #
  # Measured against the same scratch stage: mutant cases=8 failed-cases=6
  # checks=19 failures=9 status=1 -- two failed cases and three failures more
  # than the sibling, and the two extra cases are exactly the "nonzero-offset
  # and empty slices agree" pair, which feeds `HTTP/1.0` and so is untouched by
  # the sibling's truncation. Comparison-caught.
  #
  # Pin sweep, both directions, against every other mutation under this pass's
  # verify command -- which is the sibling above and nothing else: 2 mutations,
  # 2 ordered pairs (n(n-1), this file's convention: ordered pairs of DISTINCT
  # mutants; corrected from 4 by the whole-branch review fix wave, which is
  # 2 squared and double-counts the two self-checks under the pair heading).
  # Every pin re-judged through byte_machine_mutation_verdict against both
  # captured outputs. Result: counted separately, each pin caught its own
  # mutant, and each returned wrong-reason against the other's; zero
  # collisions. The two pins differ only in the branch byte they name (49 vs
  # 48), and each mutant's
  # output contains exactly one of the two.
  # Control: this lane, this program and both mutations are new on this branch,
  # so there is no prior baseline to re-measure; the meaningful control is the
  # neighbouring-lane measurement recorded in this pass's header, which shows
  # both mutants surviving the two lanes they are NOT declared under.
  FIND [[(apply string-append (map render-transition-arm (normal-dispatch-transitions s)))]]
  REPLACE [[(apply string-append (map render-transition-arm (list (car (reverse (normal-dispatch-transitions s))))))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "256 x 8 positions match, in both mismatch modes: no \\(mode position byte\\) disagreed -- expected none, got \\(reexecute 7 48\\)")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 49: the sequence determinism golden is non-vacuous (M3 Slice ③ -----
# Task 5) ---------------------------------------------------------------------
#
# determinism-http-version-tests.sps compares the emitted bytes of the §21.2
# `version` production against test/fixtures/generated-http-version.golden.sls,
# the first committed golden whose machine contains a BRANCH. The mutation below
# flips trie-put's insert-before-if-less arm, so a trie node's children come out
# DESCENDING by byte instead of ascending -- decision 0016 point 1's child rule,
# and the unstable branch order that §25:1539's "normalized output is
# deterministic" would otherwise lose.
#
# trie-put is the whole of that rule for a SEQUENCE prefix state: the `list-sort`
# at the head of the byte-dispatch arm (decision 0014) never sees these states,
# and this fixture declares no byte-dispatch node at all. Measured as a control
# rather than read off the source -- flipping that comparator
# `(< (car a) (car b))` -> `(> ...)` on the same scratch stage re-emits this
# machine BYTE-IDENTICALLY to the committed golden, and leaves this pass's own
# program green (cases=3 failed-cases=0 checks=8 failures=0 status=0). The
# Slice ③ implementation plan's draft of this lane named `list-sort` as the
# mechanism (.plans/milestone-3-slice-3-implementation-plan.md, Task 5);
# that is true of a byte-dispatch node -- decision 0014's ascending-by-byte
# transition sort -- and false of a sequence prefix state, which is what this
# fixture is made of.
#
# It is the same one-line edit Pass 35 declares as "normal-ir: trie children are
# not kept ascending by byte", re-anchored under this lane's SPEC for the reason
# Pass 46 re-anchors Pass 44's byte shift (AGENTS.md: a mutation is witnessed
# only by the tests that run in the lane its SPEC names). What is new is the
# witness kind: Pass 35 asserts the lowered transition list structurally, and
# this pass asserts the EMITTED BYTES.
#
# Why the new golden is what witnesses it, measured rather than argued. On a
# scratch stage the mutant leaves the tree's other two determinism programs
# passing UNCHANGED -- byte-identical summaries to their own unmutated baselines
# on the same stage, because neither machine contains a sequence node, so
# trie-put is never called:
#   determinism-one-byte-tests.sps: cases=3 failed-cases=0 checks=4 failures=0
#   status=0, baseline and mutant alike;
#   determinism-pause-tests.sps: cases=4 failed-cases=0 checks=8 failures=0
#   status=0, baseline and mutant alike.
#
# Stated rather than implied, because "no other lane catches this" would be
# false, and because the set that does NOT catch it is the surprising half.
# Re-measured on the same stage, exactly one other program reddens:
#   normal-ir-tests.sps (Pass 35's SPEC program, where this same edit is already
#   declared): cases=38 failed-cases=4 checks=82 failures=9 status=1.
# Both lanes that drive this same branching fixture through an EXECUTOR stay
# green: differential-http-version-tests.sps (cases=8 failed-cases=0 checks=19
# failures=0 status=0) and http-version-interpret-tests.sps (cases=12
# failed-cases=0 checks=19 failures=0 status=0). So do the neighbouring
# sequence and core lanes, measured on the same stage --
# differential-sequence-node-tests.sps, sequence-interpret-tests.sps,
# interpret-tests.sps, compile-tests.sps, ir-tests.sps and verify-tests.sps, all
# status=0. That is not an accident of these fixtures: reordering the two arms
# of a `case` over disjoint byte sets is BEHAVIOUR-PRESERVING, so the two
# executors still agree and no differential can see it. Emission ORDER is
# observable only in the bytes, which is what a golden is for.
#
# The mutant's library is also 3849 bytes -- the same length as the golden -- so
# a size check would not notice either. Diffed against the committed golden, the
# whole difference is the branch state's two arms swapping ((48) before (49)
# becomes (49) before (48)) and the v2 fingerprint moving
# 16999772257989587335 -> 14649231454401036534.
#
# Three neighbouring edits were measured on the same stage and NOT declared
# here, recorded so the next reader does not re-derive them:
#   allocate-prefix-ids walked breadth-first instead of depth-first (Pass 35
#   carries this edit) is INERT on this fixture -- cases=3 failed-cases=0
#   checks=8 failures=0 status=0. Every interior trie node here has exactly one
#   interior child, so the two walks number the chain identically. Declaring it
#   under this SPEC would have been an uncaught mutation.
#   prefix ids started at 0 rather than declared-count (also Pass 35) IS caught
#   here (failed-cases=2 failures=6) but corrupts the states vector outright, so
#   it reddens the execution group as well as the golden and says nothing about
#   the branch's ORDER.
#   trie-put's merge (=) arm disabled (also Pass 35) IS caught here
#   (failed-cases=2 failures=3), but it changes BEHAVIOUR -- `HTTP/1.1` becomes
#   unreachable -- so the lanes that already exist see it: measured
#   differential-http-version-tests.sps failed-cases=4 failures=6 and
#   normal-ir-tests.sps failed-cases=7 failures=10. It needs no new witness.
#
# Pin sweep, both directions. This pass declares one mutation, so under this
# file's n(n-1) convention there are ZERO ordered pairs of distinct mutants --
# there is no sibling under this verify command to collide with. What was
# actually run is the self-check, counted separately: the pin against its own
# capture, which it matches. (Corrected from "one ordered pair -- the pin
# against its own capture" by the whole-branch review fix wave; a self-check is
# not an ordered pair, and calling it one made this pass's arithmetic disagree
# with every other audit block in the file.) No OTHER pass runs this program,
# so no existing pin's collision set widened when this one was added. The pin
# is the case-name tail plus the check label, which resolves to the single (case,
# check) pair "the emitted bytes equal the committed sequence golden" /
# "golden": this program declares exactly one check with that label, and the pin
# contains no regex metacharacter. Pinning the measured DETAIL was considered
# and declined: it is a 3849-element bytevector dump, so any pin drawn from it
# embeds the golden's own bytes in this file, and there is no collision here for
# it to resolve.
#
# The word "sequence" in that case name is load-bearing, not decoration. Without
# it this program's case AND check names are byte-identical to Pass 38's
# (determinism-one-byte-tests.sps), so the two pins would be the same string.
# That is sound as this suite works today -- BYTE_MACHINE_MUTATION_VERIFY_COMMAND
# is set per pass, each names one --program, and byte_machine_mutation_verdict
# judges a pin only against its own mutation's captured output -- but uniqueness
# costs nothing here, and it stays correct if a future pass's verify command
# ever runs more than one determinism program.
# Control: this lane, this program and this mutation are all new on this branch,
# so there is no prior baseline to re-measure; the control that carries the
# claim is the neighbouring-determinism measurement above, which shows the
# mutant surviving the two determinism lanes it is NOT declared under.
#
# Verify command uses both library roots, an empty object guard, the new
# determinism program.

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/determinism-http-version-tests.sps"
  # the golden lives in the source tree; the staged program reads it via env
  # (BYTE_MACHINE_HTTP_VERSION_GOLDEN_FILE, supplied by this suite's own ctest
  # registration and inherited unmodified through execute_process -- see "WHAT
  # THIS SUITE NEEDS FROM ITS ENVIRONMENT" above)
  )

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls
  SPEC byte-machine.determinism.http-version.chez.source
  LABEL "normal-ir: a branching trie's children are emitted descending by byte"
  # FIND measured unique in the file (one occurrence, confirmed on a scratch
  # copy); SITES therefore stays at its default of 1.
  #
  # Measured against a scratch stage, not the committed tree: baseline cases=3
  # failed-cases=0 checks=8 failures=0 status=0; mutant cases=3 failed-cases=1
  # checks=8 failures=1 status=1, the one failure being the golden comparison
  # and nothing else. Comparison-caught (a check-equal failure, no raise): the
  # emitted library still loads and both alternatives still walk, which is
  # exactly why the golden rather than the execution group is what notices.
  FIND [[          ((< b (caar cs)) (cons (cons b child) cs))]]
  REPLACE [[          ((> b (caar cs)) (cons (cons b child) cs))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the emitted bytes equal the committed sequence golden: golden")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# Milestone 4 Slice ①a task 6 (§4.7 item 2): reserved-member-3's drift guard.
# Its own PASS, because a mutation is witnessed only by tests that run in the
# lane its SPEC names -- appended to the preceding pass it ran under a verify
# command driving a different program and reported UNCAUGHT, which is exactly
# what that rule predicts.
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/member3-drift-tests.sps")

# compile.sls stated this gap in its own words for three milestones -- "checked,
# not assumed, since it has no automated drift guard" -- and this slice adds
# three entries to the list, so the gap is demonstrated rather than theoretical.
# The mutation is a deletion, which is the drift the guard exists to catch.
byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.member3-drift.chez.source
  LABEL "compile: an emitted local is missing from reserved-member-3"
  # Re-anchored by Slice ② task 8: the list gained `v` and `r`, the two locals
  # the emitted field arms bind, and reflowed onto two lines. Dropping `pk` is
  # still the edit -- the same decision, the same expectation.
  # Re-anchored by Slice ③ task 4: the list gained `d`, the emitted accumulate
  # arm's digit local. Dropping `pk` is still the edit.
  # Re-anchored by Milestone 5 Slice ①a task 2: the list gained `psr` and `cbv`,
  # emitted `exec`'s eighth and ninth parameters (decision 0025 point 3).
  # Dropping `pk` is STILL the edit -- the same decision, the same expectation,
  # the fourth re-anchor. This pin moves whenever the list does, by design: it
  # anchors on the whole list precisely so that a name added without a matching
  # guard entry is what breaks it.
  # Re-anchored by Milestone 5 Slice ②: the list gained `o`, the callback arm's
  # outcome binding. Dropping `pk` is still the edit.
  # Re-anchored by Milestone 11 Slice ①: the list gained `kpath`, the emitted
  # keyword-table arm's resume-path local. Dropping `pk` is still the edit.
  FIND [[    '(exec loop pos st off b bv start end state offset finish? fieldv errs pk
      v r d o psr cbv n kpath))]]
  REPLACE [[    '(exec loop pos st off b bv start end state offset finish? fieldv errs
      v r d o psr cbv n kpath))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "no undeclared emitted local -- expected \\(\\), got \\(pk\\)")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.member3-drift.chez.source
  LABEL "compile: reserved-member-3 loses the accumulate arm's digit local"
  # Slice ③ adds `d` to the list and an accumulate node to this fixture, so the
  # entry is EXERCISED rather than merely declared -- the gap ② closed for `v`
  # and `r`, reopened by ③'s own addition. Dropping it is what the guard is for:
  # the emitted body binds a local the list does not reserve, and a caller may
  # legitimately bind the same name.
  # Re-anchored by Milestone 5 Slice ①a task 2: the continuation line gained
  # `psr cbv`. Dropping `d` is still the edit. Measured after the edit: this FIND
  # and the whole-list FIND above remain textually distinct and each occurs
  # exactly once, which the suite asserts in both directions (no SITES is
  # declared anywhere in this file, so every FIND is pinned at one occurrence).
  # Re-anchored by Milestone 5 Slice ②: the tail gained `o`. Dropping `d` is
  # still the edit, and the two FINDs in this pair stay textually distinct.
  # Re-anchored by Milestone 11 Slice ①: the tail gained `kpath`. Dropping `d` is
  # still the edit, and the two FINDs in this pair stay textually distinct.
  FIND [[      v r d o psr cbv n kpath))]]
  REPLACE [[      v r o psr cbv n kpath))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "no undeclared emitted local -- expected \\(\\), got \\(d\\)")

# --- Milestone 6 Slice ① task 2: the counted arm's one local ---------------------
byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.member3-drift.chez.source
  LABEL "compile: reserved-member-3 loses the counted arm's n"
  # Re-anchored by Milestone 11 Slice ①: the tail gained `kpath`. Dropping `n` is
  # still the edit.
  FIND [[      v r d o psr cbv n kpath))]]
  REPLACE [[      v r d o psr cbv kpath))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "no undeclared emitted local -- expected \\(\\), got \\(n\\)")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# Milestone 4 Slice ①a task 7: the position kind is a property of the ARRIVING
# transition (decision 0022 item 5), asserted BY VALUE in both executors.
#
# What the by-value assertion adds, stated honestly. Each mutation below breaks
# exactly ONE lane, so the cross-lane comparison would also catch it -- the
# earlier claim here, that these are defects "the differential alone cannot
# see", was false of its own next sentence. What the by-value check adds for
# these three is that the failure NAMES the wrong kind instead of reporting a
# bare disagreement between two tuples.
#
# The case the by-value assertion uniquely covers -- both lanes agreeing on a
# WRONG kind, which AGENTS.md's "agreement must stay observable" rule is about --
# has no mutation here and cannot have one: a mutation edits a single FILE, and
# making both lanes agree wrongly takes a coordinated edit to compile.sls and
# runtime.sls at once. The by-value assertions in position-kind-tests.sps are
# the only guard against it, which is why they assert the kind against §12.7's
# table rather than only against each other.
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/position-kind-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.position-kind.chez.source
  LABEL "compile: an emitted reexecute jump carries the advance position kind"
  FIND [[(string-append "(loop pos " (number->string target) " off (quote byte))")]]
  REPLACE [[(string-append "(loop pos " (number->string target) " off (quote boundary))")]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "reexecute mismatch reports byte at the offending byte: kind -- expected byte, got boundary")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.position-kind.chez.source
  LABEL "runtime: the interpreter's advance jump carries the reexecute position kind"
  # Re-anchored by Slice ③ task 4 onto `route-byte-step!`, where the two
  # byte-consuming kinds now share one tail. The decision -- an ADVANCE reports
  # `boundary`, a reexecute reports `byte` -- is unchanged and now covers both.
  FIND [[              (loop (+ pos 1) 'boundary))
            (loop pos 'byte)))]]
  REPLACE [[              (loop (+ pos 1) 'byte))
            (loop pos 'byte)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "an advance-mode mismatch reports boundary after the committed byte: kind -- expected boundary, got byte")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.position-kind.chez.source
  LABEL "compile: the default-EOF arm reports a byte position rather than eof"
  # §12.7:771 fixes `eof` for truncated input during finish!, and this arm is a
  # terminal construction reached by no jump, so it takes a per-site literal
  # rather than the loop variable. That literal had no mutation: the pass covered
  # `byte` in the generated lane and `boundary` in the interpreter, leaving the
  # third of the three kinds the lane is named for unwitnessed in both.
  FIND [[") " id " off (quote eof)) " id " off)")))]]
  REPLACE [[") " id " off (quote byte)) " id " off)")))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "both lanes report eof at the terminal, not at a hop: generated -- expected eof, got byte")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.position-kind.chez.source
  LABEL "compile: a reason is written into generated source unescaped"
  # §20:1039's explicit escaping. valid-reason? deliberately ADMITS the three
  # characters that need it -- they are inside §10.1:480's printable-ASCII-plus-LF
  # repertoire -- so escape-string is the only thing between an author-supplied
  # reason and a generated library that either does not parse or parses WRONG.
  #
  # Measured, not assumed: with only the quote clause removed the file still
  # READS -- the string terminates early and the reason arrives as "a " instead
  # of the declared text -- so the witnessing check is the ROUND TRIP, not the
  # load. Removing the whole escaper does produce the reader error decision
  # 0022's Consequences predicts, but that is a DIFFERENT mutant; pinning this
  # one to it was a false supporting reason, caught by re-measuring the mutant
  # the suite actually applies. The round trip is the stronger assertion anyway:
  # escaping to the empty string would also load.
  #
  # Shipped with no witness at all until the whole-branch review: every reason in
  # the test tree was plain lowercase ASCII plus space, so nothing distinguished
  # this function from the identity.
  FIND [[                  (cond ((char=? c #\") (cons #\" (cons #\\ acc)))]]
  REPLACE [[                  (cond ((char=? c #\nul) (cons c acc))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the emitted library loads and reports the reason unchanged: generated round-trips the reason")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.position-kind.chez.source
  LABEL "compile: an error declaration is resolved by code alone"
  # The whole-branch review's Critical. Two declarations may share a CODE --
  # pass-names rejects duplicate declaration NAMES and nothing rejects duplicate
  # codes -- and the normalizer has collapsed the node's declaration name to its
  # resolved code by the time the emitter sees it, so keying on the code alone
  # returns the FIRST declaration carrying it. The generated lane then reports a
  # different declaration's reason than the interpreter, on a machine the
  # verifier accepts with zero diagnostics. Invisible to every pre-existing lane
  # (each fixture uses distinct codes) and to the property lane (machine-gen.sls
  # fixes two declarations with distinct codes), which is why it needed its own
  # fixture rather than a wider sweep of the existing ones.
  FIND [[((and (eq? (error-declaration-code (car ds)) code)
                                     (string=? (error-declaration-reason (car ds)) reason))]]
  REPLACE [[((eq? (error-declaration-code (car ds)) code)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "both lanes report the reason of the declaration the node names: generated")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.position-kind.chez.source
  LABEL "runtime: the finish loop initializes the position kind to eof"
  # Decision 0022 item 5's headline: the initialization is `boundary`
  # UNCONDITIONALLY, in a feed call and a finish call alike, with no finish? key.
  # Initializing this loop to `eof` is the shape Gate 0 shipped and caught one
  # review later -- it made both lanes agree at the default-EOF arm and made that
  # arm's own literal observationally identical to the inherited variable.
  FIND [[(let loop ((node (parser-current parser)) (pk 'boundary))]]
  REPLACE [[(let loop ((node (parser-current parser)) (pk 'eof))]]
  EXPECT_STATUS 1
  # Witnessed by the PARKED case, not by the truncation one: every other route
  # into a finish-time error either hops (setting `eof` on the way) or lands on
  # the default-EOF terminal, which takes its own per-site constant. Only an
  # error state a prior feed parked on is reached by NO jump, so only it can
  # observe what the loop was initialized to.
  EXPECT_OUTPUT_MATCHES "both lanes report boundary, not eof: interpreter -- expected boundary, got eof")

# Slice ③ task 7 adds ONE, HERE rather than to the field pass, because a
# mutation's specification is a LABEL and the program actually run is this pass's
# verify command -- the two must name the same lane or the mutation runs against
# the wrong program and reads as uncaught. (It did, first time: appended to the
# field pass with a position-kind SPEC, it ran field-access-tests.sps and was
# reported UNCAUGHT.)
#
# It belongs to the position-kind lane rather than the field lane because what
# the new table row asserts and the field lane does not is the OFFSET. field-access-tests.sps already pins the overflow's position KIND in
# both lanes; a mutation that moves the kind is caught there. This one moves the
# offset alone -- the kind stays `byte` -- and it is caught by task 7's row and
# by nothing else in the tree. Measured: the whole release selection under this
# mutant fails exactly the two position-kind lanes (plus the mutation suite's own
# baseline, which any dirty tree fails), and differential.field passes.
#
# *** ANNOTATED 2026-09-03, whole-branch review: that measurement was true when
# it was taken and the sentence above is now STALE. *** Re-measured on the closed
# branch, this mutant fails SIX behavioural lanes: both position-kind lanes, both
# determinism.accumulate lanes (Task 9's golden reads the emitted bytes, and this
# mutation changes them) and both property.differential lanes (Task 8's draw puts
# an accumulate node in front of the oracle). The claim that survives re-measuring
# is the one this pin is actually for: differential.field still passes, so the
# OFFSET is still a thing only the position-kind row asserts. Left in place rather
# than reworded, because a measured claim that later became false is a record of
# how a lane's reach grows, and rewriting it would erase that.

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.position-kind.chez.source
  LABEL "compile: the emitted overflow advances the stream offset past the digit it did not consume"
  # §12.7:773's "does not consume" made falsifiable. The generated arm keeps
  # `pos` -- so it does not re-read the byte -- while advancing the ABSOLUTE
  # offset, which is precisely the inconsistency a kind-only assertion cannot
  # see: the error still says `byte`, it just says it about the wrong byte.
  FIND [["                       (loop pos " (num over) " off (quote byte))))))))\n")))]]
  REPLACE [["                       (loop pos " (num over) " (+ off 1) (quote byte))))))))\n")))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "an accumulate overflow reports byte at the unconsumed digit: offset -- expected 2, got 3")

# --- Slice ③ task 8: §12.7:770's row, which the tree did not implement -------
#
# "Zero-width machine action or callback failure | `boundary` at the current
# stream offset." Every site building a callback-domain error passed the loop's
# `pk` instead, and Slice ②'s own comment claimed the carried-through `pk` "is
# the rule the carried-through `pk` already implements" -- true only where the
# invoking node was reached by an ADVANCE edge. Over a REEXECUTE edge `pk` is
# `byte`, and BOTH LANES REPORTED IT, so no differential could see it: the
# lane-to-lane projection is satisfied by two lanes agreeing on a wrong value,
# which is why the fix's rows assert the VALUE and not only the agreement.
#
# FOUR mutations, because the correction has four independent sites: one named
# constant serving the runtime's six arms, and three rendered literals. Every
# fixture that reaches one does so over a reexecute edge, which is what makes
# the literal and the variable differ at all.

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.position-kind.chez.source
  LABEL "runtime: a callback failure reports the loop's position kind"
  # The interpreted half, over all three of its arms at once -- the constant is
  # one decision and the six sites read it.
  #
  # *** RE-PINNED AT THE FINAL REVIEW. *** The pin read `kind -- expected
  # boundary, got byte`, which the emitted-callback-arm mutation below prints
  # byte for byte: both make that row's kind check fail, and the comment here
  # claimed the emitted ones "do not move" it. What separates them is the
  # PROJECTION's direction -- the harness prints the second `check-equal`
  # argument as "expected", which is the GENERATED lane, so a mutation of the
  # interpreted lane reads `expected …boundary, got …byte` and its emitted
  # sibling reads the mirror. Measured.
  FIND [[  (define callback-failure-position 'boundary)]]
  REPLACE [[  (define callback-failure-position 'byte)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the lanes agree on the projection -- expected .callback said-no .callback failure. inv 1 boundary., got .callback said-no .callback failure. inv 1 byte."
)

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.position-kind.chez.source
  LABEL "compile: the emitted callback arm reports the loop's position kind"
  # The generated half, one arm at a time. Each is pinned on its own row's
  # PROJECTION, whose "expected" is the generated lane's value -- the harness
  # prints the second `check-equal` argument as expected -- so the three read as
  # mirror images of each other and no two collide.
  FIND [[            (num (cadr tg)) " off))\n"
            "           (else (byte-machine-make-feed-outcome/v1 (quote error) pos "
            "(byte-machine-make-callback-error/v1 (cadr o) (caddr o) (quote "
            (nm (normal-state-id s)) ") " id " off (quote boundary)) " id " off)))))\n")))]]
  REPLACE [[            (num (cadr tg)) " off))\n"
            "           (else (byte-machine-make-feed-outcome/v1 (quote error) pos "
            "(byte-machine-make-callback-error/v1 (cadr o) (caddr o) (quote "
            (nm (normal-state-id s)) ") " id " off pk) " id " off)))))\n")))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a callback failure reports boundary at the committed offset: the lanes agree on the projection -- expected .callback said-no .callback failure. inv 1 byte."
)

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.position-kind.chez.source
  LABEL "compile: the emitted span-end arm reports the loop's position kind"
  # Its own site and its own row: a span end is always reached by a reexecute
  # edge in practice -- the delimiter must not be consumed into the payload --
  # so this arm is the one where the defect was easiest to reach and hardest to
  # see, both lanes having agreed on `byte`.
  FIND [[            (nm (normal-state-id s)) ") " id " off (quote boundary)) " id " off)))))\n")))
        ;; The SECOND substep.]]
  REPLACE [[            (nm (normal-state-id s)) ") " id " off pk) " id " off)))))\n")))
        ;; The SECOND substep.]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a span data callback failure reports boundary at the committed offset: the lanes agree on the projection -- expected .callback said-no .callback failure. cl 2 byte."
)

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.position-kind.chez.source
  LABEL "compile: the emitted span-completion arm reports the loop's position kind"
  # The third, and the reason the lane builds a THIRD machine: a span whose
  # completion callback is declared and fails. Neither row above reaches this
  # arm, and its projection differs from the span end's only by the check label.
  FIND [[                (nm (normal-state-id s)) ") " id " off (quote boundary)) " id " off))))))\n"))))]]
  REPLACE [[                (nm (normal-state-id s)) ") " id " off pk) " id " off))))))\n"))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a span completion callback failure reports boundary too: the lanes agree on the projection -- expected .callback said-no .callback failure. cl 2 byte."
)

# --- Milestone 6 Slice ① task 2: the runtime's counted arm, witnessed here -----
# The arm runs in the interpreted lane only (the generated lane calls the emitted
# `exec`), so its pins live in a pass whose program EXECUTES a machine carrying
# the kind through the interpreter -- this one, through the three counted rows.
# The emitted arm's exhaustion-first twin is NOT here: this file's check labels
# carry no lane prefix, so the two mutants' records are identical, and the twin
# is pinned in the counted differential pass on a lane-labelled witness.
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.position-kind.chez.source
  LABEL "runtime: the counted arm does not advance the stream offset"
  FIND [[                      (parser-set-offset! parser (+ n (parser-offset parser)))]]
  REPLACE [[                      (parser-set-offset! parser (parser-offset parser))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "truncation at a parked counted consume reports eof at the final offset: offset -- expected 2, got 1")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.position-kind.chez.source
  LABEL "runtime: the counted arm parks current on its EOF route when input runs out"
  # `current` must stay on the node after a partial commit; the wrong value
  # available to the arm is the EOF route, and a parser parked THERE finishes
  # on the error node by no jump -- `boundary`, where a truncation is `eof`.
  FIND [[                          (make-parser-result 'need-input (+ pos n) (- (+ pos n) start)
                                              (parser-offset parser) #f))))))]]
  REPLACE [[                          (begin (parser-set-current! parser (op 'eof-target node))
                                 (make-parser-result 'need-input (+ pos n) (- (+ pos n) start)
                                                     (parser-offset parser) #f)))))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "truncation at a parked counted consume reports eof at the final offset: kind -- expected eof, got boundary")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.position-kind.chez.source
  LABEL "runtime: the counted arm asks exhaustion before the op"
  FIND [[            ((counted-consume)
             (let* ((r (op 'count-step node (parser-field-values parser) pos end))]]
  REPLACE [[            ((counted-consume)
             (let* ((r (if (>= pos end) (cons 0 #f) (op 'count-step node (parser-field-values parser) pos end)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "a zero count at the end of a slice transitions before exhaustion is tested: is a record -- expected a true value")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Milestone 5 Slice ①b tasks 6+7: parser-field-ref, across BOTH executors --
#
# *** THE INTEGER IS GONE FROM THIS HEADER ON PURPOSE (Slice ④). *** It read
# "Pass 49", and so does the Milestone 3 header ~460 lines above it: two
# different passes reachable by one citation. The integers cannot be repaired by
# renumbering either, because they do not index anything countable -- this file
# has 46 `byte_machine_mutation_run` call sites and the suite reports 58 passes,
# the difference being helper functions that call `_run` once per case in a loop
# and consume indices no header names. `EXPECTED_PASSES`, measured from the
# harness, is the only authority. New headers name their slice.
#
# field-access-tests.sps is the only lane in which the field declarations are
# observable at all, and it drives both executors, which reach them by different
# routes: the interpreter asks its op closure a 'field-initials message, the
# generated lane reads member 0 of the ABI payload it was emitted with. Nothing
# is shared between those two paths, so this pass carries a mutation for each
# side separately. It emits and runtime-loads a generated library, so the verify
# command is the differential shape -- both library roots, the shared object
# guard, and BYTE_MACHINE_TEST_TMPDIR inherited from this suite's own test
# environment.
#
# TWO further mutations were measured and are NOT written, each because its
# record set is IDENTICAL to one that is -- not a subset, the same set. (This
# said THREE and listed two bullets; the count was of bullets that never
# existed.)
#   * make-parser's op arm discarding what it asked for, versus interpret.sls
#     answering with nothing. One decision seen from the asker's side and the
#     answerer's; the parser ends up with an empty table either way.
#   * The emitter rendering a wrong field NAME, versus the v2 arm ignoring
#     member 0 entirely. A name the parser cannot match is a table it cannot
#     use, and both produce the same four raised cases.
# In each case the written mutation is the one that lives in the file whose new
# code it names.

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/field-access-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.field.chez.source
  LABEL "runtime: the v2 arm ignores the ABI payload's field member"
  # Re-anchored by Milestone 5 Slice ①b task 4: the constructor now reads member
  # 1 as well, so the line gained a second `vector-ref` and this FIND went to
  # zero. The Slice ①b plan named this as the one CONDITIONAL break in its work
  # list -- survives untouched if ①b leaves the constructor reading member 0
  # only, dies if it does not -- and it did not. The decision this pin names is
  # unchanged: member 0 is the field table and dropping it must be caught.
  # Re-anchored again by Milestone 5 Slice ②, which added member 2 (§17:963's
  # state-name table) and so a third `vector-ref` on the same line. The decision
  # is still member 0's.
  FIND [[            (vector-ref metadata 0) (vector-ref metadata 1)
            (vector-ref metadata 2)))]]
  REPLACE [[            (vector) (vector-ref metadata 1)
            (vector-ref metadata 2)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "parser-field-ref \\(generated\\).a fresh parser reads the declared initial at every width: case raised")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.differential.field.chez.source
  LABEL "interpret: the field-initials message answers with no declarations"
  FIND [[                               (machine-fields m))))]]
  REPLACE [[                               '())))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "parser-field-ref \\(interpreter\\).a fresh parser reads the declared initial at every width: case raised")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.field.chez.source
  LABEL "compile: an emitted field declaration carries initial zero"
  # Pinned in THIS lane rather than the compile lane, where its record is
  # indistinguishable from the member-0 mutation's: compile-tests asserts the
  # rendered member by one substring, so every deviation reddens the same check.
  # Re-anchored after the whole-branch review rebuilt this lane's fixture: the
  # cross-executor DISAGREEMENT records it used to sit on are now shared with the
  # runtime's own zero-initials mutation, and what separates it is the emitted
  # table's ORDER assertion -- this mutation is the only one in the pass that
  # changes the rendered text of member 0.
  FIND [[ " . " (number->string (caddr (car fs))) ")")]]
  REPLACE [[ " . " (number->string 0) ")")]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the emitted field table is in declaration order: member 0 lists all four in order -- expected a true value")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.field.chez.source
  LABEL "runtime: a fresh parser's field values are zero instead of the declared initials"
  # §12.5:738's just-constructed state. Distinct from the emitter mutation above,
  # which moves only the GENERATED half: this one moves both, so its record is
  # the interpreter's, which that one never produces.
  FIND [[            (begin (vector-set! v i (cdr (vector-ref decls i)))]]
  REPLACE [[            (begin (vector-set! v i 0)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "parser-field-ref \\(interpreter\\).a fresh parser reads the declared initial at every width: count -- expected 7, got 0")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.field.chez.source
  LABEL "runtime: parser-field-ref answers an undeclared name instead of refusing"
  # §13:801 makes an undeclared name a CALLER mistake, not a machine outcome, so
  # it must reach a contract violation and never a parser-error.
  FIND [[        (cond ((>= i n)
               (byte-machine-contract-violation 'parser-field-ref 'accessor-misuse
                                                field-name))]]
  REPLACE [[        (cond ((>= i n) 0)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "an undeclared field name is accessor-misuse: code -- expected accessor-misuse, got no-raise")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.field.chez.source
  LABEL "runtime: parser-field-ref always reads slot zero"
  # The reason the lane's fixture declares FOUR fields with four DIFFERENT
  # non-zero initials: with equal initials, with a zero among them, or with one
  # field, this mutation is invisible. The first version of the fixture had three
  # fields and a zero, which the whole-branch review flagged against the design's
  # own stated mitigation (milestone-4-design.md:1208-1218).
  FIND [[               (vector-ref (parser-field-values parser) i))]]
  REPLACE [[               (vector-ref (parser-field-values parser) 0))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a fresh parser reads the declared initial at every width: limit -- expected 65535, got 7")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.field.chez.source
  LABEL "runtime: parser-reset! does not restore the field values"
  # *** CLOSED by Slice ② task 6+7, which is exactly the reopening condition the
  # EXPECT_SURVIVES this replaces wrote for itself: "the same commit that gives
  # fields a writer must delete this EXPECT_SURVIVES and pin the mutation, and
  # the isolation case field-access-tests.sps declines for the same reason
  # belongs there too." Both are done in that commit. ***
  #
  # Slice ①b could not witness this because parser-field-ref was read-only and
  # nothing wrote a field, so slot 8 was constant for a parser's lifetime and
  # restoring a constant is a no-op. A parse now changes it, and the difference
  # between a reset that restores and one that does not is two numbers. The
  # suite's declared survivors go back to TEN.
  FIND [[    (vector-set! parser 8 (initial-values (parser-field-decls parser)))))]]
  REPLACE [[    ))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "parser-reset! restores a field a parse has CHANGED: restored to the declared initial -- expected 254, got 255")

# Slice ② tasks 6 and 7 add FIVE to this pass -- the first fixture in the tree
# whose fields a parse actually changes, which is what makes them witnessable.

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.differential.field.chez.source
  LABEL "interpret: an overflowing field operation writes anyway"
  # §25:1569 and §10.6:568: a failed operation leaves the prior value UNCHANGED,
  # not saturated. This SURVIVED against the first fixture, whose only overflow
  # started AT the ceiling -- where "unchanged" and "clamped to the maximum"
  # coincide. An `add` that overflows from BELOW it separates them.
  FIND [[              (field-action-node-error n))))]]
  REPLACE [[              (begin (vector-set! fv slot m*) (field-action-node-error n)))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "an overflow from BELOW the ceiling does not clamp: unchanged, not clamped -- expected 254, got 255")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.differential.field.chez.source
  LABEL "interpret: the field bound is never checked"
  # The other direction: with no check the value simply exceeds its declared
  # width and the error target is never reached.
  FIND [[          (if (<= 0 r m*)]]
  REPLACE [[          (if #t]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a failed operation leaves the prior value unchanged \\(§25:1569\\): count held at its maximum -- expected 255, got 256")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.differential.field.chez.source
  LABEL "interpret: increment does not increment"
  # One arm of the operation table, standing for all seven: the arithmetic is
  # written TWICE on purpose (§18:970-972) and this is the interpreter's copy.
  FIND [[                    ((increment) (+ v 1))]]
  REPLACE [[                    ((increment) v)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "an increment commits into the parser's own storage: count -- expected 255, got 254")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.field.chez.source
  LABEL "runtime: a zero-width step consumes a byte"
  # Zero-width means zero-width: the loop must re-enter at the SAME pos. A
  # zero-width node that advanced would silently eat the byte the next dispatch
  # was going to read.
  FIND [[               (parser-set-current! parser t)
               (loop pos pk)))]]
  REPLACE [[               (parser-set-current! parser t)
               (loop (+ pos 1) pk)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "fields a parse actually writes \\(Slice ②\\)\\.a failed operation leaves the prior value unchanged \\(§25:1569\\): lifecycle -- expected error, got ready")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.field.chez.source
  LABEL "runtime: a zero-width step resets the position kind"
  # §12.7:777 makes position kind differential-compared, so the two lanes must
  # agree. A zero-width step does not move the parser in the input, so the kind
  # is carried THROUGH -- a failure reached after one reports what it would have
  # reported without it.
  FIND [[             (parser-set-current! parser t)
             (loop t pk)))]]
  REPLACE [[             (parser-set-current! parser t)
             (loop t 'boundary)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a failure after a zero-width hop on an EOF chain reports eof, not boundary: position kind -- expected eof, got boundary")

# Slice ② task 8 adds SIX for the EMITTER's field arms. Everything they pin is a
# SECOND implementation of what the interpreter's mutations already pin -- the
# arithmetic is written twice on purpose (§18:970-972), and these are the copy
# the differential exists to compare.
#
# One mutation is measured and NOT written: swapping the branch arms produces a
# record set IDENTICAL to "the emitted zero predicate is inverted" below -- not a
# subset, the same set. On a two-armed branch, swapping the arms and negating the
# predicate are the same function, so no fixture can separate them by behaviour;
# only reading the source tells them apart.

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.field.chez.source
  LABEL "compile: the emitted bound check is absent"
  # §25:1568's operation share, emitter side.
  FIND [[         (if (and (>= r 0) (<= r "]]
  REPLACE [[         (if (or #t (>= r 0) (<= r "]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "fields a parse actually writes \\(Slice ②\\)\\.both lanes agree over every input the fixture can take: count \\[10\\] -- expected 254, got 265")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.field.chez.source
  LABEL "compile: the emitted upper bound is off by one"
  # The boundary rather than the check: a u8 accepts 255 and rejects 256.
  FIND [[(num (- (expt 2 width) 1))]]
  REPLACE [[(num (expt 2 width))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "fields a parse actually writes \\(Slice ②\\)\\.both lanes agree over every input the fixture can take: count \\[00\\] -- expected 255, got 256")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.field.chez.source
  LABEL "compile: an emitted overflow writes the value anyway"
  # §25:1569 and §10.6:568, emitter side: a failed operation leaves the prior
  # value UNCHANGED, not saturated. The fixture's `add` overflows from BELOW the
  # ceiling, which is what makes unchanged and clamped distinguishable at all.
  FIND [[                "             " (zero-width-jump (cdr tg)) ")))\n")]]
  REPLACE [[                "             (begin (vector-set! fieldv " (num slot) " r) " (zero-width-jump (cdr tg)) "))))\n")]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "fields a parse actually writes \\(Slice ②\\)\\.both lanes agree over every input the fixture can take: count \\[10\\] -- expected 254, got 264")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.field.chez.source
  LABEL "compile: an emitted increment does not increment"
  # One arm of the emitter's operation table, and the counterpart of the
  # interpreter mutation of the same name -- two implementations, two pins.
  FIND [[      ((increment) "(+ v 1)")]]
  REPLACE [[      ((increment) "v")]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the generated lane writes, checks and routes identically: count -- expected 255, got 254")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.field.chez.source
  LABEL "compile: an emitted zero-width step consumes a byte"
  # Zero-width means zero-width in the generated lane too: the emitted jump
  # keeps pos, off and pk. Advancing would eat the byte the next dispatch reads.
  FIND [[(string-append "(loop pos " (num target) " off pk)"))]]
  REPLACE [[(string-append "(loop (+ pos 1) " (num target) " off pk)"))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "fields a parse actually writes \\(Slice ②\\)\\.both lanes agree over every input the fixture can take: lifecycle \\[00\\] -- expected error, got ready")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.field.chez.source
  LABEL "compile: the emitted zero predicate is inverted"
  # The branch arm. See this block's header for the mutation it stands in for.
  FIND [[      ((zero) "(= v 0)")]]
  REPLACE [[      ((zero) "(not (= v 0))")]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the generated lane writes, checks and routes identically: seen -- expected 1, got 101")

# Slice ② task 9 adds THREE for the operation matrix. The two lower-bound
# mutations are what the matrix exists for: every earlier fixture in this slice
# overflows UPWARD, so a check that tested only the upper bound passed all of
# them. §25:1568 asks for underflow at `decrement` from 0 as well, and it is the
# only place the lower half of the bound is load-bearing.

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.differential.field.chez.source
  LABEL "interpret: the field lower bound is not checked"
  # A decrement at 0 goes to -1 and is accepted. Caught in the INTERPRETER's
  # half of the comparison, which is what makes it distinct from the emitter's.
  FIND [[          (if (<= 0 r m*)]]
  REPLACE [[          (if (<= r m*)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the operation matrix over every width \\(§25:1568, §25:1569\\)\\.overflow, underflow and success agree across widths and lanes: interp lo u8 \\[2\\] -- expected 0, got -1")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.field.chez.source
  LABEL "compile: the emitted field lower bound is not checked"
  # The same decision in the emitter's copy of the arithmetic. Its record names
  # the GENERATED half, which the interpreter mutation never touches.
  FIND [[         (if (and (>= r 0) (<= r "]]
  REPLACE [[         (if (and #t (<= r "]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the operation matrix over every width \\(§25:1568, §25:1569\\)\\.overflow, underflow and success agree across widths and lanes: gen lo u8 \\[2\\] -- expected 0, got -1")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.differential.field.chez.source
  LABEL "interpret: decrement does not decrement"
  # The success control's other side: without a real decrement the underflow
  # row stops underflowing and the lifecycle flips.
  FIND [[                    ((decrement) (- v 1))]]
  REPLACE [[                    ((decrement) v)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the operation matrix over every width \\(§25:1568, §25:1569\\)\\.overflow, underflow and success agree across widths and lanes: lifecycle u8 \\[2\\] -- expected ready, got error")

# *** Slice ②'s whole-branch review found that SIX of the fourteen operations
# and predicates appeared in no fixture at all -- clear-mask, equal, nonzero,
# mask-any, mask-all and mask-none -- so their two independent implementations
# were never compared. The design says writing them twice is "the single class
# of defect this milestone introduces" and the differential is what catches it;
# a differential only compares what a fixture EXERCISES. Measured: inverting the
# EMITTER's mask-none alone left all 92 lanes at status 0. ***
#
# The coverage group closes it, and TWO mutations pin the group itself -- one per
# lane, on a member that had no fixture before it. The other four are covered by
# the same two checks and are not written separately: their record sets differ
# only in which row of the same loop reddens, so a mutation per member would add
# twelve pins that all resolve to the same two (case, check) pairs.

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.field.chez.source
  LABEL "compile: the emitted mask-none predicate is inverted"
  # Previously unexercised in BOTH lanes. This is the exact mutation whose
  # survival was the review's evidence: before the coverage group, it passed
  # every lane in the tree.
  FIND [[      ((mask-none) (string-append "(= 0 (bitwise-and v " (num a) "))"))]]
  REPLACE [[      ((mask-none) (string-append "(not (= 0 (bitwise-and v " (num a) ")))"))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "every predicate takes the same arm in both lanes: gen mask-none 3 -- expected 1, got 2")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.differential.field.chez.source
  LABEL "interpret: mask-all is computed as mask-any"
  # The INTERPRETER's half, and the reason the operands are chosen to separate
  # each predicate from its siblings rather than merely to exercise it: with
  # `mask-all 12` on f=12 this mutation answers correctly and SURVIVED. The
  # operand is 14, where 12 has some of the mask bits but not all.
  FIND [[                      ((mask-all) (= a (bitwise-and v a)))]]
  REPLACE [[                      ((mask-all) (not (= 0 (bitwise-and v a))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "every predicate takes the same arm in both lanes: interp mask-all 14 -- expected 2, got 1")

# Slice ③ task 4 adds FIVE pinned and TWO survivors for the checked
# multiply-add, written twice as §18:970-972 requires.
#
# *** The two survivors are the SAME decision in the two lanes, and their reason
# is §15:856 itself. *** Replacing the pre-check `current <= floor((maximum -
# digit) / base)` with a compute-then-check `current * base + digit <= maximum`
# gives IDENTICAL answers on this host, because Chez has bignums and never
# wraps. §15:864-868 specifies the pre-check anyway, and §15:856 says why --
# "must not rely on host fixnum width or silent wrapping" -- so the form is
# mandated for a host this project does not run on. No fixture can distinguish
# them here; that is a property of the host, not a gap in the lane.

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.differential.field.chez.source
  LABEL "interpret: base 16's lowercase digits are not digits"
  # The reason the fixture spells 1aF: base 16's digits are three DISJOINT
  # ASCII ranges, and a fixture using only 0-9 passes against an implementation
  # that handles no letters at all.
  FIND [[((and (>= byte 97) (<= byte 102)) (+ 10 (- byte 97)))]]
  REPLACE [[((and (>= byte 97) (<= byte 102)) #f)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the checked multiply-add, both lanes \\(Slice ③\\).base 16 accepts all three ASCII digit ranges: interpreter")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.differential.field.chez.source
  LABEL "interpret: a digit is not bounded by the base"
  # `a` is a digit in base 16 and not in base 10. Without this bound a base-10
  # machine would accumulate hex letters.
  FIND [[(and v (< v base) v)]]
  REPLACE [[(and v v)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the checked multiply-add, both lanes \\(Slice ③\\).a base-10 machine does not accept a hex letter as a digit: interpreter")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.differential.field.chez.source
  LABEL "interpret: an overflow consumes the offending digit"
  # §12.7:772-773: overflow does NOT consume the digit, which is what makes the
  # reported position kind `byte` rather than `boundary`. The value being
  # unchanged is the other half and is pinned by the matrix.
  FIND [[(cons (integer-accumulate-node-overflow-error n) 'reexecute)]]
  REPLACE [[(cons (integer-accumulate-node-overflow-error n) 'advance)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the checked multiply-add, both lanes \\(Slice ③\\).an overflow reports position kind BYTE, at the offending digit: interpreter")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.field.chez.source
  LABEL "compile: base 16's lowercase digits are not emitted as digits"
  # The emitter's copy of the same decision -- written twice on purpose, and
  # this is the half the differential exists to compare.
  FIND [[" ((and (>= b 97) (<= b 102)) (+ 10 (- b 97)))"]]
  REPLACE [[" "]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the checked multiply-add, both lanes \\(Slice ③\\).base 16 accepts all three ASCII digit ranges: generated")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.field.chez.source
  LABEL "compile: an emitted overflow consumes the offending digit"
  FIND [[            "                       (loop pos " (num over) " off (quote byte))))))))\n"]]
  REPLACE [[            "                       (loop (+ pos 1) " (num over) " (+ off 1) (quote boundary))))))))\n"]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the checked multiply-add, both lanes \\(Slice ③\\).an overflow reports position kind BYTE, at the offending digit: generated")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.differential.field.chez.source
  LABEL "interpret: the overflow check is made after the multiply-add"
  FIND [[((<= (vector-ref fv slot) (div (- m* d) base))]]
  REPLACE [[((<= (+ (* (vector-ref fv slot) base) d) m*)]]
  EXPECT_SURVIVES
    "measured, not assumed: this mutant passes the whole lane unchanged, in both lanes, and it always will on this host. §15:864-868 specifies the check as `current <= floor((maximum - digit) / base)`, BEFORE the multiply-add; this mutant computes `current * base + digit` first and tests the product. Under Chez the product is an exact integer of unbounded size, so the two forms agree on every input and no fixture can separate them -- including the u64 case, where the accumulated value is already a bignum and the product simply becomes a larger one. The pre-check is written anyway because §15:856 mandates it: \"must not rely on host fixnum width or silent wrapping\". The form is for a host that WRAPS, where computing the product first would silently produce a small wrong number and the check would pass. This project does not run on such a host, so the requirement is unwitnessable here by construction -- a property of the host, not a gap in the lane. Reopening condition: a backend whose integers wrap, or any change that makes the accumulation use fixnum-specialised arithmetic, makes this mutant a bug detector and it must be re-measured and pinned then."
  )

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.field.chez.source
  LABEL "compile: the emitted overflow check is made after the multiply-add"
  FIND [[            "                   (if (<= v (div (- " (num mx) " d) " (num base) "))\n"]]
  REPLACE [[            "                   (if (<= (+ (* v " (num base) ") d) " (num mx) ")\n"]]
  EXPECT_SURVIVES
    "measured, not assumed: this mutant passes the whole lane unchanged, in both lanes, and it always will on this host. §15:864-868 specifies the check as `current <= floor((maximum - digit) / base)`, BEFORE the multiply-add; this mutant computes `current * base + digit` first and tests the product. Under Chez the product is an exact integer of unbounded size, so the two forms agree on every input and no fixture can separate them -- including the u64 case, where the accumulated value is already a bignum and the product simply becomes a larger one. The pre-check is written anyway because §15:856 mandates it: \"must not rely on host fixnum width or silent wrapping\". The form is for a host that WRAPS, where computing the product first would silently produce a small wrong number and the check would pass. This project does not run on such a host, so the requirement is unwitnessable here by construction -- a property of the host, not a gap in the lane. Reopening condition: a backend whose integers wrap, or any change that makes the accumulation use fixnum-specialised arithmetic, makes this mutant a bug detector and it must be re-measured and pinned then. The emitter's copy of the same decision; the two are one ruling and both are recorded so neither can be quietly changed alone."
  )

# Slice ③ task 5 adds ONE. Its content is otherwise TESTS for behaviour the
# accumulate arm INHERITS rather than implements, and that is the task's finding:
# an accumulate node needs no state of its own across a feed boundary. The
# partially-accumulated value IS the field -- parser slot 8, which already
# survives a feed -- and `current` stays parked on the node because the arm
# returns need-input without moving it, exactly as the dispatch arm does. The
# recon asked where that state would live "since it is not obviously a field";
# it is one.
#
# Two candidate mutations were measured and are NOT written, because neither is
# this task's: resetting `current` on need-input SURVIVES (the fixture's entry
# reexecutes back into the accumulate node, so the routing masks it), and reading
# the previous byte is caught by task 4's cases rather than by these.

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.field.chez.source
  LABEL "runtime: an exhausted accumulate slice reports stopped instead of need-input"
  # The accumulate arm's own end-of-slice decision, and the only one this task
  # owns. Caught by the split cases alone -- a single-feed fixture never reaches
  # the guard, which is why fragmentation needed cases of its own rather than
  # being assumed to follow from the dispatch arm's pin.
  #
  # *** ANNOTATED 2026-09-03: "by the split cases alone" was true when measured
  # and is now stale. *** Re-measured on the closed branch, this mutant reddens
  # FOUR groups -- the split cases, task 6's all-256 partition, task 8's
  # default-EOF consumer group, and both property.differential lanes -- every one
  # of them added AFTER this sentence was written. What the pin still rests on is
  # the claim about SHAPE, which re-measuring does not touch: a single-feed
  # fixture cannot reach this guard, so fragmentation needed cases of its own.
  # Left rather than reworded, because a uniqueness claim decaying as the lane
  # grows around it is the useful record here.
  FIND [[            ((accumulate)
             (if (>= pos end)
                 (make-parser-result 'need-input pos]]
  REPLACE [[            ((accumulate)
             (if (>= pos end)
                 (make-parser-result 'stopped pos]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "split-point fragmentation \\(Slice ③\\).a number split across a feed boundary accumulates whole: interpreter")

# Slice ③ task 6 adds TWO -- one per lane, because the task's claim is about
# both lanes agreeing and a mutation to only one of them is what that claim is
# for. Each is an off-by-one at a digit-range BOUND, the defect the shipped
# handful-of-digits fixtures structurally cannot see: they name `a`, `F` and `!`,
# so the bytes that move when a bound slips by one are exactly the bytes they
# never feed. Both are caught by task 6's group ALONE -- measured.

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.differential.field.chez.source
  LABEL "interpret: the base 16 lowercase digit range stops one short of f"
  # 102 is `f`. No shipped fixture feeds it -- the base 16 lane's case uses `a`
  # and `F` -- so this survives every other accumulate test in the tree. Caught
  # twice over here: the all-256 comparison reports the divergent byte, and the
  # partition SIZE drops 22 -> 21, which is the assertion cross-lane agreement
  # cannot make (two lanes wrong together still agree).
  FIND [[((and (>= byte 97) (<= byte 102)) (+ 10 (- byte 97)))]]
  REPLACE [[((and (>= byte 97) (<= byte 101)) (+ 10 (- byte 97)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "base 16 partitions every byte identically in both lanes: no divergence -- expected none, got \\(102")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.field.chez.source
  LABEL "compile: the emitted base 10 digit range admits the colon"
  # 58 is `:`, the byte immediately above `9`, and it decodes to 10 -- a digit
  # worth exactly the base. The emitter is the mutated side here and the
  # interpreter is untouched, so this is caught by the CROSS-LANE half of the
  # partition rather than by any absolute count: the generated machine accepts a
  # byte the interpreter rejects.
  FIND [["(and (>= b 48) (<= b 57) (- b 48))"]]
  REPLACE [["(and (>= b 48) (<= b 58) (- b 48))"]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "base 10 partitions every byte identically in both lanes: no divergence -- expected none, got \\(58")

# Slice ③ task 8's SHIPPED-CODE fix, found by the property generator. The
# emitter's reached-declaration walk credited only `dispatch` states with the
# default-EOF route, so a machine whose only default-eof consumer was an
# accumulate node had that declaration filtered out of the emitted errs table and
# index-of raised while rendering a machine the verifier had just accepted.
#
# Pinned HERE, on a fixed fixture, rather than on the property lane that found
# it: the generated sequence re-rolls whenever any draw changes, and a defect
# whose only witness is a seeded draw has a witness that can vanish without
# anyone editing it. (It fails the property lane too -- measured.)

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.field.chez.source
  LABEL "compile: only dispatch states are credited with consuming the default EOF declaration"
  # Re-anchored by Milestone 11 Slice ①: the credit list gained `keyword-table`.
  # Narrowing it to `dispatch` alone is still the edit and the witness (the field
  # differential's accumulate-only default-eof consumer) is unchanged.
  FIND [[((and (memq (normal-state-kind st)
                                                      '(dispatch accumulate counted-consume
                                                        keyword-table))]]
  REPLACE [[((and (memq (normal-state-kind st)
                                                      '(dispatch))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "no error declaration for code")

# --- Whole-branch review, 2026-09-03: FOUR operands of the accumulate node that
# no EXECUTING fixture reached. Every accumulate machine in the tree declared one
# field, named itself as its digit-target, gave its non-digit edge mode
# `advance`, and overflowed only in base 10 -- so the slot lookup, the
# digit-target operand, §10.6:567's normal reexecute case, and the base in the
# bound's divisor were all free parameters. Seven mutations against one fixture
# that separates all four; each was measured caught by that fixture's group.

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.differential.field.chez.source
  LABEL "interpret: the accumulate commits into slot zero instead of the field it names"
  FIND [[               (slot (car sw)) (m* (field-max (cdr sw)))
               (base (integer-accumulate-node-base n))]]
  REPLACE [[               (slot 0) (m* (field-max (cdr sw)))
               (base (integer-accumulate-node-base n))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the accumulate commits into the field it NAMES, not into slot zero: interpreter n")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.field.chez.source
  LABEL "compile: the emitted accumulate commits into slot zero instead of the field it names"
  FIND [[(slot (car sw)) (mx (- (expt 2 (cdr sw)) 1))]]
  REPLACE [[(slot 0) (mx (- (expt 2 (cdr sw)) 1))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the accumulate commits into the field it NAMES, not into slot zero: generated n")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.differential.field.chez.source
  LABEL "interpret: the overflow bound divides by ten rather than by the node's base"
  # The fixture shape matters and the first one did not work: `#FFFFF` cannot
  # separate a divisor of 16 from one of 10, because 0xFFF passes both bounds and
  # 0xFFFF fails both. The separating value lands BETWEEN them -- `#1000F`, where
  # 4096 > (65535-15)/16 and 4096 <= (65535-15)/10, so the mutant accepts a digit
  # that writes 65551 into a u16.
  FIND [[(div (- m* d) base)]]
  REPLACE [[(div (- m* d) 10)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the overflow bound divides by the node's OWN base, at base 16: interpreter leaves 0x1000")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.field.chez.source
  LABEL "compile: the emitted overflow bound divides by ten rather than by the node's base"
  FIND [[(div (- " (num mx) " d) " (num base) ")]]
  REPLACE [[(div (- " (num mx) " d) 10)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the overflow bound divides by the node's OWN base, at base 16: generated leaves 0x1000")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.field.chez.source
  LABEL "compile: the emitted digit jump self-loops instead of taking digit-target"
  # The operand nothing could see while every accumulate node in the tree WAS its
  # own digit-target: a self-loop is indistinguishable from reading the operand
  # until one fixture points the digit edge somewhere else.
  FIND [[                              (loop (+ pos 1) " (num digit) " (+ off 1) (quote boundary)))]]
  REPLACE [[                              (loop (+ pos 1) " id " (+ off 1) (quote boundary)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "one digit is taken and the DECLARED digit-target stops the parse: generated stopped")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.differential.field.chez.source
  LABEL "interpret: the non-digit edge always advances, ignoring its declared mode"
  # §10.6:567's NORMAL case -- "normally reexecuting the delimiter" -- which no
  # executing fixture in the tree took until this one. Under the mutant the
  # delimiter is consumed at the accumulate node and the fallback dispatch that
  # was supposed to read it runs out of input instead.
  FIND [[            (let ((e (integer-accumulate-node-nondigit-edge n)))
              (cons (edge-target e) (edge-mode e))))]]
  REPLACE [[            (let ((e (integer-accumulate-node-nondigit-edge n)))
              (cons (edge-target e) 'advance)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the delimiter is re-read with no action anywhere in the path: interpreter stopped at sawx")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.field.chez.source
  LABEL "compile: the emitted non-digit edge always advances, ignoring its declared mode"
  # The emitter's copy of the same decision. Written as a tautology rather than
  # by deleting the branch, so the mutation changes WHICH arm is rendered without
  # changing the shape of the code around it.
  FIND [[                 " (if (eq? (cdr nd) 'advance)]]
  REPLACE [[                 " (if (eq? (car nd) (car nd))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the delimiter is re-read with no action anywhere in the path: generated stopped at sawx")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Slice ③ task 9: the accumulate determinism lane (pass 50) ---------------
#
# A pass of its own because the verify command is a different program, and the
# ONE mutation in it is one no behavioural lane can catch: it reorders the two
# uppercase/lowercase arms of the emitted base 16 digit `cond`. The ranges are
# disjoint, so every input decodes to the same digit and every differential,
# property and position-kind lane passes -- the emitted BYTES change, and the
# committed golden is the only thing that looks at those.
#
# That is the whole argument for a fourth golden, made falsifiable. §8 asked for
# this lane and for an empty test/fixtures diff in the same breath; this mutation
# is why the lane won.
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/determinism-accumulate-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls
  SPEC byte-machine.determinism.accumulate.chez.source
  LABEL "compile: the emitted base 16 digit cond tries uppercase before lowercase"
  FIND [[                            " ((and (>= b 97) (<= b 102)) (+ 10 (- b 97)))"
                            " ((and (>= b 65) (<= b 70)) (+ 10 (- b 65)))"]]
  REPLACE [[                            " ((and (>= b 65) (<= b 70)) (+ 10 (- b 65)))"
                            " ((and (>= b 97) (<= b 102)) (+ 10 (- b 97)))"]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the emitted bytes equal the committed golden: golden")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Milestone 5 Slice ⓪ task 6: the diagnostic census (pass 51) -------------
#
# This pass is why BYTE_MACHINE_SOURCE_ROOT is set to ${STAGE_DIR}/src at the top
# of this file: the census READS the source it is asserting about, so it must
# read the staged copy the mutation was applied to. Pointed at the pristine tree
# it would compare a file with itself and report every mutation here as caught.
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/diagnostic-census-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.diagnostic-census.chez.source
  LABEL "ir: an eighth field operation is declared with no operand schema row"
  # The drift the row exists for, and measured caught by the census ALONE -- the
  # two tables live in different files, written under different rules, and
  # nothing compared them before. verify.sls's own comment at the schema lookup
  # calls a mismatch "unreachable through the public API", which is verbatim the
  # shape of Slice ③'s first Critical: a closed-set claim made in prose.
  FIND [[(define field-operations '(store clear increment decrement add set-mask clear-mask))]]
  REPLACE [[(define field-operations '(store clear increment decrement add set-mask clear-mask frobnicate))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the fourteen names agree across the two files: declared names equal tabulated names")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.unit.diagnostic-census.chez.source
  LABEL "verify: pass-declarations is never run"
  # Milestone 5 Slice ①b task 7. The whole pass, dropped from verify-machine's
  # append. Eight of the census's twenty-four fixtures then find no diagnostic at
  # all, so this is caught by a COMPARISON naming a missing code rather than by a
  # raise from wherever the walk happens to stop.
  # The following line rides along in both halves: the runner refuses an empty
  # REPLACE, so the pass is dropped by rewriting the pair rather than by deleting
  # a line.
  # Re-anchored by Slice ③: `pass-spans` (§16.3:925's pass 7) sits between them
  # in `verify-machine`'s append. The edit -- drop pass-declarations -- is
  # unchanged, and its sibling below now pins pass 7 the same way.
  FIND [[                                  (pass-declarations machine)
                                  (pass-spans machine)]]
  REPLACE [[                                  (pass-spans machine)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "duplicate-callback-declaration is emitted")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.unit.diagnostic-census.chez.source
  LABEL "verify: pass-spans is never run"
  # Milestone 5 Slice ③, and the same shape as its sibling above: the whole pass
  # dropped from verify-machine's append. All four span fixtures then find no
  # diagnostic at all, so this is caught by a COMPARISON naming missing codes
  # rather than by a raise from wherever the walk happens to stop. The following
  # line rides along in both halves; the runner refuses an empty REPLACE.
  FIND [[                                  (pass-spans machine)
                                  (pass-overlap machine)]]
  REPLACE [[                                  (pass-overlap machine)]]
  EXPECT_STATUS 1
  # Measured: each of the four span codes has a fixture, so the per-code loop
  # fails four times by name before the summary row does. Pinned on one of them,
  # which is what attributes this to the PASS rather than to a fixture.
  EXPECT_OUTPUT_MATCHES "inconsistent-span-state is emitted -- expected a true value")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.unit.diagnostic-census.chez.source
  LABEL "verify: an emission site is relabelled with another existing code"
  # The per-code site counts, which is the half of the census that notices a code
  # moving rather than appearing. Behavioural lanes also redden here -- a
  # relabelled site reports the wrong code to a fixture that names it -- but the
  # record pinned is the census's own count row, which is what attributes the
  # failure to the site table rather than to any one fixture.
  # Re-anchored at Slice ⓪b task 4: the site this pointed at was one of two
  # `eof-reachable-stop` emissions, and the §16.2:909 collapse left one.
  FIND [[(make-diagnostic/path 'eof-reachable-stop (node-name n)]]
  REPLACE [[(make-diagnostic/path 'zero-progress-cycle (node-name n)]]
  EXPECT_STATUS 1
  # Tightened by Milestone 7 Slice ①: Slice ①'s new "a path-bearing site is
  # relabelled to a non-path code" mutation ALSO reddens this case (it relabels a
  # path site too), so the bare case name resolved to two mutants. Pinned instead
  # on the count row unique to THIS mutant -- it relabels to `zero-progress-cycle`,
  # so that code reads 2; the Slice ① mutant relabels to `duplicate-name` and
  # leaves `zero-progress-cycle` at 1.
  EXPECT_OUTPUT_MATCHES
    "the code set and the per-site counts match the pinned table: zero-progress-cycle -- expected 1, got 2")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.unit.diagnostic-census.chez.source
  LABEL "verify: a new diagnostic code appears with no fixture and no pinned row"
  # The RATCHET itself, which is the census's whole reason to exist. This is what
  # a Milestone 5 or 6 slice adding a code looks like to the suite: the code set
  # derived from the source no longer matches the pinned table, AND the
  # source-derived loop finds a code with no machine that emits it. Both layers
  # fire, which is deliberate -- the pinned table alone would let a code be
  # accounted for on paper without ever being produced.
  FIND [[(make-diagnostic 'unreachable-node (node-name n) "node is unreachable")]]
  REPLACE [[(make-diagnostic 'unreachable-nodes (node-name n) "node is unreachable")]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "no source code lacks a fixture")

# --- Milestone 7 Slice ①: the census path row's two directions --------------
# A mutation is witnessed only by its own SPEC lane's program, so these two run
# on the diagnostic-census lane: one makes a path site pathless (the per-site
# count moves), the other relabels a path site to a non-path code (the code set
# moves). Together they close both halves of decision 0032 item 6.

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.unit.diagnostic-census.chez.source
  LABEL "verify: a path-bearing site is made pathless"
  # The two constructors have the same arity, so this compiles and the site's code stays path-bearing while its constructor stops carrying a path -- the half of decision 0032 item 6 that keeps a new site under a path-bearing code from shipping pathless.
  FIND [[(make-diagnostic/path 'zero-progress-cycle (node-name n)]]
  REPLACE [[(make-diagnostic/declarations 'zero-progress-cycle (node-name n)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "make-diagnostic/path sites -- expected 11, got 10")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.unit.diagnostic-census.chez.source
  LABEL "verify: a path-bearing site is relabelled to a non-path code"
  # The row's other half ('no other site passes a path'): a non-path code now rides a path constructor. Separable from the shipped 'an emission site is relabelled' -- which relabels WITHIN the path set -- by the got, which carries `duplicate-name`.
  FIND [[(make-diagnostic/path 'eof-reachable-stop (node-name n)]]
  REPLACE [[(make-diagnostic/path 'duplicate-name (node-name n)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the codes emitted through a path constructor equal the declared policy -- expected \\(eof-reachable-stop eof-zero-progress-cycle inconsistent-span-state invalid-span-state non-eof-into-finish span-active-at-exit span-active-at-pause zero-progress-cycle\\), got \\(duplicate-name")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Milestone 5 Slice ⓪ task 2: the kind x position matrix (pass 52) --------
#
# The matrix's value is BREADTH, not unique catches on today's tree: it drives
# every node kind through every structural position, so a kind added tomorrow is
# exercised in all sixteen positions without anyone writing sixteen fixtures.
# Most single-kind omissions it would catch are also caught by some existing
# lane -- measured, and said plainly rather than dressed up.
#
# What it catches ALONE is the ratchet below, and that is the point.
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/kind-position-census-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls
  SPEC byte-machine.unit.kind-position-census.chez.source
  LABEL "ir: node? admits a kind the matrix's table does not cover"
  # THE RATCHET. `node?`'s disjunct list IS the closed set of node kinds, and S2
  # derives the matrix's coverage from it rather than from a list in the test --
  # a list in the test would be one more census that goes stale, which this
  # project has now paid for five times. When Milestone 5 adds a callback node
  # kind, this row goes red BEFORE any fixture does, and the sixteen positions
  # are then exercised for it by construction.
  #
  # Measured caught by the matrix ALONE: no other lane in the tree notices.
  FIND [[        (integer-accumulate-node? x) (callback-node? x)
        (span-start-node? x) (span-end-node? x) (counted-consume-node? x)))]]
  REPLACE [[        (integer-accumulate-node? x) (callback-node? x)
        (span-start-node? x) (span-end-node? x) (counted-consume-node? x) (stop-node? x)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the same fourteen kinds -- expected")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls
  SPEC byte-machine.unit.kind-position-census.chez.source
  LABEL "ir: node-source-label loses an arm"
  # Milestone 6 Slice ⓪'s S2b ratchet, the SECOND per-kind census in ir.sls the
  # matrix derives from the file. Deleting an arm shrinks the cond's predicate
  # set to eleven, and the row's count check says so by comparison -- before any
  # fixture for a missing kind exists, which is the point of deriving it. The
  # sibling `#f`-arm mutant in the ir pass leaves the predicate set intact and
  # cannot redden this row; the two are separate decisions. S2b's set-equality
  # check is labelled "arm predicates equal node?'s disjuncts" and NOT "the same
  # twelve kinds": the slice's first label contained the ratchet pin's substring
  # and the sweep found that pin satisfied by this mutant -- the exact resolution
  # the plan's F2 warned about, caught by the sweep and not by the lane.
  FIND [[          ((stop-node? x) (stop-node-source-label x))
          ((error-node? x) (error-node-source-label x))]]
  REPLACE [[          ((error-node? x) (error-node-source-label x))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "and there are fourteen of them -- expected 14, got 13")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls
  SPEC byte-machine.unit.kind-position-census.chez.source
  LABEL "verify: a zero-width edge role loses its label"
  # Milestone 5 Slice ①a's FINAL REVIEW, closing a gap the slice's own comment
  # had argued was unclosable. That comment claimed the position drift row is
  # BLIND under this suite -- the census reads the STAGED tree (:1157), so a
  # mutation deleting a role deletes it from the code AND from the set derived
  # in the test. The first half is true; the conclusion is not. The derived set
  # is compared against `role->positions`, which is DECLARED in the test file,
  # and a mutation rewrites only the file its own FILE names -- so the mutated
  # verifier meets an unmutated mapping and the two disagree.
  #
  # This pin is the proof. Renaming `true` breaks the derived-equals-mapped
  # assertion by a COMPARISON, naming both sides, rather than by a raise
  # somewhere downstream. Measured: caught by the census lane alone.
  FIND [[           (list (cons 'true (field-branch-node-true-target n))]]
  REPLACE [[           (list (cons 'tru (field-branch-node-true-target n))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "derived roles equal the mapped roles -- expected")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls
  SPEC byte-machine.unit.kind-position-census.chez.source
  LABEL "verify: cycle and eof-reachable-stop are merged into one tier"
  # The 25-cell verdict lattice is what certifies Slice ⓪b's tiers rather than
  # taking them on trust: every sibling pair, and the join must be the higher
  # tier. Merging the top two tiers collapses ten of the twenty-five cells onto
  # the wrong diagnostic -- `cycle` stops outranking `eof-reachable-stop`, which
  # is the ONE relation decision 0021 item 1 pins by name, and the one a
  # non-terminating machine depends on.
  FIND [[      (eof-reachable-stop)
      (cycle)))]]
  REPLACE [[      (eof-reachable-stop cycle)
      ()))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the join is the higher tier every time")

# --- Milestone 5 Slice ② task 2: the tenth kind's four verifier decisions ----
#
# Every pin below was MEASURED by applying the edit by hand and reading which
# records the census emits, not derived from the code. Two of the four produce
# exactly one FAIL record; the other two are pinned on the record that is theirs
# alone among these mutants.
byte_machine_mutation(
  FILE src/byte-machine/verify.sls
  SPEC byte-machine.unit.kind-position-census.chez.source
  LABEL "verify: a callback node's three targets are not edges at all"
  # The whole arm, dropped from `zero-width-edges` -- the one census that
  # `node-out-edges`, `zero-width-successors` and `eof-successors` are all views
  # of. Pinned on AXIS C, deliberately: on axes A and B this mutant makes
  # `join-over` raise its own "empty zero-width join", which is a crash rather
  # than a discrimination, while axis C fails by a COMPARISON naming both sides
  # -- three positions that should report `missing-target` and report nothing.
  FIND [[          ((callback-node? n)
           (append (list (cons 'continue (callback-node-continue-target n)))]]
  REPLACE [[          ((and #f (callback-node? n))
           (append (list (cons 'continue (callback-node-continue-target n)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "each reports its derived fault -- expected .*callback-pause-continuation want .missing-target")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls
  SPEC byte-machine.unit.kind-position-census.chez.source
  LABEL "verify: a parked callback is classified as if the walk had flowed through it"
  # THE DECISION SLICE ② ADDED THAT NO OLDER KIND NEEDED. A parser parked at a
  # callback node is parked because that callback returned pause, so §13:812
  # resumes on its pause continuation ALONE; classifying the node itself joins
  # over the continue and branch targets too. The mutant reports
  # `eof-reachable-stop` for a stop terminal that only a feed-time `continue`
  # reaches -- a legal `stopped` feed result and no EOF path. Measured: four
  # cells, across axes A and B; pinned on the axis-A record, which no other
  # mutant in this lane emits.
  # Re-anchored by Milestone 6 Slice ①, which turned the `if` into a `cond` with
  # a counted-consume arm; the mutant is still "a parked callback starts its
  # walk at its own name".
  FIND [[    (cond ((and (callback-node? n) (not (eq? (node-name n) (machine-entry m))))
           (callback-node-pause-continuation n))]]
  REPLACE [[    (cond ((and (callback-node? n) (not (eq? (node-name n) (machine-entry m))))
           (node-name n))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "callback-branch stop want .. got .eof-reachable-stop")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls
  SPEC byte-machine.unit.kind-position-census.chez.source
  LABEL "verify: a callback node's branch edges borrow the continue role"
  # The role VOCABULARY, one level finer than the sibling above: the three edges
  # carry three §13:803-808 outcome labels, and collapsing two of them is
  # invisible to reachability and to both terminal rules. Caught only by A',
  # which compares the roles derived from this file against the mapping declared
  # in the test -- one FAIL record, measured.
  FIND [[                   (map (lambda (b) (cons 'branch (cadr b)))]]
  REPLACE [[                   (map (lambda (b) (cons 'continue (cadr b)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "derived roles equal the mapped roles -- expected .*got .alternative case continuation continue digit")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls
  SPEC byte-machine.unit.kind-position-census.chez.source
  LABEL "verify: the zero-progress REPORT set excludes the callback kind"
  # The half-fix Milestone 3 Slice ② shipped and Slice ③ closed, one kind later:
  # the WALK finds the cycle, nothing reports it, and a callback that continues
  # into itself verifies clean and then invokes its callback forever in both
  # lanes. Its own record is the pause-continuation cell, where the mutant keeps
  # the EOF cycle and loses the feed one -- a record no other mutant here emits.
  FIND [[                                         (integer-accumulate-node? n)
                                         (callback-node? n)
                                         (span-start-node? n) (span-end-node? n)
                                         (counted-consume-node? n))
                                     (self-cycle (node-name n)))]]
  REPLACE [[                                         (integer-accumulate-node? n)
                                         (span-start-node? n) (span-end-node? n)
                                         (counted-consume-node? n))
                                     (self-cycle (node-name n)))]]
  EXPECT_STATUS 1
  # RE-ANCHORED by Milestone 7 Slice ⓪: the pin was the bare cell prefix
  # "callback-pause-continuation advance want", which this slice's new "the
  # parked set loses the callback disjunct" also emits (it moves the same cell's
  # verdict). The whole measured axis-B record is unique to this mutant --
  # collision set EMPTY, as on the merge base.
  EXPECT_OUTPUT_MATCHES
    "every position pointed at itself .axis B..each self-reference matches its derived verdict: each matches its derivation -- expected .., got ..callback-pause-continuation advance want .eof-zero-progress-cycle zero-progress-cycle. got .eof-zero-progress-cycle.. .callback-branch advance want .zero-progress-cycle. got ... .callback-continue advance want .zero-progress-cycle. got ....")

# Milestone 5 Slice ③ task 1: the span kinds' single successors. Each arm is its
# own mutation because axis C names the position that failed.
byte_machine_mutation(
  FILE src/byte-machine/verify.sls
  SPEC byte-machine.unit.kind-position-census.chez.source
  LABEL "verify: a span-start node's successor is not an edge"
  FIND [[          ((span-start-node? n) (list (cons 'next (span-start-node-next n))))]]
  REPLACE [[          ((span-start-node? n) '())]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "each reports its derived fault -- expected .*span-start-next want .missing-target")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls
  SPEC byte-machine.unit.kind-position-census.chez.source
  LABEL "verify: a span-end node's successor is not an edge"
  FIND [[          ((span-end-node? n) (list (cons 'next (span-end-node-next n))))]]
  REPLACE [[          ((span-end-node? n) '())]]
  EXPECT_STATUS 1
  # RE-MEASURED at task 8, when the span end joined §16.2:909's parked set. The
  # mutant used to lose two findings from the axis-C cell; now the span end is a
  # walk START with no out-edge, so `eof-terminal`'s zero-width join is empty and
  # RAISES before any verdict is compared -- a stronger consequence than the one
  # first recorded, and the pin has to name it or it is a stale expectation.
  #
  # Its span-start sibling above ALSO raises, but only on axis A: at
  # `span-start-next` the span start is not a walk start, so axis C still reaches
  # its value comparison. The axis-C RAISE is therefore this mutant's alone, and
  # that is the line pinned.
  EXPECT_OUTPUT_MATCHES
    "a target naming no node .axis C..every position reports the resolution fault its route calls for: case raised")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls
  SPEC byte-machine.unit.kind-position-census.chez.source
  LABEL "verify: the zero-progress REPORT set excludes the span kinds"
  # The half-fix Milestone 3 Slice ② shipped, two kinds later: the WALK finds
  # the cycle and nothing reports it, so a span node whose successor is itself
  # verifies clean and then hangs in both lanes.
  FIND [[                                         (span-start-node? n) (span-end-node? n)
                                         (counted-consume-node? n))
                                     (self-cycle (node-name n)))]]
  REPLACE [[                                         (counted-consume-node? n))
                                     (self-cycle (node-name n)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "span-start-next advance want")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls
  SPEC byte-machine.unit.kind-position-census.chez.source
  LABEL "verify: the parked set loses the callback disjunct"
  # The parked set's OTHER unpinned disjunct, and its only witness is in THIS
  # lane -- `verify-tests.sps` passes with the disjunct gone (measured on both
  # the pre-0031 tree and the unified one), so a pin declared in Pass 33 would
  # ship UNCAUGHT. A mutation is witnessed only by its own SPEC lane's program
  # (AGENTS.md), so it is declared here, where the axis-A cell
  # `(callback-pause-continuation stop)` loses its `eof-reachable-stop`.
  FIND [[             (callback-node? n)
             (span-end-node? n)]]
  REPLACE [[             (span-end-node? n)]]
  EXPECT_STATUS 1
  # The axis-A cell, measured. The axis-B self cell moves too
  # (`(callback-pause-continuation advance)` loses `eof-zero-progress-cycle`),
  # and one record is enough: this pin resolves once in this mutant's own FAIL
  # records and no other mutant in the pass satisfies it.
  EXPECT_OUTPUT_MATCHES
    "every kind in every position agrees with §16.2 .axis A..the product is driven and every cell matches its derived verdict: and every one matches §16.2 -- expected .., got ..callback-pause-continuation stop want .eof-reachable-stop. got ....")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Milestone 5 Slice ②: the callback node executes (pass 53) ---------------
#
# The differential lane is the SPEC because the emitted arm exists nowhere else:
# no other program in the tree loads a generated library containing a callback
# state. Two of the seven mutations below edit code SHARED by both lanes --
# `byte-machine-callback-step/v1`'s vocabulary and the callback-domain error
# record -- so the cross-lane comparison cannot see them at all: both lanes move
# together and agree. They are caught by that program's BY-VALUE assertions,
# which is the "agreement must stay observable" rule with a mutation behind it
# rather than a paragraph.
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/differential-callback-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.callback.chez.source
  LABEL "runtime: a callback pause parks on the continue target"
  # §13:814 parks `current` PAST the invocation on the DECLARED pause
  # continuation. The two arms are textually distinct by indentation alone --
  # `parser-feed-op!`'s sits two spaces deeper than `parser-finish-op!`'s -- so
  # each is its own one-site FIND and each is its own decision.
  FIND [[                  (parser-set-current! parser (cadddr parts))]]
  REPLACE [[                  (parser-set-current! parser (cadr parts))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "resume then feed agrees, and the callback is not re-delivered: the two lanes agree on the whole walk")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.callback.chez.source
  LABEL "runtime: an EOF callback pause records the FEED pause lifecycle"
  # §12.4:729: "A pause during EOF produces `paused-finish`." Only the
  # interpreted lane is edited, so the differential sees the disagreement.
  FIND [[                (parser-set-current! parser (cadddr parts))
                (parser-set-lifecycle! parser 'paused-finish)]]
  REPLACE [[                (parser-set-current! parser (cadddr parts))
                (parser-set-lifecycle! parser 'paused-feed)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "finish reaching a callback agrees across the lanes: and every one agrees")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.callback.chez.source
  LABEL "runtime: a callback pause is routed as a continue"
  # SHARED CODE: both lanes call this classifier, so both move together and the
  # cross-lane comparison stays green. Caught by the by-value case that asserts
  # the four outcomes are four DISTINCT tuples -- without which a lane pair
  # agreeing on one wrong answer for every outcome would pass.
  # Re-anchored in Slice ③: the classifier moved into `classify-callback-result`
  # (one `cond` serving both arities), so this arm lost six leading spaces. The
  # mutant and its verdict are unchanged.
  FIND [[          ((eq? r callback-pause) (list 'pause))]]
  REPLACE [[          ((eq? r callback-pause) (list 'goto continue))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "and the pause is neither -- expected a true value")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.callback.chez.source
  LABEL "runtime: a callback error is recorded in the machine domain"
  # SHARED CODE again, and decision 0024's Consequences predicted exactly this:
  # `domain` is fixed inside one constructor, so "a check that only compares
  # domain across lanes passes vacuously by construction". The by-value
  # assertion on the whole projected record is what has teeth here.
  FIND [[    (vector parser-error-tag 'callback code callback-error-reason detail]]
  REPLACE [[    (vector parser-error-tag 'machine code callback-error-reason detail]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the callback-domain error carries decision 0024's two codes: the explicit failure's application code")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.differential.callback.chez.source
  LABEL "interpret: an unbound optional callback defaults to the pause continuation"
  # §9.3:419: "other optional callbacks default to `continue`." Decision 0028
  # item 3 resolves that to a TARGET at lowering time, in two independent walks
  # -- this one and `normalize-machine`'s -- so editing either is visible to the
  # differential, which is the whole reason they are not a shared helper
  # (decision 0015 point 3).
  FIND [[                (else (callback-node-continue-target n)))))]]
  REPLACE [[                (else (callback-node-pause-continuation n)))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "both lanes take the default with no closure called: the lanes agree")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.callback.chez.source
  LABEL "compile: the emitted callback pause resumes at the continue target"
  # The generated half of the first mutation in this pass. Both are needed: each
  # edits one lane, and a lane that agreed with a mutated sibling would be the
  # defect neither alone can show.
  FIND [[            "           ((pause) (byte-machine-make-feed-outcome/v1 (quote paused) pos #f "
            (num (cadr tg)) " off))\n"]]
  REPLACE [[            "           ((pause) (byte-machine-make-feed-outcome/v1 (quote paused) pos #f "
            (num (car tg)) " off))\n"]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "resume then feed agrees, and the callback is not re-delivered: the two lanes agree on the whole walk")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.callback.chez.source
  LABEL "compile: the emitted callback arm renders an empty branch map"
  # The branch map is what §13:812's decision half is decided by: with it empty,
  # every returned key falls to the out-of-contract path and the generated lane
  # reports decision 0024's minted code where the interpreted one takes a
  # branch.
  FIND [[            (let join ((bs (normal-field-arguments s)) (acc ""))]]
  REPLACE [[            (let join ((bs '()) (acc ""))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "all six outcomes produce the identical tuple in both lanes: and every one agrees")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.callback.chez.source
  LABEL "runtime: a callback invocation does not commit `current` first"
  # §13:820, and it is only false in ONE lane: the interpreted arm passes the
  # node it is already parked on, so this write is a no-op there and the
  # generated arm passes its own `st`. Without it the emitted lane's callback
  # sees the state the FEED started in -- `start`, not `inv`.
  # The following line rides along in both halves; the runner refuses an empty
  # REPLACE.
  FIND [[    (parser-set-current! parser state)
    (parser-set-offset! parser offset)]]
  REPLACE [[    (parser-set-offset! parser offset)]]
  EXPECT_STATUS 1
  # Pinned on the generated lane's OWN wrong value, not on the bare check label:
  # its sibling below shares that label, and only the recorded tuple separates
  # them. Measured, and the harness prints the SECOND argument as "expected" --
  # here the generated lane, which reports the state the feed started in.
  EXPECT_OUTPUT_MATCHES "committed value -- expected .start 1.*got .inv 1")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.callback.chez.source
  LABEL "runtime: a callback invocation does not commit the offset first"
  # §13:819's half of the same sentence, and the same one-lane asymmetry: the
  # emitted `exec` owns `off` and writes the parser's slot only on return, so
  # without this the callback sees the offset the feed began at.
  FIND [[    (parser-set-current! parser state)
    (parser-set-offset! parser offset)]]
  REPLACE [[    (parser-set-current! parser state)]]
  EXPECT_STATUS 1
  # Its sibling's mirror: same check label, different recorded tuple.
  EXPECT_OUTPUT_MATCHES "committed value -- expected .inv 0.*got .inv 1")

# Milestone 5 Slice ② tasks 6 and 7: §12.2:698-699's two rows, and the first
# slice in which either can be REACHED -- `busy` needs something running inside
# the parser and `poisoned` needs a callback to escape from one.
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.callback.chez.source
  LABEL "runtime: a feed does not mark the parser busy while it runs"
  # §12.1:679, and the line that makes the whole reentrancy row reachable: with
  # it gone the parser is still `ready` inside the callback, so a callback may
  # feed the parser it is running inside and §13:821's own sentence is false of
  # what a callback observes.
  # The following line rides along in both halves; the runner refuses an empty
  # REPLACE.
  # Re-anchored in Slice ③: §14:833's mark re-anchor now sits between the `busy`
  # write and the wind. The FIND had to carry the following lines only because
  # the runner refuses an empty REPLACE, so it carries the new ones instead --
  # the mutant, and its verdict, are unchanged.
  FIND [[(parser-set-lifecycle! parser 'busy)
       (when (parser-active-span parser)]]
  REPLACE [[(when (parser-active-span parser)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "all six answered -- expected .busy inv 1 7")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.callback.chez.source
  LABEL "runtime: a feed refuses a busy parser as a lifecycle violation"
  # §9.4:438 makes "lifecycle violation, reentrancy, poisoned parser" three
  # codes. The mutant still raises, and still raises from the right `who`, so
  # only a pin that names the CODE can see it -- which is why the test asserts
  # per operation by who AND code rather than through one family predicate.
  FIND [[       (byte-machine-contract-violation 'parser-feed! 'reentrancy]]
  REPLACE [[       (byte-machine-contract-violation 'parser-feed! 'lifecycle-violation]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the reentrancy code -- expected .*got ..parser-feed! #f")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.callback.chez.source
  LABEL "runtime: reset has no busy guard"
  # The row §12.2:699 gives reset, and the one operation whose `busy` cell is
  # not its `poisoned` cell. Before Slice ② this procedure had no lifecycle
  # guard at all: five unconditional mutations, so a callback could reset the
  # parser it was running inside and the feed would continue from the entry.
  FIND [[    (when (eq? (parser-lifecycle parser) 'busy)
      (byte-machine-contract-violation 'parser-reset! 'reentrancy]]
  REPLACE [[    (when #f
      (byte-machine-contract-violation 'parser-reset! 'reentrancy]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the reentrancy code -- expected .*got .*.parser-reset! #f")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.callback.chez.source
  LABEL "runtime: an escaping callback does not poison the parser"
  # §12.6:749's consequent. `dynamic-wind`'s after thunk runs on BOTH exits, so
  # the flag is the whole discrimination: without it the normal path poisons
  # every parser, and without the thunk nothing poisons any.
  FIND [[             (unless completed (parser-set-lifecycle! parser 'poisoned))))))
      (else (assertion-violation 'parser-feed! "unknown lifecycle"]]
  REPLACE [[             (unless #t (parser-set-lifecycle! parser 'poisoned))))))
      (else (assertion-violation 'parser-feed! "unknown lifecycle"]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "and it is the callback.s own condition, propagated -- expected ..raised boom. poisoned")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.callback.chez.source
  LABEL "runtime: a poisoned parser is refused as a lifecycle violation"
  # The third of §9.4:438's three codes, and the same argument as the
  # reentrancy pin: the mutant raises, from the right `who`, with the wrong
  # code.
  FIND [[       (byte-machine-contract-violation 'parser-feed! 'poisoned-parser]]
  REPLACE [[       (byte-machine-contract-violation 'parser-feed! 'lifecycle-violation]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a poisoned parser raises parser-poisoned, and only reset reuses it: feed -- raised object did not satisfy the predicate")

# Milestone 5 Slice ② task 8: a callback CONSUMES NO INPUT (§11.4:652), one
# mutation per lane. Their records are mirror images -- each mutant advances its
# own lane's position and the other's stands still -- so the pins are the
# unbound-optional tuple with the two lanes' values in opposite order.
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.callback.chez.source
  LABEL "runtime: a callback invocation consumes a byte"
  # Re-anchored in Slice ③: the span-end arm's `goto` is textually identical to
  # this one -- both are zero-width, which is the point -- so the FIND now
  # carries the invocation above it, which names the kind it belongs to.
  FIND [[                        (caddr parts) (cadr parts) (list-ref parts 4))))
               (case (car o)
                 ((goto)
                  (parser-set-current! parser (cadr o))
                  (loop pos pk))]]
  REPLACE [[                        (caddr parts) (cadr parts) (list-ref parts 4))))
               (case (car o)
                 ((goto)
                  (parser-set-current! parser (cadr o))
                  (loop (+ pos 1) pk))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the lanes agree -- expected .stopped 1 1 1 #f stopped., got .stopped 2 2 1")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.callback.chez.source
  LABEL "compile: the emitted callback jump consumes a byte"
  # Re-anchored in Slice ③, for the same reason its interpreted sibling above
  # was: the emitted span-end arm renders the identical `goto` line. The FIND
  # carries the invocation line above it, which is this arm's alone.
  FIND [[            (let ((d (caddr tg))) (if d (num d) "#f")) ")))\n"
            "         (case (car o)\n"
            "           ((goto) (loop pos (cadr o) off pk))\n"]]
  REPLACE [[            (let ((d (caddr tg))) (if d (num d) "#f")) ")))\n"
            "         (case (car o)\n"
            "           ((goto) (loop (+ pos 1) (cadr o) off pk))\n"]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the lanes agree -- expected .stopped 2 2 1 #f stopped., got .stopped 1 1 1")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Milestone 5 Slice ③: the span kinds execute (pass 54) -------------------
#
# The differential lane is the SPEC for the same reason Slice ②'s was: no other
# program in the tree loads a generated library containing a span state. What is
# different here is what the lane can SEE. A callback outcome shows up in a
# parser result; a span fragment does not -- two lanes can agree on every tuple
# in §22.4 while handing the application different bytes. So the pins below are
# anchored on the FRAGMENT TRACE, and three of them (the emitted span start, the
# emitted span end, and the emitted completion substep) would otherwise resolve
# to the same "the lanes agree" line. The fixture asserts the GENERATED lane's
# trace and active span as values for exactly that reason, and each pin names
# the wrong value rather than the disagreement.
#
# Six mutations edit code SHARED by both lanes -- the fragment step's empty
# check, the boundary flush, the feed's mark re-anchor, reset's span clear -- so
# both lanes move together and a cross-lane comparison cannot see them at all.
# Those are pinned on recorded VALUES, never on agreement.
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/differential-span-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.span.chez.source
  LABEL "runtime: the flush delivers an empty fragment instead of suppressing"
  # §14:834 (amended, decision 0042). `>= from to` now lives in
  # span-fragment-suppress-empty, which the FLUSH alone reaches (the span ends
  # deliver-if-never through the public step). Inverting it to `> from to` makes
  # an empty flush -- one that accumulated nothing this slice -- deliver a
  # zero-length fragment. Witnessed by the criterion-3 case's MID trace, `()` in
  # the baseline (the flush found nothing and delivered nothing); the FINAL trace
  # is unchanged, because the span end then suppresses the now-set flag, so only
  # the mid trace separates them.
  FIND [[      (if (or (>= from to) (unbound-callback? f))]]
  REPLACE [[      (if (or (> from to) (unbound-callback? f))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the flush delivered nothing -- expected .., got .#vu8..."
)

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.span.chez.source
  LABEL "runtime: an empty span is suppressed instead of delivered once"
  # decision 0042 item 1: the public span-end step delivers an empty fragment
  # exactly when `from == to` and the span has delivered nothing. Weakening that
  # guard to `< from to` makes the arm unreachable (arm 1 already took `< from
  # to`), so an empty span delivers nothing -- the pre-0042 behaviour. Witnessed
  # by the AZ empty span, which must now deliver one empty fragment then complete.
  FIND [[            ((and (= from to) (not (parser-span-delivered? parser)))]]
  REPLACE [[            ((and (< from to) (not (parser-span-delivered? parser)))]]
  EXPECT_STATUS 1
  # Anchored on the AZ case NAME, not the bare check label: the same "one empty
  # fragment, then the completion" check fires for the EOF-chain span and the
  # carried-EOF cases too (this mutant suppresses every empty delivery), so the
  # case name is what resolves the pin to AZ alone.
  EXPECT_OUTPUT_MATCHES "AZ opens and closes having delivered nothing: one empty fragment, then the completion -- expected .#vu8.. complete., got .complete."
)

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.span.chez.source
  LABEL "runtime: parser-finish! does not re-anchor the span mark to 0"
  # decision 0042 item 4: parser-finish! re-anchors an active span's mark to 0
  # before the EOF chain runs, so a span carried from a feed and closed empty at
  # EOF sees from==to and delivers its one empty fragment uniformly. Dropping the
  # re-anchor leaves the carried mark (the opening feed's start), so from>to and
  # the span end suppresses -- announcing the empty span only when the last feed
  # happened to start at 0. Witnessed by the nonzero-start carried-empty case,
  # whose whole point is slicing-independence.
  FIND [[       (when (parser-active-span parser)
         (parser-set-span-mark! parser 0))
       (let ((completed #f))]]
  REPLACE [[       (let ((completed #f))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "slicing-independent: one empty fragment, then the completion -- expected .#vu8.. complete., got .complete."
)

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.span.chez.source
  LABEL "runtime: a span-end fragment does not mark the span delivered"
  # decision 0042 item 1: span-fragment-deliver! sets the delivered flag, so a
  # span split across feeds whose FINAL fragment is empty suppresses it (the flush
  # delivered the bytes and set the flag). Dropping the set leaves the flag clear,
  # so the empty final fragment delivers spuriously. Witnessed by the criterion-2
  # split: `bc` flushed, then an empty tail that must NOT appear.
  FIND [[    (parser-set-span-delivered?! parser #t)]]
  REPLACE [[    #t]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "no empty tail -- expected .#vu8.98 99. complete., got .#vu8.98 99. #vu8.. complete."
)

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.span.chez.source
  LABEL "runtime: the feed-boundary flush never runs"
  # §14:833-834 and §19.3:1024. The status guard is what selects the boundary:
  # `error` is forbidden a final fragment (§14:839), `stopped`/`finished` with a
  # span active are verifier-rejected, and `paused` cannot produce a nonempty
  # one. Pointing it at `paused` disables the flush without deleting it.
  FIND [[    (if (and (eq? (parser-result-status r) 'need-input)]]
  REPLACE [[    (if (and (eq? (parser-result-status r) 'paused)]]
  EXPECT_STATUS 1
  # Its half of the pair the flush-pause mutation below also names: this mutant
  # delivers NO fragment, and the pin says so rather than resting on the status
  # line the two used to share.
  EXPECT_OUTPUT_MATCHES
    "separates two mutants: delivered, and reported as a pause -- expected ..#vu8.98 99.. .paused 3 3 3 #f paused-feed.., got ... .need-input 3 3 3 #f ready.."
)

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.span.chez.source
  LABEL "runtime: an open span's mark is not re-anchored at the next feed"
  # *** THE ONE PLACE §14:833's RE-ANCHOR LIVES, and since the mark advance was
  # measured subsumed and deleted, the only place a mark ever moves after a span
  # opens. *** With it gone the mark keeps the coordinates it had in the slice
  # the span STARTED in, so the second feed's span end slices `[1,2)` of the new
  # bytevector -- one wrong byte, not none, which is why the pin names the
  # sequence rather than a count.
  #
  # Measured, not derived: the sub-slice case below does NOT fail under this
  # mutant, because there the stale mark happens to land on the right byte. Two
  # mutations, two cases, and neither case covers both.
  FIND [[       (when (parser-active-span parser)
         (parser-set-span-mark! parser start))
       (let ((completed #f))]]
  REPLACE [[       (let ((completed #f))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "bc then de, never bc twice -- expected .#vu8.98 99. #vu8.100 101. complete., got .#vu8.98 99. #vu8.101. complete."
)

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.span.chez.source
  LABEL "runtime: the mark is re-anchored to 0 rather than to the slice start"
  # §14:833 makes the mark a SLICE offset and §14:833 anchors it at "the next
  # feed's `start`". Every other case in the lane feeds a whole bytevector,
  # where `start` and `0` are the same program -- so this mutant is invisible to
  # all of them, and the sub-slice case exists only to separate the two.
  FIND [[         (parser-set-span-mark! parser start))]]
  REPLACE [[         (parser-set-span-mark! parser 0))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the padding is in neither fragment -- expected .#vu8.98 99. #vu8.100. complete., got .#vu8.98 99. #vu8.7 7 100. complete."
)

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.span.chez.source
  LABEL "runtime: a full reset leaves the span state behind"
  # §12.5:739 lists span state FIRST among what a reset clears, and F2 found the
  # comment above `parser-reset!` still saying it "does not exist". Both lanes
  # move, so the pin names the accessor's value in each.
  FIND [[    (byte-machine-span-close/v1 parser)
    (vector-set! parser 8]]
  REPLACE [[    (vector-set! parser 8]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "inactive after -- expected .#f #f., got .payload payload."
)

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.span.chez.source
  LABEL "interpret loop: the span is not made inactive before the completion callback"
  # §14:841: "Before invoking the completion callback, execution makes the span
  # inactive." One lane only, so the cross-lane comparison catches it too -- but
  # the pin is on the VALUE, because the emitted mutation two below shares that
  # line and only the value separates them.
  FIND [[             (let ((parts (op 'span-completion-parts node)))
               (byte-machine-span-close/v1 parser)]]
  REPLACE [[             (let ((parts (op 'span-completion-parts node)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "and the span is inactive afterwards -- expected #f, got payload"
)

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.span.chez.source
  LABEL "interpret loop: a span start records the mark at 0 instead of the cursor"
  # §14:830: "Starting a span records the current cursor." The interpreted arm's
  # `pos` against the finish arm's literal 0 -- which is correct THERE, since the
  # finish path has no cursor, and is what makes this FIND one site.
  FIND [[               (byte-machine-span-open/v1 parser (car parts) pos (cadr parts))]]
  REPLACE [[               (byte-machine-span-open/v1 parser (car parts) 0 (cadr parts))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "one fragment then one completion -- expected .#vu8.98 99 100. complete., got .#vu8.65 98 99 100. complete."
)

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.span.chez.source
  LABEL "runtime: a pause during the flush is reported as need-input"
  # §14:837 makes the flush's pause the FEED's pause: the fragment is committed
  # and the caller must resume. Reported as `need-input` the parser stays ready,
  # so the caller's `parser-resume!` raises a lifecycle violation three steps
  # later -- which the harness shows as a bare raise.
  #
  # *** RE-PINNED AT THE FINAL REVIEW: the STATUS alone was printed BYTE FOR BYTE
  # by "the feed-boundary flush never runs" above. *** Two mutants, one output
  # line, and the pin attributed the catch to neither. They part on the FRAGMENT
  # -- a flush that ran and mis-reported its status still delivered `bc`, one
  # that never ran delivered nothing -- so the lane grew a case asserting the
  # PAIR, and each mutation now names its own half of it. Measured both ways.
  FIND [[            ((pause) (make-parser-result 'paused (parser-result-next r)]]
  REPLACE [[            ((pause) (make-parser-result 'need-input (parser-result-next r)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "separates two mutants: delivered, and reported as a pause -- expected ..#vu8.98 99.. .paused 3 3 3 #f paused-feed.., got ..#vu8.98 99.. .need-input 3 3 3 #f ready.."
)

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.span.chez.source
  LABEL "compile: the emitted span start records the mark at 0"
  # The generated half of the interpreted mutation above. Both are needed: each
  # edits one lane, and a lane agreeing with a mutated sibling is the defect
  # neither alone can show.
  FIND [[            (symbol->string (car d)) ") pos " (num (cadr d)) ")\n"]]
  REPLACE [[            (symbol->string (car d)) ") 0 " (num (cadr d)) ")\n"]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the generated lane's own fragment -- expected .#vu8.98 99 100. complete., got .#vu8.65 98 99 100. complete."
)

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.span.chez.source
  LABEL "compile: the emitted span end slices to the end of the feed"
  # §14:831 emits `[mark,cursor)`, and `cursor` is `pos` -- not `end`. The
  # difference is exactly the delimiter the span end reexecutes onto, so this
  # mutant produces a fragment one byte too long and nothing else moves.
  FIND [[" off (vector-ref cbv " (num (cadr d)) ") bv pos " cid ")))\n"]]
  REPLACE [[" off (vector-ref cbv " (num (cadr d)) ") bv end " cid ")))\n"]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the generated lane's own fragment -- expected .#vu8.98 99 100. complete., got .#vu8.98 99 100 90. complete."
)

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.span.chez.source
  LABEL "compile: the emitted completion substep does not close the span"
  # §14:841's generated half. TWO shapes are rendered here -- with and without a
  # declared completion callback (§10.4:516) -- and this is the one that calls;
  # its sibling below is the one that does not, and each needs its own witness
  # because a single machine renders only one of them.
  FIND [[                "       (begin (byte-machine-span-close/v1 psr)\n"
                "         (let ((o (byte-machine-callback-step/v1 psr " id]]
  REPLACE [[                "       (begin #t\n"
                "         (let ((o (byte-machine-callback-step/v1 psr " id]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "and its span is inactive too -- expected #f, got payload"
)

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.span.chez.source
  LABEL "compile: the emitted completion substep for a span with no callback does not close"
  # The OTHER rendered shape, and the reason the lane builds a second machine at
  # all: a span declaring no completion callback still needs the substep, whose
  # only job is then to make the span inactive. Nothing else in the tree renders
  # this arm, so without the second machine it would ship unexecuted.
  FIND [[                "       (begin (byte-machine-span-close/v1 psr)\n"
                "              " (zero-width-jump (normal-field-targets s)) "))\n")]]
  REPLACE [[                "       (begin #t\n"
                "              " (zero-width-jump (normal-field-targets s)) "))\n")]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "#vu8.98 99 100.. payload., got "
)

# --- Task 6's oracle: §25:1590's universal, made a table ---------------------
#
# "Every invalid span topology is rejected" is a universal over a set the parent
# plan never writes down, so the lane writes it down: eleven rows, each with the
# verdict DERIVED from §14:843 or §16.2:899 before it was run, and the count as
# the sentinel. These four break one arm of `span-node-diagnostics` each, and
# every one of them turns a rejected row green rather than turning a green row
# red -- which is the direction a census can otherwise miss entirely.

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.differential.span.chez.source
  LABEL "verify: a span re-entering itself is not rejected"
  FIND [[               ((and (pair? state) (eq? (cadr state) s))
                (list (make-diagnostic/path 'invalid-span-state (node-name n)
                                            "span re-entry: this span is already open"
                                            path)))]]
  REPLACE [[               ((and (pair? state) (eq? (cadr state) s)) '())]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "reentry want .invalid-span-state. got .."
)

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.differential.span.chez.source
  LABEL "verify: ending the wrong span is not rejected"
  FIND [[               ((pair? state)
                (list (make-diagnostic/path 'invalid-span-state (node-name n)
                                            "wrong end: a different span is open"
                                            path)))]]
  REPLACE [[               ((pair? state) '())]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "wrong-end want .invalid-span-state. got .."
)

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.differential.span.chez.source
  LABEL "verify: a finish reachable with a span active is admitted"
  # Decision 0023 item 5 kept `finish` distinguished from `error` precisely so
  # this arm could name one and not the other, and the table's `error-inside`
  # row is what proves the distinction still costs something: with `finish`
  # dropped the row below goes green while `error-inside` stays green, so only
  # the FINISH row moves.
  FIND [[      ((and (pair? state) (or (stop-node? n) (finish-node? n)))]]
  REPLACE [[      ((and (pair? state) (stop-node? n))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "finish-inside want .span-active-at-exit. got .."
)

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.differential.span.chez.source
  LABEL "verify: a callback invocation inside a span is admitted"
  # §13:826 names "an explicit pause node or event/decision callback
  # invocation" as one rule, and this arm is where the two halves are one `or`.
  # Replacing the callback half with a kind that can never carry the state --
  # a span END sets the state to `none` on the way out -- keeps the arm shaped
  # like itself and makes the callback row green.
  FIND [[      ((and (pair? state) (or (pause-node? n) (callback-node? n)))]]
  REPLACE [[      ((and (pair? state) (or (pause-node? n) (span-end-node? n)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "callback-inside want .span-active-at-pause. got .."
)

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.span.chez.source
  LABEL "runtime: reset refuses a POISONED parser instead of resetting it"
  # Slice ④'s new reset leg. `§12.2:698` makes reset the ONE operation a poisoned
  # parser may run -- every other cell in that row raises -- so this mutant is
  # the plausible wrong reading of the row, not a strawman. Nothing else in the
  # tree drives reset on a poisoned parser: the callback lane poisons a
  # SPAN-LESS machine and never resets it, so this pin has no sibling.
  #
  # The recorded signature is a RAISE rather than a value mismatch, and the pin
  # names the case, which is what keeps it from being a bare nonzero exit.
  FIND [[    (when (eq? (parser-lifecycle parser) 'busy)
      (byte-machine-contract-violation 'parser-reset! 'reentrancy]]
  REPLACE [[    (when (memq (parser-lifecycle parser) '(busy poisoned))
      (byte-machine-contract-violation 'parser-reset! 'reentrancy]]
  EXPECT_STATUS 1
  # The FAIL grammar is `FAIL <group>.<case>: <what>`, so the case name is
  # followed by `: ` and the GROUP name is followed by a bare `.`. An earlier
  # version of this pin put `.*:` between them and the suite rejected it as
  # "caught by coincidence" -- the greedy wildcard swallowed the colons inside
  # the group's own section references. Anchor on the case, which is unique.
  EXPECT_OUTPUT_MATCHES "reset is accepted, clears the span, and the parser is reusable: case raised"
)

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.span.chez.source
  LABEL "runtime: the FINISH path's span completion never closes the span"
  # The interpreted finish path's own `byte-machine-span-close/v1`, which no
  # mutation reached before: the two existing pins on that call are reset's
  # (four-space indent) and the FEED loop's (fifteen). This is the thirteen-space
  # one, and Slice ④'s EOF group is the first fixture whose span is closed by a
  # node on the EOF chain after a feed opened it.
  FIND [[          ((span-completion)
           (let ((parts (op 'span-completion-parts node)))
             (byte-machine-span-close/v1 parser)]]
  REPLACE [[          ((span-completion)
           (let ((parts (op 'span-completion-parts node)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the fragment comes from the feed and the completion from finish: the lanes agree -- expected #t, got #f"
)

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")



# --- Milestone 5 Slice ④: input retention (§25:1591) -------------------------
#
# Follows Slice ③'s span pass (the fifty-fourth) and is the FIFTY-FIFTH.
#
# The lane Slice ③'s liveness probe was brought forward FOR, and the first pass
# in this file whose SPEC reads something no result and no trace can show: what
# is still REACHABLE from a live parser after `parser-feed!` returns.
#
# All three mutations below are halves of design §9's argument.
# The first makes the runtime retain and layer 1 must see it. The other two make
# an EXEMPT carrier stop carrying, and layer 3 must see that too -- because an
# oracle asserting "nothing is reachable" would pass a runtime that quietly
# dropped the application's own context, and `§13:799` says those three carriers
# are the application's to keep.
#
# Layer 2, the negative control, carries no mutant and does not need one: it is a
# FIXTURE that retains on purpose, and `retention-tests.sps` is not a mutation
# target. (Not "no fixture in `test/common` is" -- `property-differential-tests.sps`
# is one, above. The narrower claim is the true one.) Its control is the
# two-directional assertion: layer 1 says "gone" and layer 2 says "retained"
# about the same FIXTURE SHAPE -- not, as an earlier version of this comment
# said, about the same probe; they are two `retained?` calls over two fixtures
# and two bytevectors. An instrument answering a constant still fails one of
# them, which is the conclusion, but the reason is the shape and not the object.
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/retention-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.retention.chez.source
  LABEL "runtime: the fed bytevector is stored in the parser and survives the return"
  # `§25:1591` itself. The stored-error slot is the one that makes this a
  # UNIQUE witness rather than a duplicate of some other pass: it is not read on
  # a successful stop, `parser-stored-error` is not exported, and no other lane
  # in the tree looks at what a parser still reaches. Every other suite stays
  # green under this mutant.
  FIND [[(parser-set-lifecycle! parser 'busy)
       (when (parser-active-span parser)]]
  REPLACE [[(parser-set-lifecycle! parser 'busy)
       (parser-set-stored-error! parser bv)
       (when (parser-active-span parser)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "gone in both lanes -- expected ..interpreted . #f. .generated . #f.., got ..interpreted . #t."
)

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.retention.chez.source
  LABEL "runtime: a callback failure's detail is dropped instead of carried"
  # Layer 3's second carrier, and the arm design §9 says an oracle gets wrong:
  # "an oracle that excludes only the user-context slot will report a false
  # violation the first time a fixture callback fails with a detail holding its
  # own slice." With the detail dropped the parser stops retaining and the arm
  # reads "gone" -- which is the direction that looks like GOOD news.
  FIND [[    (vector callback-failure-tag code detail)]]
  REPLACE [[    (vector callback-failure-tag code #f)]]
  EXPECT_STATUS 1
  # *** THE CASE NAME IS PART OF THE PIN. *** "retained, and permitted" is the
  # `<what>` of TWO checks in this lane -- the user-context arm and this one --
  # with byte-identical expected values, so a pin starting at the `<what>` also
  # matches the OTHER arm's failure, including mutation 3's. The FAIL grammar is
  # `FAIL <group>.<case>: <what> -- <detail>`, and this pass's own standard is
  # that a sound pin resolves to exactly ONE (case, check) pair.
  EXPECT_OUTPUT_MATCHES "a slot walk misses: retained, and permitted -- expected ..interpreted . #t. .generated . #t.., got ..interpreted . #f. .generated . #f."
)

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.retention.chez.source
  LABEL "runtime: the interpreted parser drops the user context"
  # Layer 3's first carrier, and the mutant is deliberately ONE-LANE: only the
  # `op` arm is edited, so the recorded `got` reads
  # `((interpreted . #f) (generated . #t))`. That asymmetry is the assertion --
  # the two lanes reach `user-context` by different routes (`make-parser` builds
  # both vectors here, but only this arm's literal moves), and a pin that
  # mutated both would not show it.
  FIND [[                 user-context #f #f 0 #f #f)))]]
  REPLACE [[                 'not-the-input #f #f 0 #f #f)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "user context may retain it, and does: retained, and permitted -- expected ..interpreted . #t. .generated . #t.., got ..interpreted . #f. .generated . #t."
)

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Milestone 6 Slice ① task 3: the counted differential (pass 56) --------------
#
# Both lanes over the counted machine, every check labelled by LANE, so a pin
# names which lane went wrong and is caught by the EXPECTED VALUE's record, never
# by the lanes' disagreement (design §6 oracle 3 as the slice plan's F13 corrects
# it: with one FILE per mutation and a runtime arm that serves the interpreted
# lane alone, no mutant of this slice can make both lanes agree on a wrong value).
# The emitter's min, subtraction and completion-order decisions live here rather
# than in unit.compile, because only an executing lane with a surplus or exact
# body can see them; the emitter's exhaustion-first twin of the runtime pin in
# the position-kind pass lives here because that pass's labels carry no lane.
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/differential-counted-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.counted.chez.source
  LABEL "compile: the reached declaration walk ignores counted consume"
  # The machine whose ONLY default-EOF consumer is the counted consume: the
  # declaration leaves the errs table and render-machine raises on a machine the
  # verifier accepted -- the Milestone 4 Slice ③ defect, one kind later.
  # Re-anchored by Milestone 11 Slice ①: the credit list gained `keyword-table`
  # on a continuation line. Dropping counted-consume (keeping keyword-table) is
  # still the edit and the witness is unchanged.
  FIND [[                                                      '(dispatch accumulate counted-consume
                                                        keyword-table))]]
  REPLACE [[                                                      '(dispatch accumulate
                                                        keyword-table))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the only-consumer machine renders, loads and runs: case raised")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.counted.chez.source
  LABEL "compile: the emitted counted arm commits (- end pos) instead of the min"
  FIND [[            "                (let ((n (min v (- end pos))))\n"]]
  REPLACE [[            "                (let ((n (- end pos)))\n"]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "generated: surplus into a rejection -- expected ..error 5 5 .machine unexpected-byte .unexpected byte. reject 5 byte. error reject 0.., got ..need-input")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.counted.chez.source
  LABEL "compile: the emitted counted arm never subtracts"
  FIND [[            "                  (vector-set! fieldv " slot " (- v n))\n"]]
  REPLACE [[            "                  (vector-set! fieldv " slot " v)\n"]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "generated: exact body -- expected ..need-input 5 5 #f ready comma 0.., got ..need-input 5 5 #f ready comma 3..")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.counted.chez.source
  LABEL "compile: the emitted counted arm continues only when input remains"
  # The count-completion-wins mutant (decision 0030 item 2) in the generated
  # lane: the exact body parks on `body` with a zero count instead of continuing
  # to the delimiter dispatch in the same feed.
  FIND [[            "                  (if (= n v)\n"]]
  REPLACE [[            "                  (if (and (= n v) (< (+ pos n) end))\n"]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "generated: exact body -- expected ..need-input 5 5 #f ready comma 0.., got ..need-input 5 5 #f ready body 0..")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.counted.chez.source
  LABEL "compile: the emitted counted arm tests exhaustion before the zero count"
  # The runtime arm's twin is pinned in the position-kind pass; this one needs a
  # lane-labelled witness, and the feed-order witness is exactly that.
  FIND [[            "         (cond ((= v 0) " (zero-width-jump next-id) ")\n"]]
  REPLACE [[            "         (cond ((and (= v 0) (< pos end)) " (zero-width-jump next-id) ")\n"]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "generated: parked on the delimiter after 0: -- expected comma, got body")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.counted.chez.source
  LABEL "runtime: the counted arm re-asks the op after a partial commit"
  # Loops back through the node instead of parking: the op is asked again over
  # the exhausted slice, answers (0 . #f), and the parser parks with the same
  # result -- every tuple lane agrees, and only the counting witness sees the
  # second message. §25:1607 in the interpreted lane.
  FIND [[                          (make-parser-result 'need-input (+ pos n) (- (+ pos n) start)
                                              (parser-offset parser) #f))))))]]
  REPLACE [[                          (loop (+ pos n) 'boundary))))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "one count-step per feed -- expected 1, got 2")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.counted.chez.source
  LABEL "runtime: the counted finish arm asks the EOF route before the zero count"
  # Decision 0030 item 1 at finish: the entry-zero machine's fresh parser must
  # transition to `next` and report the empty-body error, not the default EOF.
  FIND [[             (if (cdr r)
                 (begin (parser-set-current! parser (cdr r)) (loop (cdr r) pk))
                 (take-eof-route! node loop))))]]
  REPLACE [[             (take-eof-route! node loop)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "interpreter: the finish reports the empty-body error -- expected .empty body rejected., got .unexpected end of input.")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Milestone 6 Slice ① task 3: the counted determinism lane (pass 57) ----------
#
# A pass of its own because the verify command is a different program, and its
# ONE mutation is one no behavioural lane can catch: the emitted position kind
# spelled with a quote mark instead of `(quote …)`. The reader turns both into
# the same datum, so the structural walk in compile-tests cannot see it either;
# the emitted BYTES change, and the committed golden is the only thing that
# looks at those -- the accumulate lane's argument, made falsifiable once more.
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/determinism-counted-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.determinism.counted.chez.source
  LABEL "compile: the emitted counted arm spells its position kind with a quote mark"
  FIND [[            "                      (loop (+ pos n) " (num next-id) " (+ off n) (quote boundary))\n"]]
  REPLACE [[            "                      (loop (+ pos n) " (num next-id) " (+ off n) 'boundary)\n"]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the emitted bytes equal the committed golden: golden")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Milestone 6 Slice ② task 3: the counted-span differential (pass 58) ---------
#
# No mechanism was added by the slice, so the only decision this lane witnesses
# that no other lane does is decision 0030 item 2's PLACEMENT: the completion
# event lands in the feed that delivered the last body byte. The two mutants that
# move it are the count-completion-order mutants Slice ① already declared under
# unit.interpret and differential.counted on other records; here each is pinned
# on the placement record per lane, the value §7's oracle 3 exists for -- a
# symmetric wrong reading puts the completion in the `,` feed in BOTH lanes and
# agrees with itself, so neither pin could ever rest on lane disagreement.
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/differential-counted-span-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.differential.counted-span.chez.source
  LABEL "interpret: count-step continues only when input remains -- the completion lands in the delimiter's feed"
  FIND [[                (cons k (if (= k v) (counted-consume-node-next n) #f))))))]]
  REPLACE [[                (cons k (if (and (= k v) (< (+ pos k) end)) (counted-consume-node-next n) #f))))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "interpreter: byte-at-a-time per-feed events, count and span -- expected .... 3 #f. ... 3 sp. ...data 1.. 2 sp. ...data 1.. 1 sp. ...data 1. complete. 0 #f. ... 0 #f.., got .... 3 #f. ... 3 sp. ...data 1.. 2 sp. ...data 1.. 1 sp. ...data 1.. 0 sp. ..complete. 0 #f..")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.counted-span.chez.source
  LABEL "compile: the emitted counted arm continues only when input remains -- the completion lands in the delimiter's feed"
  FIND [[            "                  (if (= n v)\n"]]
  REPLACE [[            "                  (if (and (= n v) (< (+ pos n) end))\n"]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "generated: byte-at-a-time per-feed events, count and span -- expected .... 3 #f. ... 3 sp. ...data 1.. 2 sp. ...data 1.. 1 sp. ...data 1. complete. 0 #f. ... 0 #f.., got .... 3 #f. ... 3 sp. ...data 1.. 2 sp. ...data 1.. 1 sp. ...data 1.. 0 sp. ..complete. 0 #f..")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Milestone 7 Slice ③ Pass 59: the printer, the fixture saver, the minimizer -
# The FIFTY-NINTH pass, and the first Milestone 7 adds (⓪/①/② re-anchored or
# widened existing passes). It runs property-fixture-tests.sps -- the deliberate-
# failure probe (§4.7). Three mutations are CAUGHT, each by a distinct check whose
# failure signature is asserted (not a bare nonzero exit, the family the plan warns
# is least visible by exit status): the printer emitting another kind's constructor,
# the saver writing a non-reproducing fixture, and the minimizer accepting a
# reduction that no longer disagrees. The fourth, the 64-emission bound, is a
# declared SURVIVOR (F10): the survivor is named only after the attempt, and the
# attempt measured the probe minimizing in FOUR emissions, so no probe here reaches
# the bound -- witnessing it would need a machine with >64 verifying, still-
# disagreeing reductions, which this slice does not construct.
#
# --- Slice ③ sweep (Task 9, measured 2026-09-11 over the three caught mutants). The
# per-pin match-count matrix is a clean diagonal: on the green tree all three regexes
# match ZERO records; each mutant matches its OWN pin's regex exactly ONCE and the
# other two ZERO times (pin1 R1=1/R2=0/R3=0, pin2 0/1/0, pin3 0/0/1). The printer pin
# matches the printer group's lone "case raised" render-rejection; the saver pin the
# RAW reruns-disagree check (distinct from the MINIMIZED one's label); the minimizer
# pin the in-memory minimized-still-disagrees check. Label audit (Task 9 Step 3): none
# of 230 shipped regexes contains or is contained by these three, and none matches any
# fixture check label; Step 4: no regex uses `.*` or ends at `got`. The whole lane
# passed 59/561 with all four behaving (three caught, the bound survivor surviving),
# so no shipped pin's FIND was broken by this slice's driver edits (Task 9 Step 1).
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/property-fixture-tests.sps")

# The printer's arm for one KIND emitting another kind's constructor. The round
# trip catches it: a stop reprinted as a finish makes a byte edge target a finish
# terminal, which the verifier REJECTS, so render-machine of the reprinted machine
# raises inside the round-trip case. (§8 says "by fingerprint"; a KIND swap is
# caught one step earlier, at verify -- the reprinted machine does not verify, a
# stronger catch than a fingerprint mismatch. Task 12 corrects §8's mechanism.)
# COUPLING (measured, seed 20260823): this render-rejection signature holds because
# the first accepted machine carrying a stop node reaches that stop over a BYTE edge,
# so reprinting it as a finish trips `non-eof-into-finish`. Were the first such stop
# EOF-only-reachable, the reprint would VERIFY and the round trip would fail instead
# by byte-identity ("... machine <i> ... expected a true value"). The signature is
# thus tied to the committed seed and generator, as the differential pins' machine
# indices are; a generator change that flips it makes this pin read UNCAUGHT and
# reddens the lane, which is the re-anchor signal (Slice ③ Task 9, CMake review).
byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-print.sls
  SPEC byte-machine.property.fixture.chez.source
  LABEL "print-stop emits another kind's constructor (make-finish-node)"
  FIND [[    (list 'make-stop-node (lit (stop-node-name n)) (lit (stop-node-source-label n))))]]
  REPLACE [[    (list 'make-finish-node (lit (stop-node-name n)) (lit (stop-node-source-label n))))]]
  EXPECT_OUTPUT_MATCHES "round trip byte-identical over the seed set: case raised -- Exception in render-machine: cannot render an unverified machine")

# The saver writing the base machine instead of the corrupted trial: the emitted
# fixture binds `gen` to the honest interpreter (`ref`) rather than the lying
# wrapper, so the reloaded fixture's lanes AGREE and it reproduces nothing. Caught
# by the in-process re-run of the saved fixture's own gen (reruns-disagree?).
byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/property-driver.sls
  SPEC byte-machine.property.fixture.chez.source
  LABEL "the saver writes an honest gen (base machine), so the fixture no longer reproduces"
  FIND [[             (list 'define 'gen gen-expr)]]
  REPLACE [[             (list 'define 'gen 'ref)]]
  EXPECT_OUTPUT_MATCHES "the raw fixture's saved trial still disagrees when re-read and re-run -- expected a true value")

# The minimizer accepting a reduction that no longer disagrees: the failure oracle
# is short-circuited to "always failing", so the minimizer keeps shrinking past the
# disagreement and the minimized trial agrees. Caught by the minimized-still-
# disagrees check.
byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/property-driver.sls
  SPEC byte-machine.property.fixture.chez.source
  LABEL "the minimizer accepts a reduction that no longer disagrees"
  FIND [[                    (not (eq? (fail-oracle m s i sch) 'none)))))]]
  REPLACE [[                    #t)))]]
  EXPECT_OUTPUT_MATCHES "the minimized trial still disagrees -- expected a true value")

# The 64-emission bound (F10). SURVIVOR, declared with the measured attempt: the
# probe minimizes in FOUR emissions (Task 5 Step 8), so removing the loop's bound
# guard changes nothing here -- the fixpoint stops it first. Pinned only after the
# attempt, never before it; a probe that reached the bound would witness this, and
# constructing one (>64 verifying, still-disagreeing reductions) is not this slice.
byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/property-driver.sls
  SPEC byte-machine.property.fixture.chez.source
  LABEL "the minimizer's emission bound is removed"
  FIND [[             ((or (null? cs) (>= emissions bound))]]
  REPLACE [[             ((or (null? cs) #f)]]
  EXPECT_SURVIVES "the probe minimizes in 4 emissions (< the 64 bound), so the fixpoint stops the loop before the bound is ever consulted; no probe in this slice reaches it (F10)")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Milestone 7 Slice ④ Pass 60: the corruption catalogue and the oracle -------
# The SIXTIETH pass. It runs property-rejections-tests.sps -- the catalogue and the
# independent oracle (§4.5/§4.6). Twenty-five mutations: the catalogue's positive
# (a no-op corrupt), negative (a twin that is its corrupt), refusal (a thunk made
# legal) and per-entry-count (an applies? made false) checks; the code sentinel's
# unconstructible term (a declared survivor, see mut4); the matcher-bytes
# prohibition; and each of the nine oracle rows made to never fire (its fire
# counter) and to always fire (its silent counter). Each EXPECT asserts the failure
# signature, never a bare nonzero exit.
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/property-rejections-tests.sps")

# mut1: a non-span entry's corrupt is a no-op -> the positive containment fails.
byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-corrupt.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "a non-span entry's corrupt (dup-node-name) is a no-op"
  FIND [[      (lambda (m) (let ((ns (node-names m))) (rename-to m all-node-ctors ns (car ns))))]]
  REPLACE [[      (lambda (m) m)]]
  EXPECT_OUTPUT_MATCHES "dup-node-name corruptions all contain the expected pairs -- expected a true value")

# mut2: a span-bearing entry's corrupt is a no-op -> the positive containment fails.
byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-corrupt.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "a span-bearing entry's corrupt (span-active-at-pause) is a no-op"
  FIND [[      (lambda (m) (let* ((s (first-node-of m span-start-node?))
                         (nm (span-start-node-name s))
                         (old-next (span-start-node-next s))
                         (d1 (extend (->d m) '(make-machine) 1 (machine-name m) 7
                                     (list 'make-pause-node (q 'zz-inspan-pause) (q old-next) #f))))
                    (build (edit d1 '(make-span-start-node) 1 nm 3 (q 'zz-inspan-pause)))))]]
  REPLACE [[      (lambda (m) m)]]
  EXPECT_OUTPUT_MATCHES "span-active-at-pause corruptions all contain the expected pairs -- expected a true value")

# mut3: one entry's twin is replaced by its corrupt -> the twin no longer verifies.
byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-corrupt.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "an entry's twin is its corrupt (dup-node-name)"
  FIND [[      (lambda (m) (let ((ns (node-names m))) (rename-to m all-node-ctors ns (car ns))))
      identity-twin]]
  REPLACE [[      (lambda (m) (let ((ns (node-names m))) (rename-to m all-node-ctors ns (car ns))))
      (lambda (m) (let ((ns (node-names m))) (rename-to m all-node-ctors ns (car ns))))]]
  EXPECT_OUTPUT_MATCHES "dup-node-name twins verify and lack the entry's code -- expected a true value")

# mut4: the code sentinel drops the unconstructible list. DECLARED SURVIVOR
# (Task 9 Step 8 reconciliation): invalid-shape is redundantly the not-a-machine
# entry's expected code, so dropping the unconstructible {invalid-shape} leaves the
# union unchanged. Every census code has an entry, so no code is unconstructible-
# only; the unconstructible list is a documented belt-and-braces, not a load-bearing
# sentinel term. The plan's Step 1 predicted this caught "naming invalid-shape"; the
# measurement is that it is not catchable, recorded here.
byte_machine_mutation(
  FILE test/common/property-rejections-tests.sps
  SPEC byte-machine.property.rejections.chez.source
  LABEL "the code sentinel drops the unconstructible list"
  FIND [[               (sentinel (uniq (append entry-codes unconstructible-codes)))]]
  REPLACE [[               (sentinel (uniq entry-codes))]]
  EXPECT_SURVIVES "invalid-shape is redundantly the not-a-machine entry's expected code, so the union is unchanged when the unconstructible list is dropped; every census code has an entry, so no code is unconstructible-only and the list is documentary rather than load-bearing")

# mut5: one refusal thunk is made legal -> F5 row 2 sees no raise.
byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-corrupt.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "a refusal thunk is made legal (make-edge with a valid mode)"
  FIND [[       (lambda () (eval '(make-edge 'x 'not-a-mode) eval-env))]]
  REPLACE [[       (lambda () (eval '(make-edge 'x 'advance) eval-env))]]
  EXPECT_OUTPUT_MATCHES "edge-mode-outside-closed-set raises a contract violation -- expected a true value")

# mut6: an entry's applies? is constantly false -> its per-entry count reads 0.
byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-corrupt.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "an entry's applies? is constantly false (missing-callback-declaration)"
  FIND [[      (lambda (m) (first-node-of m callback-node?))]]
  REPLACE [[      (lambda (m) #f)]]
  EXPECT_OUTPUT_MATCHES "missing-callback-declaration applied >= 1 -- expected a true value")

# mut7: the oracle's :893 row reads matcher-bytes -> the structural census catches it.
byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/verify-oracle.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "the oracle's :893 byte-set arm reads matcher-bytes"
  FIND [[          ((byte-set-matcher? mt) (byte-set-matcher-bytes mt))]]
  REPLACE [[          ((byte-set-matcher? mt) (matcher-bytes mt))]]
  EXPECT_OUTPUT_MATCHES "the symbol matcher-bytes does not occur in the oracle -- expected 0, got 1")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/verify-oracle.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "oracle rule :885-duplicates never fires (returns empty)"
  FIND [[(define (rule-duplicates m)
    (append
     (map (lambda (nm) (cons 'duplicate-name nm)) (dups (node-set m)))
     (map (lambda (nm) (cons 'duplicate-error-declaration nm))
          (dups (map error-declaration-name (machine-errors m))))
     (map (lambda (nm) (cons 'duplicate-callback-declaration nm))
          (dups (map callback-declaration-name (machine-callbacks m))))
     (map (lambda (nm) (cons 'duplicate-span-declaration nm))
          (dups (map span-declaration-name (machine-spans m))))))]]
  REPLACE [[(define (rule-duplicates m) '())]]
  EXPECT_OUTPUT_MATCHES ":885-duplicates fired at least once -- expected a true value")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/verify-oracle.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "oracle rule :885-duplicates always fires (every node)"
  FIND [[(define (rule-duplicates m)
    (append
     (map (lambda (nm) (cons 'duplicate-name nm)) (dups (node-set m)))
     (map (lambda (nm) (cons 'duplicate-error-declaration nm))
          (dups (map error-declaration-name (machine-errors m))))
     (map (lambda (nm) (cons 'duplicate-callback-declaration nm))
          (dups (map callback-declaration-name (machine-callbacks m))))
     (map (lambda (nm) (cons 'duplicate-span-declaration nm))
          (dups (map span-declaration-name (machine-spans m))))))]]
  REPLACE [[(define (rule-duplicates m) (map (lambda (zzn) (cons 'duplicate-name (node-name zzn))) (machine-nodes m)))]]
  EXPECT_OUTPUT_MATCHES ":885-duplicates agrees with the verifier -- expected none, got .oracle")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/verify-oracle.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "oracle rule :885-nondup never fires (returns empty)"
  FIND [[(define (rule-885-nondup m)
    (append
     (map (lambda (nm) (cons 'invalid-field-declaration nm))
          (dups (map uint-field-name (machine-fields m))))
     (apply append
       (map (lambda (n)
              (if (callback-node? n)
                  (map (lambda (k) (cons 'duplicate-branch-key (node-name n)))
                       (dups (map car (callback-node-branch-targets n))))
                  '()))
            (machine-nodes m)))))]]
  REPLACE [[(define (rule-885-nondup m) '())]]
  EXPECT_OUTPUT_MATCHES ":885-nondup fired at least once -- expected a true value")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/verify-oracle.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "oracle rule :885-nondup always fires (every node)"
  FIND [[(define (rule-885-nondup m)
    (append
     (map (lambda (nm) (cons 'invalid-field-declaration nm))
          (dups (map uint-field-name (machine-fields m))))
     (apply append
       (map (lambda (n)
              (if (callback-node? n)
                  (map (lambda (k) (cons 'duplicate-branch-key (node-name n)))
                       (dups (map car (callback-node-branch-targets n))))
                  '()))
            (machine-nodes m)))))]]
  REPLACE [[(define (rule-885-nondup m) (map (lambda (zzn) (cons 'invalid-field-declaration (node-name zzn))) (machine-nodes m)))]]
  EXPECT_OUTPUT_MATCHES ":885-nondup agrees with the verifier -- expected none, got .oracle")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/verify-oracle.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "oracle rule :887-905-missing-target never fires (returns empty)"
  FIND [[(define (rule-missing-target m)
    (let* ((nodes (node-set m))
           (refs (uniq (append (if (symbol? (machine-entry m)) (list (machine-entry m)) '())
                               (apply append (map non-eof-targets (machine-nodes m)))))))
      (map (lambda (t) (cons 'missing-target t))
           (filter (lambda (t) (and (symbol? t) (not (memq t nodes)))) refs))))]]
  REPLACE [[(define (rule-missing-target m) '())]]
  EXPECT_OUTPUT_MATCHES ":887-905-missing-target fired at least once -- expected a true value")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/verify-oracle.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "oracle rule :887-905-missing-target always fires (every node)"
  FIND [[(define (rule-missing-target m)
    (let* ((nodes (node-set m))
           (refs (uniq (append (if (symbol? (machine-entry m)) (list (machine-entry m)) '())
                               (apply append (map non-eof-targets (machine-nodes m)))))))
      (map (lambda (t) (cons 'missing-target t))
           (filter (lambda (t) (and (symbol? t) (not (memq t nodes)))) refs))))]]
  REPLACE [[(define (rule-missing-target m) (map (lambda (zzn) (cons 'missing-target (node-name zzn))) (machine-nodes m)))]]
  EXPECT_OUTPUT_MATCHES ":887-905-missing-target agrees with the verifier -- expected none, got .oracle")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/verify-oracle.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "oracle rule :893-overlap never fires (returns empty)"
  FIND [[(define (rule-overlap m)
    (filter-map-nodes m
      (lambda (n)
        (and (byte-dispatch-node? n)
             (any-meet? (map (lambda (c) (matcher-set (byte-case-matcher c)))
                             (byte-dispatch-node-cases n)))
             (cons 'overlapping-cases (byte-dispatch-node-name n))))))]]
  REPLACE [[(define (rule-overlap m) '())]]
  EXPECT_OUTPUT_MATCHES ":893-overlap fired at least once -- expected a true value")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/verify-oracle.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "oracle rule :893-overlap always fires (every node)"
  FIND [[(define (rule-overlap m)
    (filter-map-nodes m
      (lambda (n)
        (and (byte-dispatch-node? n)
             (any-meet? (map (lambda (c) (matcher-set (byte-case-matcher c)))
                             (byte-dispatch-node-cases n)))
             (cons 'overlapping-cases (byte-dispatch-node-name n))))))]]
  REPLACE [[(define (rule-overlap m) (map (lambda (zzn) (cons 'overlapping-cases (node-name zzn))) (machine-nodes m)))]]
  EXPECT_OUTPUT_MATCHES ":893-overlap agrees with the verifier -- expected none, got .oracle")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/verify-oracle.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "oracle rule :894-prefix never fires (returns empty)"
  FIND [[(define (rule-prefix m)
    (filter-map-nodes m
      (lambda (n)
        (and (sequence-dispatch-node? n)
             (let ((alts (map sequence-case-bytes (sequence-dispatch-node-cases n))))
               (and (pairwise-prefix? alts)
                    (cons 'ambiguous-sequence-prefix (sequence-dispatch-node-name n))))))))]]
  REPLACE [[(define (rule-prefix m) '())]]
  EXPECT_OUTPUT_MATCHES ":894-prefix fired at least once -- expected a true value")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/verify-oracle.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "oracle rule :894-prefix always fires (every node)"
  FIND [[(define (rule-prefix m)
    (filter-map-nodes m
      (lambda (n)
        (and (sequence-dispatch-node? n)
             (let ((alts (map sequence-case-bytes (sequence-dispatch-node-cases n))))
               (and (pairwise-prefix? alts)
                    (cons 'ambiguous-sequence-prefix (sequence-dispatch-node-name n))))))))]]
  REPLACE [[(define (rule-prefix m) (map (lambda (zzn) (cons 'ambiguous-sequence-prefix (node-name zzn))) (machine-nodes m)))]]
  EXPECT_OUTPUT_MATCHES ":894-prefix agrees with the verifier -- expected none, got .oracle")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/verify-oracle.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "oracle rule :897-unreachable never fires (returns empty)"
  FIND [[(define (rule-unreachable m)
    (let ((r (reachable m)))
      (map (lambda (nm) (cons 'unreachable-node nm))
           (filter (lambda (nm) (not (member nm r))) (node-set m)))))]]
  REPLACE [[(define (rule-unreachable m) '())]]
  EXPECT_OUTPUT_MATCHES ":897-unreachable fired at least once -- expected a true value")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/verify-oracle.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "oracle rule :897-unreachable always fires (every node)"
  FIND [[(define (rule-unreachable m)
    (let ((r (reachable m)))
      (map (lambda (nm) (cons 'unreachable-node nm))
           (filter (lambda (nm) (not (member nm r))) (node-set m)))))]]
  REPLACE [[(define (rule-unreachable m) (map (lambda (zzn) (cons 'unreachable-node (node-name zzn))) (machine-nodes m)))]]
  EXPECT_OUTPUT_MATCHES ":897-unreachable agrees with the verifier -- expected none, got .oracle")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/verify-oracle.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "oracle rule :908-non-eof-into-finish never fires (returns empty)"
  FIND [[(define (rule-non-eof-into-finish m)
    (let ((r (byte-reached m)))
      (uniq
       (filter-map-nodes m
         (lambda (n)
           (and (member (node-name n) r)
                (exists (lambda (t) (finish-name? m t)) (non-eof-targets n))
                (cons 'non-eof-into-finish (node-name n))))))))]]
  REPLACE [[(define (rule-non-eof-into-finish m) '())]]
  EXPECT_OUTPUT_MATCHES ":908-non-eof-into-finish fired at least once -- expected a true value")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/verify-oracle.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "oracle rule :908-non-eof-into-finish always fires (every node)"
  FIND [[(define (rule-non-eof-into-finish m)
    (let ((r (byte-reached m)))
      (uniq
       (filter-map-nodes m
         (lambda (n)
           (and (member (node-name n) r)
                (exists (lambda (t) (finish-name? m t)) (non-eof-targets n))
                (cons 'non-eof-into-finish (node-name n))))))))]]
  REPLACE [[(define (rule-non-eof-into-finish m) (map (lambda (zzn) (cons 'non-eof-into-finish (node-name zzn))) (machine-nodes m)))]]
  EXPECT_OUTPUT_MATCHES ":908-non-eof-into-finish agrees with the verifier -- expected none, got .oracle")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/verify-oracle.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "oracle rule :898-zero-progress never fires (returns empty)"
  FIND [[(define (rule-zero-progress m)
    (let* ((br (byte-reached m))                     ; 0030 item 7: byte-reached only
           (nodes (filter (lambda (nm) (member nm br)) (node-set m)))
           (on-cycle (nodes-on-nonconsuming-cycle m nodes)))
      (map (lambda (nm) (cons 'zero-progress-cycle nm)) on-cycle)))]]
  REPLACE [[(define (rule-zero-progress m) '())]]
  EXPECT_OUTPUT_MATCHES ":898-zero-progress fired at least once -- expected a true value")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/verify-oracle.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "oracle rule :898-zero-progress always fires (every node)"
  FIND [[(define (rule-zero-progress m)
    (let* ((br (byte-reached m))                     ; 0030 item 7: byte-reached only
           (nodes (filter (lambda (nm) (member nm br)) (node-set m)))
           (on-cycle (nodes-on-nonconsuming-cycle m nodes)))
      (map (lambda (nm) (cons 'zero-progress-cycle nm)) on-cycle)))]]
  REPLACE [[(define (rule-zero-progress m) (map (lambda (zzn) (cons 'zero-progress-cycle (node-name zzn))) (machine-nodes m)))]]
  EXPECT_OUTPUT_MATCHES ":898-zero-progress agrees with the verifier -- expected none, got .oracle")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/verify-oracle.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "oracle rule :909-eof never fires (returns empty)"
  FIND [[(define (rule-eof m)
    (uniq
     (apply append
       (map (lambda (start)
              (let ((v (eof-verdict m (parked-eof-start m start) '())))
                (cond ((eq? v 'stop) (list (cons 'eof-reachable-stop (node-name start))))
                      ((eq? v 'cycle) (list (cons 'eof-zero-progress-cycle (node-name start))))
                      (else '()))))
            (parked-set m)))))]]
  REPLACE [[(define (rule-eof m) '())]]
  EXPECT_OUTPUT_MATCHES ":909-eof fired at least once -- expected a true value")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/verify-oracle.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "oracle rule :909-eof always fires (every node)"
  FIND [[(define (rule-eof m)
    (uniq
     (apply append
       (map (lambda (start)
              (let ((v (eof-verdict m (parked-eof-start m start) '())))
                (cond ((eq? v 'stop) (list (cons 'eof-reachable-stop (node-name start))))
                      ((eq? v 'cycle) (list (cons 'eof-zero-progress-cycle (node-name start))))
                      (else '()))))
            (parked-set m)))))]]
  REPLACE [[(define (rule-eof m) (map (lambda (zzn) (cons 'eof-reachable-stop (node-name zzn))) (machine-nodes m)))]]
  EXPECT_OUTPUT_MATCHES ":909-eof agrees with the verifier -- expected none, got .oracle")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Milestone 7 Slice ④ Pass 61: the compile-file limits witness --------------
# The SIXTY-FIRST pass. It runs compile-limits-tests.sps (§4.12 item 2). Two
# mutations: compile-file replaced by a plain load of the source (caught by the
# object-exists check, written before the object is loaded); and the interpreter-
# agreement comparison inverted (caught by the agreement check).
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/compile-limits-tests.sps")

byte_machine_mutation(
  FILE test/common/compile-limits-tests.sps
  SPEC byte-machine.unit.compile-limits.chez.source
  LABEL "compile-file is replaced by a plain load of the source"
  FIND [[(compile-file genfile objfile)]]
  REPLACE [[(load genfile)]]
  EXPECT_OUTPUT_MATCHES "the object file exists and is non-empty -- expected a true value")

byte_machine_mutation(
  FILE test/common/compile-limits-tests.sps
  SPEC byte-machine.unit.compile-limits.chez.source
  LABEL "the interpreter-agreement comparison is inverted"
  FIND [[(check-equal "the two lanes agree on the full triple" (and rc (triple rc)) (triple ri))]]
  REPLACE [[(check-not-equal "the two lanes agree on the full triple" (and rc (triple rc)) (triple ri))]]
  EXPECT_OUTPUT_MATCHES "the two lanes agree on the full triple -- expected any value other than")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

byte_machine_mutation_reset()

# --- Milestone 8 Slice ①: the request line's own decisions -------------------
# Three decisions the request-line fixture (http-machine.sls) encodes, each
# caught by the unit lane with a MEASURED failure signature -- the got value the
# mutation produces, not a bare nonzero exit (Slice ③'s pin-audit rule). Measured
# against a staged run 2026-09-12:
#   1. the first method byte belongs to the span -- idle REEXECUTES a tchar into
#      message-begin (decision 0037), so advancing it instead drops the byte and
#      the method span reads "ET" not "GET";
#   2. a span ends BEFORE its delimiter SP (§21.3:1140) -- advancing at the token
#      end pulls the SP into the span, which then reads "GET ";
#   3. the version production is HTTP/1.0 / HTTP/1.1 -- altering the 1.1
#      alternative rejects a canonical HTTP/1.1 request at its final digit.
# No collision sweep against other passes is owed: this FILE and this SPEC lane
# are new to this slice, so no existing pin's FIND or output is touched.
set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/http-request-line-tests.sps")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/http-machine.sls
  SPEC byte-machine.unit.http-request-line.chez.source
  LABEL "http-machine: idle advances the first method byte instead of reexecuting it into the span"
  FIND [[(make-edge 'msg-begin 'reexecute)]]
  REPLACE [[(make-edge 'msg-begin 'advance)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "method-data .ET.")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/http-machine.sls
  SPEC byte-machine.unit.http-request-line.chez.source
  LABEL "http-machine: the method span consumes its delimiter SP instead of ending before it"
  FIND [[(make-edge 'method-close 'reexecute)]]
  REPLACE [[(make-edge 'method-close 'advance)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "method-data .GET .")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/http-machine.sls
  SPEC byte-machine.unit.http-request-line.chez.source
  LABEL "http-machine: the HTTP/1.1 version alternative is not recognized"
  FIND [[(make-sequence-case (string-bytes "HTTP/1.1") 'ver-ok #f)]]
  REPLACE [[(make-sequence-case (string-bytes "HTTP/1.2") 'ver-ok #f)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "invalid-version byte 18")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

byte_machine_mutation_reset()

# --- Milestone 8 Slice ②: the header section's own decisions -----------------
# Three decisions the header section encodes, caught by the http-message lane
# with a MEASURED signature (the got value, not a bare nonzero exit). Measured
# against a staged run 2026-09-12: the first header-name byte belongs to the name
# span (header-line-start REEXECUTES a tchar into hn-open); a header name ends
# BEFORE its colon (hn-loop reexecutes the colon into hn-close); and the header
# value opens AFTER leading OWS is skipped (ows-skip reexecutes the first
# non-OWS byte into hv-open), so advancing there drops the value's first byte.
set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/http-message-tests.sps")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/http-machine.sls
  SPEC byte-machine.unit.http-message.chez.source
  LABEL "http-machine: the first header-name byte is advanced past instead of opening the name span"
  FIND [[(make-edge 'hn-open 'reexecute)]]
  REPLACE [[(make-edge 'hn-open 'advance)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "header-name-data .ost.")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/http-machine.sls
  SPEC byte-machine.unit.http-message.chez.source
  LABEL "http-machine: the header name consumes its colon instead of ending before it"
  # Re-anchored in Slice ③: `(make-edge 'hn-close 'reexecute)` now occurs three
  # times (hn-loop, cl-end, te-end all reexecute into hn-close), so the FIND
  # includes hn-loop's own self-loop line to stay a single site.
  FIND [[(make-edge 'hn-loop 'advance) #f))
       (make-edge 'hn-close 'reexecute)]]
  REPLACE [[(make-edge 'hn-loop 'advance) #f))
       (make-edge 'hn-close 'advance)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "header-name-data .Host:.")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/http-machine.sls
  SPEC byte-machine.unit.http-message.chez.source
  LABEL "http-machine: the header value advances past its first byte instead of opening the span there"
  FIND [[(make-edge 'hv-open 'reexecute)]]
  REPLACE [[(make-edge 'hv-open 'advance)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "header-value-data .xample.com.")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

byte_machine_mutation_reset()

# --- Milestone 8 Slice ③: framing recognition and the fixed body ------------
# Three decisions the framing slice encodes, caught by the http-framing lane with
# a MEASURED signature. Measured against a staged run 2026-09-12:
#   1. recognition is CASE-INSENSITIVE (decision 0035): both-cases yields the
#      character's two cases, so collapsing it to one drops lowercase/mixed names;
#   2. a framing header's flag is checked at the boundary AFTER the line's LF
#      (§21.4:1175): inverting the duplicate test flags the FIRST Content-Length;
#   3. Content-Length is base-10 checked accumulation (§21.2:1073): base 16 makes
#      "abc" a valid length and moves the overflow digit.
set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/http-framing-tests.sps")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/http-machine.sls
  SPEC byte-machine.unit.http-framing.chez.source
  LABEL "http-machine: framing recognition is no longer case-insensitive"
  FIND [[(if (>= b 97) (list b (- b 32)) (list b (+ b 32)))]]
  REPLACE [[(list b)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "hit: content-length -- expected error")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/http-machine.sls
  SPEC byte-machine.unit.http-framing.chez.source
  LABEL "http-machine: the Content-Length duplicate test is inverted, flagging the first one"
  FIND [[(make-field-branch-node 'cl-line-done 'nonzero '(has-cl)]]
  REPLACE [[(make-field-branch-node 'cl-line-done 'zero '(has-cl)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "duplicate-content-length boundary 35")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/http-machine.sls
  SPEC byte-machine.unit.http-framing.chez.source
  LABEL "http-machine: Content-Length accumulates in base 16 instead of base 10"
  FIND [['cl-value 'content-length 10 'cl-value]]
  REPLACE [['cl-value 'content-length 16 'cl-value]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "content-length-overflow byte 48")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

byte_machine_mutation_reset()

# --- Milestone 8 Slice ④: the chunked body and trailers ----------------------
# Three decisions the chunked slice encodes, caught by the http-chunked lane with
# a MEASURED signature. Measured against a staged run 2026-09-12:
#   1. chunk sizes are BASE 16 (§21.2:1108): base 10 rejects an all-`f` size as a
#      malformed extension instead of overflowing;
#   2. the chunk-header size decides body vs trailers: inverting it routes a
#      nonzero chunk's data into the trailer section (its bytes read as a name);
#   3. a Content-Length trailer is FORBIDDEN at the colon (§21.2:1110): dropping
#      the recognizer's forbidden verdict accepts it.
set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/http-chunked-tests.sps")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/http-machine.sls
  SPEC byte-machine.unit.http-chunked.chez.source
  LABEL "http-machine: chunk sizes accumulate in base 10 instead of base 16"
  FIND [['chunk-size 'chunk-size 16 'chunk-size]]
  REPLACE [['chunk-size 'chunk-size 10 'chunk-size]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "invalid-chunk-extension byte 46")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/http-machine.sls
  SPEC byte-machine.unit.http-chunked.chez.source
  LABEL "http-machine: the chunk-header size test is inverted, routing chunk data to the trailers"
  FIND [[(make-field-branch-node 'chunk-body-decide 'nonzero '(chunk-size)]]
  REPLACE [[(make-field-branch-node 'chunk-body-decide 'zero '(chunk-size)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "trailer-name-data .HELLO.")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/http-machine.sls
  SPEC byte-machine.unit.http-chunked.chez.source
  LABEL "http-machine: a Content-Length trailer is accepted instead of forbidden"
  FIND [['tcl-end
       (list (make-byte-case (make-exact-byte-matcher 58) (make-edge 'e-forbidden-trailer 'reexecute) #f)]]
  REPLACE [['tcl-end
       (list (make-byte-case (make-exact-byte-matcher 58) (make-edge 'trailer-name-close 'reexecute) #f)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "Content-Length trailer -- expected .forbidden-trailer byte 63., got #f")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Milestone 11 Slice ① passes 66-68: the keyword-table node kind ------------
# The fourteenth node kind (decision 0043), its compact-table lowering (0044) and
# the per-table fold (0045). The census ratchets in ir.sls (the "fourteen kinds"
# rows, re-anchored above) already carry the closed-set FORMS; these ten pins
# carry the SEMANTICS the design's §5 mutation bullet names -- the fold, the
# terminal-vs-continue split, the delimiter reexecute, the target/no-match
# routing, the eof route, and the emitted ABI literal -- each caught absolutely
# by one of the slice's three new lanes, never by a bare nonzero exit. The fold
# and the reexecute are pinned on BOTH executors (interpreter and generated),
# because decision 0015 derives them independently and a defect in one is a
# differential result, not a shared wrong answer.

# --- Pass 66: the interpreter's keyword walk (unit.keyword-table) --------------
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/keyword-interpret-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls
  SPEC byte-machine.unit.keyword-table.chez.source
  LABEL "interpret: the keyword fold goes the wrong direction (decision 0045)"
  # A..Z fold to a..z (+32). Subtracting folds an uppercase keyword AWAY from its
  # lowercased input, so the case-insensitive table stops matching a lowercased
  # method. Comparison-caught by the CI cases.
  FIND [[(if (and ci (>= b 65) (<= b 90)) (+ b 32) b)]]
  REPLACE [[(if (and ci (>= b 65) (<= b 90)) (- b 32) b)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[accepts every casing to the same target: get -- expected .stopped 3 3 3 got-get #f #f., got .error 0 0 0 reject unexpected-byte 0.]])

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls
  SPEC byte-machine.unit.keyword-table.chez.source
  LABEL "interpret: a matched keyword consumes its delimiter instead of reexecuting it (decision 0043)"
  # The byte that closes a keyword is left unread, so the span ends at the
  # keyword length. Advancing consumes it and every span runs one byte long.
  FIND [[(cons (keyword-entry-target term) 'reexecute)]]
  REPLACE [[(cons (keyword-entry-target term) 'advance)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[takes the short keyword, span closes at 3 .delimiter not consumed.: get -- expected .stopped 3 3 3 got-get #f #f., got .stopped 4 4 4 got-get #f #f.]])

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls
  SPEC byte-machine.unit.keyword-table.chez.source
  LABEL "interpret: eof-target-of has no keyword-table arm (the AGENTS.md kind-filter trap)"
  # eof-target-of is the per-kind filter a lookup does not teach. Neutering its
  # keyword-table arm sends a parked table to the raising `else`; a finish! then
  # raises `internal`, reported by the EOF case as "case raised".
  FIND [[((keyword-table-node? n) (keyword-table-node-eof-target n))]]
  REPLACE [[((and (keyword-table-node? n) #f) (keyword-table-node-eof-target n))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[each of six EOF inputs takes the eof-target at its own offset: case raised]])

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls
  SPEC byte-machine.unit.keyword-table.chez.source
  LABEL "interpret: a walk position is a terminal even when the path is a proper prefix (decision 0043)"
  # A keyword terminates only when the path EQUALS an entry's bytes; dropping the
  # length test makes every proper prefix a false terminal (GET-X would take the
  # GET-PARAMETER path's target instead of no-matching, and a non-keyword first
  # byte would falsely match).
  FIND [[(and (= (length bs) (length path)) (kw-prefix? ci path bs))]]
  REPLACE [[(and #t (kw-prefix? ci path bs))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[never rewinding to GET: get-x -- expected .error 4 4 4 reject unexpected-byte 4., got .stopped 4 4 4 got-gp #f #f.]])

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 67: the generated compact-table walk (differential.keyword-table) ----
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/differential-keyword-table-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.keyword-table.chez.source
  LABEL "runtime: the keyword-step op folds the wrong direction (decision 0045, generated lane)"
  # The runtime op's own fold, derived independently of the interpreter's. The
  # differential asserts the generated table absolutely, so a wrong fold reddens
  # even though the interpreter (unmutated) still folds correctly.
  FIND [[(if (and ci? (>= b 65) (<= b 90)) (+ b 32) b)]]
  REPLACE [[(if (and ci? (>= b 65) (<= b 90)) (- b 32) b)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[accepts every casing to the same target: no casing misbehaved -- expected none, got .gen "get " .error 0 0 0 reject unexpected-byte 0..]])

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.keyword-table.chez.source
  LABEL "runtime: a matched keyword routes to the no-match edge instead of its target (decision 0043)"
  # `(cdr term)` is the matched entry's target id; routing to the no-match target
  # sends every matched keyword to the reject node.
  FIND [[(term (list 'jump (cdr term) i (quote byte)))]]
  REPLACE [[(term (list 'jump (car no-match) i (quote byte)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[agrees with the interpreter: no case misbehaved -- expected none, got .gen "GET-PARAMETER " .error 13 13 13 reject unexpected-byte 13..]])

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.keyword-table.chez.source
  LABEL "runtime: a matched keyword consumes its delimiter instead of reexecuting it (decision 0043, generated lane)"
  # The op reports position `i` (the closing byte is left unread); reporting
  # `(+ i 1)` consumes it and the span runs one byte long. Same FIND as the pin
  # above, a different edit -- each is staged independently.
  FIND [[(term (list 'jump (cdr term) i (quote byte)))]]
  REPLACE [[(term (list 'jump (cdr term) (+ i 1) (quote byte)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[agrees with the interpreter: no case misbehaved -- expected none, got .gen "GET-PARAMETER " .stopped 14 14 14 got-gp #f #f..]])

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.keyword-table.chez.source
  LABEL "runtime: a walk position is a terminal even when the path is a proper prefix (decision 0043, generated lane)"
  # The generated twin of the interpreter's terminal-length pin: without the
  # length test the op accepts a proper prefix as a terminal, so GET-X takes the
  # GET-PARAMETER path's target rather than no-matching.
  FIND [[(= (length (car (car es))) (length p))]]
  REPLACE [[#t]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[agrees with the interpreter: no case misbehaved -- expected none, got .gen "GET-X" .stopped 4 4 4 got-gp #f #f..]])

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls
  SPEC byte-machine.differential.keyword-table.chez.source
  LABEL "normal-ir: the case-insensitive flag is not encoded into the table (decision 0045 item 5)"
  # Slot 8 is the fold flag. Forcing it #f makes a case-insensitive table encode
  # as case-sensitive, so the fold vanishes AND -- the unique witness -- two
  # tables differing only in the flag now render identically, which the
  # fingerprint group forbids (decision 0045 item 5). Pinned to that group, not
  # the shared CI-fold failure the runtime-fold pin above also produces.
  FIND [[(keyword-table-node-case-insensitive? n) #f #f)))]]
  REPLACE [[#f #f #f)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the two renders differ on the flag alone -- expected a true value]])

# The three below close gaps the Slice ① adversarial review confirmed: the walk
# op's error position-kind was never compared across executors (interpret.sls
# lists it as required-to-match), the no-match edge's advance arm had no
# coverage, and the keyword-table's entry in the reached-declaration credit list
# had no witness. Each is caught by a group added to differential-keyword-table.
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.keyword-table.chez.source
  LABEL "runtime: the no-match reject reports the wrong position-kind (boundary, not byte)"
  # The reexecute no-match does not consume the offending byte, so the error is
  # AT that byte (position-kind byte), not after it (boundary). The differential
  # now compares position-kind across executors and absolutely.
  FIND [[(else (list 'jump (car no-match) i (quote byte)))]]
  REPLACE [[(else (list 'jump (car no-match) i (quote boundary)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[a no-match reject reports position-kind byte on the generated table and both agree: generated -- expected byte, got boundary]])

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.keyword-table.chez.source
  LABEL "runtime: the advance no-match does not consume the offending byte"
  # The advance arm consumes the mismatching byte (offset i+1); dropping the
  # increment leaves it unconsumed, which is the reexecute behaviour under an
  # advance edge. Caught by the advance-mode group.
  FIND [[(list 'jump (car no-match) (+ i 1) (quote boundary))]]
  REPLACE [[(list 'jump (car no-match) i (quote boundary))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[advances .consumed 1. and the reject is at the boundary after it, both lanes: generated -- expected .error 1 1 1 reject unexpected-byte 1., got .error 0 0 0 reject unexpected-byte 0.]])

byte_machine_mutation(
  FILE src/byte-machine/compile.sls
  SPEC byte-machine.differential.keyword-table.chez.source
  LABEL "compile: the reached declaration walk ignores keyword-table (default-eof credit)"
  # A keyword table with eof-target #f is the sole consumer of the default-eof
  # declaration; not crediting the keyword-table kind filters that declaration
  # out of the errs table and render-machine raises on a machine the verifier
  # accepted -- the Milestone 4 Slice ③ defect, one kind later. Distinct from the
  # counted-consume-drop pin above (different REPLACE, keyword-table's own row).
  FIND [[                                                      '(dispatch accumulate counted-consume
                                                        keyword-table))]]
  REPLACE [[                                                      '(dispatch accumulate counted-consume))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the default-eof machine renders and its EOF route takes the machine default error: case raised.*no error declaration for code]])

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 68: the emitted ABI literal (determinism.keyword-table) --------------
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/determinism-keyword-table-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls
  SPEC byte-machine.determinism.keyword-table.chez.source
  LABEL "compile: the emitted ABI version literal is not the current one (decision 0044)"
  # The keyword table lands together with the ABI bump 5->6 (decision 0044); the
  # emitted literal must be the current version. Emitting 5 both diverges the
  # rendered bytes from the committed golden AND makes the v6 runtime refuse the
  # library outright at construction -- `byte-machine-make-compiled-machine`
  # validates the version, so the determinism lane's top-level load of the
  # generated file raises "generated-runtime ABI mismatch with irritant 5"
  # (status 255) before it can report the golden mismatch cleanly. That refusal
  # is the sharper witness -- it names the version the emitter stamped -- so the
  # pin asserts it by message, not by the raw-byte golden diff. This is the ONE
  # pin on the emitted literal; there was none before this slice.
  FIND [[(byte-machine-make-compiled-machine 6 ]]
  REPLACE [[(byte-machine-make-compiled-machine 5 ]]
  EXPECT_STATUS 255
  EXPECT_OUTPUT_MATCHES [[generated-runtime ABI mismatch with irritant 5]])

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Milestone 11 Slice ② Pass 69: the folded-collision rejection --------------
# decision 0045 item 3: a case-insensitive table whose entries collide under
# ASCII folding is refused with case-insensitive-keyword-collision. The three
# pins carry the new verifier code -- the collision arm, its per-table guard, and
# the verifier's own fold -- each caught absolutely by the header lane's collision
# verify group (verify-machine directly), never by a bare nonzero exit. The
# executor folds are Slice ①'s; this is the verifier's, which is new here.
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/differential-keyword-header-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls
  SPEC byte-machine.differential.keyword-header.chez.source
  LABEL "verify: the folded-collision check never fires (decision 0045 item 3)"
  # Forcing the guard #f drops the collision detection: a case-insensitive table
  # whose entries fold-collide now verifies clean, so the header lane's
  # collision-refused assertion reddens.
  FIND [[((and ci (fold=? (car rest) (car others)))]]
  REPLACE [[((and #f (fold=? (car rest) (car others)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the collision table does not verify -- expected a true value]])

byte_machine_mutation(
  FILE src/byte-machine/verify.sls
  SPEC byte-machine.differential.keyword-header.chez.source
  LABEL "verify: the collision check ignores the case-insensitive? flag (decision 0045 item 1, per table)"
  # Forcing the guard #t runs the fold check on EVERY table, so a case-SENSITIVE
  # table of byte-distinct case variants (legal: byte-different, no fold) is
  # wrongly refused. The CS collision machine's verifies-clean assertion reddens.
  # Same FIND as the pin above, a different edit -- each staged independently.
  FIND [[((and ci (fold=? (car rest) (car others)))]]
  REPLACE [[((and #t (fold=? (car rest) (car others)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the case-sensitive collision-shaped table verifies -- expected a true value]])

byte_machine_mutation(
  FILE src/byte-machine/verify.sls
  SPEC byte-machine.differential.keyword-header.chez.source
  LABEL "verify: the collision fold goes the wrong direction (decision 0045)"
  # The verifier's own fold, independent of the executors' (Slice ①). Subtracting
  # folds A (65) to 33 while a (97) is unchanged, so A and a no longer fold-equal
  # and the collision is missed -- the case-insensitive table verifies clean.
  FIND [[(if (and (>= b 65) (<= b 90)) (+ b 32) b)]]
  REPLACE [[(if (and (>= b 65) (<= b 90)) (- b 32) b)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the collision table does not verify -- expected a true value]])

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# Every pass above has now run exactly once, so the accumulated total is
# final. Compared against the numbers declared at the top of this file --
# see EXPECTED_PASSES and EXPECTED_MUTATIONS, and the "FIFTY-EIGHT PASSES"
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
