# Specification for cmake/ByteMachinePortabilityGuard.cmake.
#
# Two rules, both about failures that are silent by construction.
#
# A shared body with only one wrapper is proven on one runtime while looking
# like it is proven on two. Nothing fails; there is simply one fewer lane than
# the tree suggests.
#
# Two shared bodies with the same basename collapse into one file, because Chez
# resolves includes through source-directories -- a single flat namespace shared
# with src/common once Milestone 1 lands. The build stays green and one of the
# two bodies is never executed again.

cmake_minimum_required(VERSION 3.26)

include("${CMAKE_CURRENT_LIST_DIR}/../../../cmake/ByteMachinePortabilityGuard.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/SpecSupport.cmake")

set(SPEC_SELF "${CMAKE_CURRENT_LIST_FILE}")

# --- Fixture ---------------------------------------------------------------
#
# Both the wrapper rule and the guard itself are about what is on disk -- the
# guard only ever learns of a body by globbing a directory -- so both are
# checked against real files rather than invented path strings. The staging is
# written into the test's own temporary directory, and is rebuilt by every
# process that runs this file: the driver below, and each rejection case it
# re-invokes. No case depends on another having run first.

if(DEFINED ENV{BYTE_MACHINE_TEST_TMPDIR})
  set(fixture "$ENV{BYTE_MACHINE_TEST_TMPDIR}/guard-fixture")
else()
  set(fixture "${CMAKE_CURRENT_LIST_DIR}/../../../build/guard-fixture")
endif()
file(REMOVE_RECURSE "${fixture}")
file(MAKE_DIRECTORY "${fixture}")

# Bodies for the wrapper-pairing assertions, which are handed paths directly.
file(WRITE "${fixture}/both.scm" "")
file(WRITE "${fixture}/both.chez.sps" "")
file(WRITE "${fixture}/both.gambit.scm" "")
file(WRITE "${fixture}/chez-only.scm" "")
file(WRITE "${fixture}/chez-only.chez.sps" "")
file(WRITE "${fixture}/neither.scm" "")

# Directories for the guard itself, which is handed directories and globs them.
# `empty` holds no body at all. `twin-a` and `twin-b` hold one basename between
# them. `paired` holds a body with both wrappers and `unpaired` a body with
# neither, so a guard that demanded wrappers of the *shared* directories instead
# of the wrapped ones would find nothing to complain about and pass.
file(MAKE_DIRECTORY "${fixture}/empty")
file(MAKE_DIRECTORY "${fixture}/twin-a")
file(MAKE_DIRECTORY "${fixture}/twin-b")
file(MAKE_DIRECTORY "${fixture}/paired")
file(MAKE_DIRECTORY "${fixture}/unpaired")
file(WRITE "${fixture}/twin-a/twin.scm" "")
file(WRITE "${fixture}/twin-b/twin.scm" "")
file(WRITE "${fixture}/paired/paired-body.scm" "")
file(WRITE "${fixture}/paired/paired-body.chez.sps" "")
file(WRITE "${fixture}/paired/paired-body.gambit.scm" "")
file(WRITE "${fixture}/unpaired/unpaired-body.scm" "")

# Nested bodies, for the rules that only bite if the glob descends. Each
# directory holds a top-level body as well, so a non-recursive glob finds
# something there and passes the per-directory contribution check -- otherwise
# these cases would be rejected for emptiness and prove nothing about depth.
#
# `nested-dup/deep/twin.scm` repeats the basename in `twin-a`, and
# `nested-unpaired/deep/deep-body.scm` has neither wrapper. Both violations are
# invisible to a glob that stops at the top level, which is the whole point: a
# body in a subdirectory would be neither checked nor reported, and the tree
# would be called portable without it having been looked at.
file(MAKE_DIRECTORY "${fixture}/nested-dup/deep")
file(WRITE "${fixture}/nested-dup/surface.scm" "")
file(WRITE "${fixture}/nested-dup/deep/twin.scm" "")
file(MAKE_DIRECTORY "${fixture}/nested-unpaired/deep")
file(WRITE "${fixture}/nested-unpaired/surface-body.scm" "")
file(WRITE "${fixture}/nested-unpaired/surface-body.chez.sps" "")
file(WRITE "${fixture}/nested-unpaired/surface-body.gambit.scm" "")
file(WRITE "${fixture}/nested-unpaired/deep/deep-body.scm" "")

