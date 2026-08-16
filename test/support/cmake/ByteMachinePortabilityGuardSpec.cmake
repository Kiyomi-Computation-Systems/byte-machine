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

  if(c STREQUAL "guard-rejects-an-empty-glob")
    # A guard that finds nothing must say so. Reporting a tree it never looked
    # at as portable is worse than not guarding it, because it is reported as
    # checked.
    byte_machine_portability_guard(SHARED_DIRS "${fixture}/empty")
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
# passes on "an error happened". The wrapper case reaches past the wording to
# the file it must name, because a guard that checked the wrong directory would
# still be able to produce the first half of that sentence.

spec_expect_all_rejected("${SPEC_SELF}"
  "guard-rejects-an-empty-glob|found no shared bodies to check, which means its glob is wrong"
  "guard-rejects-a-duplicate-basename|basenames must be unique across every shared body directory, but these repeat: twin.scm"
  "guard-rejects-a-missing-wrapper|every shared test body needs a wrapper for each runtime.*unpaired-body.gambit.scm")

spec_finish("ByteMachinePortabilityGuard")
