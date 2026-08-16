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
#
# Checked against real files, because the rule is about what is on disk. The
# staging is written into the test's own temporary directory.

if(DEFINED ENV{BYTE_MACHINE_TEST_TMPDIR})
  set(fixture "$ENV{BYTE_MACHINE_TEST_TMPDIR}/guard-fixture")
else()
  set(fixture "${CMAKE_CURRENT_LIST_DIR}/../../../build/guard-fixture")
endif()
file(REMOVE_RECURSE "${fixture}")
file(MAKE_DIRECTORY "${fixture}")

file(WRITE "${fixture}/both.scm" "")
file(WRITE "${fixture}/both.chez.sps" "")
file(WRITE "${fixture}/both.gambit.scm" "")
file(WRITE "${fixture}/chez-only.scm" "")
file(WRITE "${fixture}/chez-only.chez.sps" "")
file(WRITE "${fixture}/neither.scm" "")

byte_machine_guard_missing_wrappers(missing "${fixture}/both.scm")
spec_check_equal("${missing}" "" "a body with both wrappers is complete")

byte_machine_guard_missing_wrappers(missing "${fixture}/chez-only.scm")
spec_check_equal("${missing}" "${fixture}/chez-only.scm|${fixture}/chez-only.gambit.scm"
  "a body with no Gambit wrapper is reported")

byte_machine_guard_missing_wrappers(missing "${fixture}/neither.scm")
list(LENGTH missing missing_count)
spec_check_equal("${missing_count}" "2" "a body with no wrappers reports both")

spec_finish("ByteMachinePortabilityGuard")