# --- Rejection cases -------------------------------------------------------
#
# byte_machine_portability_guard's entire contract is to stop a build, so none
# of its decisions can be observed by a call that returns: the only visible
# outcome of a correct one is a dead process. Each case below is run as its own
# process by spec_expect_all_rejected at the foot of this file, and each must
# exit nonzero *and* print the diagnostic named there. Without the message check
# a guard that died for some unrelated reason -- a typo in this dispatch, a glob
# that stopped working -- would look like a decision being enforced.

if(DEFINED BYTE_MACHINE_SPEC_CASE)
  set(c "${BYTE_MACHINE_SPEC_CASE}")

  if(c STREQUAL "guard-rejects-an-unexpected-argument")
    # SHARED_DIRS is deliberately valid and complete, so nothing else here can
    # stop the build: a guard that does not reject the stray token globs the one
    # directory it did understand, finds no violation, and prints the success
    # banner -- claiming the wrapper rule held for a WRAPPED_DIRS it never
    # received. The stray token leads, because a misspelt keyword *after* a
    # multi-value one is absorbed as a directory rather than left unparsed.
    byte_machine_portability_guard(
      WRAPPED_DIR "${fixture}/unpaired"
      SHARED_DIRS "${fixture}/paired")
  elseif(c STREQUAL "guard-rejects-a-trailing-misspelt-keyword")
    # The other half of the same typo, and the form the real call site is
    # exposed to: at test/CMakeLists.txt the trailing keyword is WRAPPED_DIRS,
    # so a typo there lands *after* SHARED_DIRS and is absorbed into its value
    # -- arg_UNPARSED_ARGUMENTS is empty and the case above cannot see it. What
    # stops it is that `WRAPPED_DIR` is not a directory. SHARED_DIRS is again
    # deliberately complete, so a guard that does not check its entries globs
    # `paired/`, finds no violation, and prints the success banner for a
    # WRAPPED_DIRS it never received.
    byte_machine_portability_guard(
      SHARED_DIRS "${fixture}/paired"
      WRAPPED_DIR "${fixture}/unpaired")
  elseif(c STREQUAL "guard-rejects-a-misspelt-keyword-after-wrapped-dirs")
    # The mirror image of the case above, and the only case that observes the
    # entry check being applied to WRAPPED_DIRS as well as to SHARED_DIRS.
    # Without it the keyword loop could be reduced to `IN ITEMS SHARED_DIRS`
    # and every other case would still pass, so the decision to check both
    # would be a claim nothing tests.
    #
    # The trailing directory is `empty` rather than a second `paired`: a second
    # `paired` would repeat the basename `paired-body.scm` and a guard that
    # skipped the entry check would then die on the duplicate rule instead of
    # returning -- the case would pass for a reason that has nothing to do with
    # what it is written to prove. With `empty`, a guard that skips the check
    # globs one body from `paired/`, finds it unique and both-wrapped, and
    # prints the success banner.
    byte_machine_portability_guard(
      WRAPPED_DIRS "${fixture}/paired"
      SHARED_DIR "${fixture}/empty")
  elseif(c STREQUAL "guard-rejects-a-directory-that-contributes-nothing")
    # The per-directory half of "found nothing". `paired` contributes a body, so
    # the whole-call check below is satisfied and only a check that looks at
    # each directory separately can see that `empty` contributed none. This is
    # the shape slice 3 walks into: spec section 8.4 widens the guard to
    # src/common, which today holds only a .gitkeep, so the harness directories
    # would keep the combined result non-empty while the new directory was
    # reported portable without ever having been looked at.
    byte_machine_portability_guard(
      SHARED_DIRS "${fixture}/paired" "${fixture}/empty")
  elseif(c STREQUAL "guard-rejects-a-nested-duplicate-basename")
    # Proves the glob descends. `nested-dup` holds a top-level body as well, so
    # a non-recursive glob finds one there, reports the directory as having
    # contributed, and never sees `deep/twin.scm` colliding with `twin-a`.
    byte_machine_portability_guard(
      SHARED_DIRS "${fixture}/twin-a" "${fixture}/nested-dup")
  elseif(c STREQUAL "guard-rejects-a-nested-missing-wrapper")
    # The same descent, for the other rule, and the only case that exercises
    # byte_machine_guard_missing_wrappers deriving sibling wrapper paths for a
    # body that is not at the top of its declared directory.
    byte_machine_portability_guard(
      WRAPPED_DIRS "${fixture}/nested-unpaired")
  elseif(c STREQUAL "guard-rejects-an-empty-glob")
    # A guard that finds nothing must say so. Reporting a tree it never looked
    # at as portable is worse than not guarding it, because it is reported as
    # checked. This is now the per-directory check's doing -- a lone empty
    # directory is a directory that contributed nothing -- and the whole-call
    # check below survives for the one case no per-directory loop can reach.
    byte_machine_portability_guard(SHARED_DIRS "${fixture}/empty")
  elseif(c STREQUAL "guard-rejects-a-call-declaring-no-directories")
    # The case the per-directory loop cannot see, because it does not run: a
    # caller that names neither keyword. Without this check that call globs
    # nothing, finds no violation in the nothing it globbed, and prints the
    # success banner -- the strongest possible form of reporting a tree as
    # checked without looking at it.
    byte_machine_portability_guard()
  elseif(c STREQUAL "guard-rejects-a-duplicate-basename")
    byte_machine_portability_guard(
      SHARED_DIRS "${fixture}/twin-a" "${fixture}/twin-b")
  elseif(c STREQUAL "guard-rejects-a-missing-wrapper")
    # The shared directory is deliberately complete, so this case fails only if
    # the pairing rule is applied to WRAPPED_DIRS.
    byte_machine_portability_guard(
      SHARED_DIRS "${fixture}/paired"
      WRAPPED_DIRS "${fixture}/unpaired")
  else()
    message(FATAL_ERROR "byte-machine-spec: unknown case '${c}'")
  endif()

  message(FATAL_ERROR "byte-machine-spec: case '${c}' was accepted but must be rejected")
endif()

# --- Driver ----------------------------------------------------------------

# --- Wrapper files are not shared bodies -----------------------------------

byte_machine_guard_shared_bodies(bodies
  "/h/self/a.scm" "/h/self/a.gambit.scm" "/h/self/b.scm")
spec_check_equal("${bodies}" "/h/self/a.scm;/h/self/b.scm"
  "a Gambit wrapper is not itself a shared body")

# Chez wrappers end in .sps and so fall outside a *.scm glob already. The rule
# is stated anyway rather than left to an extension that happens to differ,
# because a future glob that included .sps would otherwise silently start
# treating wrappers as bodies.
byte_machine_guard_shared_bodies(bodies "/h/self/a.scm" "/h/self/a.chez.sps")
spec_check_equal("${bodies}" "/h/self/a.scm"
  "a Chez wrapper is not itself a shared body")

# --- Duplicate basenames ---------------------------------------------------

byte_machine_guard_duplicate_basenames(dupes
  "/h/shared/runner.scm" "/src/common/runner.scm")
spec_check_equal("${dupes}" "runner.scm"
  "the same basename in two directories is a collision")

byte_machine_guard_duplicate_basenames(dupes
  "/h/shared/harness-runner.scm" "/src/common/model.scm")
spec_check_equal("${dupes}" ""
  "distinct basenames are not a collision")

# Reported once however many times it repeats, so the diagnostic names the
# problem rather than counting it.
byte_machine_guard_duplicate_basenames(dupes "/a/x.scm" "/b/x.scm" "/c/x.scm")
spec_check_equal("${dupes}" "x.scm" "a basename is reported once")

# Seeded, so a function that never writes its output is distinguishable from one
# that correctly reports no duplicates.
set(dupes "seed")
byte_machine_guard_duplicate_basenames(dupes "/a/x.scm")
spec_check_equal("${dupes}" "" "a single body has no duplicates")

# The accumulator inside byte_machine_guard_duplicate_basenames is itself named
# `duplicates`. CMake functions get their own variable scope, but reading an
# unset local falls through to whatever the *calling* scope already bound under
# that exact name -- so an accumulator that skips its own initializer is safe
# only until some caller's scope happens to have a stale value sitting under the
# same identifier. Seeding the output variable (as above) cannot catch this: the
# hazard is keyed to the accumulator's name, not the caller's. Proven by seeding
# that exact name, ambient to the call, with a value no correct call could ever
# produce, then confirming a call with no real duplicates does not leak it.
set(duplicates "stale-ambient-value")
byte_machine_guard_duplicate_basenames(dupes "/a/x.scm")
spec_check_equal("${dupes}" ""
  "no duplicates does not leak an ambient 'duplicates' variable")
unset(duplicates)

# --- Missing wrappers ------------------------------------------------------

byte_machine_guard_missing_wrappers(missing "${fixture}/both.scm")
spec_check_equal("${missing}" "" "a body with both wrappers is complete")

byte_machine_guard_missing_wrappers(missing "${fixture}/chez-only.scm")
spec_check_equal("${missing}" "${fixture}/chez-only.scm|${fixture}/chez-only.gambit.scm"
  "a body with no Gambit wrapper is reported")

byte_machine_guard_missing_wrappers(missing "${fixture}/neither.scm")
list(LENGTH missing missing_count)
spec_check_equal("${missing_count}" "2" "a body with no wrappers reports both")

# --- The guard itself ------------------------------------------------------
#
# Each fragment names wording the module controls, so replacing a FATAL_ERROR
# with a differently worded message is a failure rather than something that
# passes on "an error happened". Four of them reach past the wording to the
# text the diagnostic must interpolate -- the wrapper it should have demanded,
# and the stray token it should have refused, named once where the parser left
# it unparsed and once for each keyword that can absorb it -- because a guard
# that checked the wrong thing would still be able to produce the first half of
# any of those sentences. The two absorbed-token fragments differ only in which
# keyword is reported about which token, and that is the point: each is
# satisfied only by the half of the entry check that runs over its keyword.
#
# These are regular expressions (spec_expect_rejected matches with MATCHES), so
# every `.` in a filename is escaped: an unescaped one is a wildcard that would
# also match, say, `twinxscm`. The `.*` in the wrapper fragment is the one
# deliberate metacharacter, bridging two halves of a sentence whose middle
# contains `Missing (body|wrapper):` -- `|` is this helper's own entry separator
# and `()` are metacharacters, so that middle cannot be written out. Bridging is
# safe because spec_flatten collapses the diagnostic to a single line first.

spec_expect_all_rejected("${SPEC_SELF}"
  "guard-rejects-an-unexpected-argument|unexpected arguments to byte_machine_portability_guard: WRAPPED_DIR"
  "guard-rejects-a-trailing-misspelt-keyword|SHARED_DIRS was given 'WRAPPED_DIR', which is not an existing directory"
  "guard-rejects-a-misspelt-keyword-after-wrapped-dirs|WRAPPED_DIRS was given 'SHARED_DIR', which is not an existing directory"
  "guard-rejects-a-directory-that-contributes-nothing|contributed no shared body: .*/empty"
  "guard-rejects-a-nested-duplicate-basename|basenames must be unique across every shared body directory, but these repeat: twin\\.scm"
  "guard-rejects-a-nested-missing-wrapper|every shared test body needs a wrapper for each runtime.*deep-body\\.gambit\\.scm"
  "guard-rejects-an-empty-glob|contributed no shared body: .*/empty"
  "guard-rejects-a-call-declaring-no-directories|was given no directories to check"
  "guard-rejects-a-duplicate-basename|basenames must be unique across every shared body directory, but these repeat: twin\\.scm"
  "guard-rejects-a-missing-wrapper|every shared test body needs a wrapper for each runtime.*unpaired-body\\.gambit\\.scm")

spec_finish("ByteMachinePortabilityGuard")
