# Specification for the verdict decision in
# test/support/cmake/MutationRunner.cmake.
#
# Every specification in this repository is trusted through one decision it
# never made for itself: whether a verify command's result counts as catching
# a mutation, and whether it caught it for the declared reason
# (byte_machine_mutation_verdict). That decision had no specification of its
# own -- only the suites whose own mutations it was judging, which is exactly
# the blind spot SpecSupportSpec.cmake exists to close for the two assertion
# helpers every other specification depends on. This file closes the same
# blind spot one layer down, for the runner underneath SpecSupport and every
# specification alike.
#
# A prior review deleted the branch that turns a caught-for-the-wrong-reason
# result into a failure and ran the whole CMake-layer mutation suite: 89/89,
# unaffected, because nothing mutated the mechanism that reads EXPECT_STATUS
# and EXPECT_OUTPUT_MATCHES in the first place. This file, and the mutations
# in MutationSuite.cmake that target it, are what closes that gap.

cmake_minimum_required(VERSION 3.26)

include("${CMAKE_CURRENT_LIST_DIR}/MutationRunner.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/SpecSupport.cmake")

set(SPEC_SELF "${CMAKE_CURRENT_LIST_FILE}")

if(DEFINED BYTE_MACHINE_SPEC_CASE)
  set(c "${BYTE_MACHINE_SPEC_CASE}")

  # byte_machine_mutation has no project-context dependency to stub: on
  # acceptance it only parses arguments and writes GLOBAL properties, both
  # fine under a bare `cmake -P`. Neither victim case below is ever run
  # through byte_machine_mutation_run, so FILE and SPEC name nothing real.
  if(c STREQUAL "mutation-rejects-survives-with-expect-status")
    byte_machine_mutation(
      FILE "${SPEC_SELF}" SPEC "${SPEC_SELF}"
      LABEL "victim" FIND [[x]] REPLACE [[y]]
      EXPECT_SURVIVES "a reason"
      EXPECT_STATUS 1)
  elseif(c STREQUAL "mutation-rejects-survives-with-expect-output-matches")
    byte_machine_mutation(
      FILE "${SPEC_SELF}" SPEC "${SPEC_SELF}"
      LABEL "victim" FIND [[x]] REPLACE [[y]]
      EXPECT_SURVIVES "a reason"
      EXPECT_OUTPUT_MATCHES "pattern")
  elseif(c STREQUAL "run-fails-a-wrong-reason-mutation")
    # Everything above tests byte_machine_mutation_verdict directly: pure,
    # no execute_process, no filesystem. What it cannot reach is whether
    # byte_machine_mutation_run's imperative shell actually *acts* on a
    # `wrong-reason` verdict by failing, rather than computing it correctly
    # and discarding the answer -- which is exactly the branch a re-review
    # found could be deleted by hand with the real CMake-layer suite staying
    # green, because nothing declared here mutated it. Closing that means
    # running the real thing: a real staged mutation, a real spec, and a
    # deliberately unsatisfiable EXPECT_OUTPUT_MATCHES, so whatever this
    # mutation is caught by, it is caught for the wrong reason by
    # construction -- no need to know or guess the real exit status.
    #
    # SpecSupport.cmake/SpecSupportSpec.cmake is the fixture: small, fast,
    # and already staged by BYTE_MACHINE_MUTATION_STAGE_DIRS's own default.
    # The FIND/REPLACE is the same one MutationSuite.cmake already declares
    # for "spec-support: spec_check_equal never fails" -- a real, known-caught
    # mutation reused here rather than invented, and independent of it: this
    # runs in its own staged copy under its own EXPECT_OUTPUT_MATCHES.
    if(DEFINED ENV{BYTE_MACHINE_TEST_TMPDIR})
      set(fixture_work_dir "$ENV{BYTE_MACHINE_TEST_TMPDIR}/shell-wrong-reason-check")
    else()
      get_filename_component(_fixture_source_root "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
      set(fixture_work_dir "${_fixture_source_root}/build/mutation-runner-spec-shell-check")
    endif()
    get_filename_component(fixture_source_root "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
    file(REMOVE_RECURSE "${fixture_work_dir}")

    # Narrowed to just this one directory: SpecSupportSpec.cmake includes
    # nothing from cmake/, and staging that tree too would only add cost.
    set(BYTE_MACHINE_MUTATION_STAGE_DIRS "test/support/cmake")

    byte_machine_mutation(
      FILE test/support/cmake/SpecSupport.cmake SPEC SpecSupportSpec.cmake
      LABEL "fixture: a real, known-caught mutation given an unsatisfiable EXPECT_OUTPUT_MATCHES"
      FIND [[  if(NOT actual STREQUAL expected)]]
      REPLACE [[  if(FALSE)]]
      EXPECT_OUTPUT_MATCHES "BYTE-MACHINE-SENTINEL-NEVER-PRODUCED-BY-SPECSUPPORTSPEC")

    byte_machine_mutation_run("${fixture_source_root}" "${fixture_work_dir}/stage")
    file(REMOVE_RECURSE "${fixture_work_dir}")
  else()
    message(FATAL_ERROR "byte-machine-spec: unknown case '${c}'")
  endif()

  message(FATAL_ERROR "byte-machine-spec: case '${c}' was accepted but must be rejected")
endif()

# --- byte_machine_mutation_verdict ------------------------------------------
#
# Pure: no execute_process, no filesystem. rc and output stand in for what
# byte_machine_mutation_run_spec would have returned from a real verify run;
# expect_status and expect_output_matches stand in for what a mutation
# declared.

# rc 0 is not-caught, whatever was declared. EXPECT_STATUS and
# EXPECT_OUTPUT_MATCHES narrow what a *nonzero* result has to look like to
# count; they do not manufacture a catch out of a zero exit.
byte_machine_mutation_verdict("0" "" "" "" verdict reason)
spec_check_equal("${verdict}" "not-caught" "rc 0 with nothing declared is not-caught")

byte_machine_mutation_verdict("0" "irrelevant output" "1" "irrelevant" verdict reason)
spec_check_equal("${verdict}" "not-caught"
  "rc 0 is not-caught even when EXPECT_STATUS and EXPECT_OUTPUT_MATCHES are both declared")

# Neither declared: plain nonzero-means-caught, the pre-slice-3 rule.
byte_machine_mutation_verdict("1" "" "" "" verdict reason)
spec_check_equal("${verdict}" "caught" "nonzero with neither declared is caught")

# EXPECT_STATUS declared alone.
byte_machine_mutation_verdict("2" "" "2" "" verdict reason)
spec_check_equal("${verdict}" "caught" "a satisfied EXPECT_STATUS alone is caught")

set(verdict "sentinel")
set(reason "sentinel")
byte_machine_mutation_verdict("2" "" "1" "" verdict reason)
spec_check_equal("${verdict}" "wrong-reason" "a status mismatch is wrong-reason")
spec_check_equal("${reason}" "expected the verify command to exit 1, got 2"
  "the wrong-reason message names both the expected and the actual status")

# EXPECT_OUTPUT_MATCHES declared alone.
byte_machine_mutation_verdict("1" "hello caught world" "" "caught" verdict reason)
spec_check_equal("${verdict}" "caught" "a satisfied EXPECT_OUTPUT_MATCHES alone is caught")

byte_machine_mutation_verdict("1" "hello world" "" "needle" verdict reason)
spec_check_equal("${verdict}" "wrong-reason" "an output mismatch is wrong-reason")
spec_check_equal("${reason}"
  "expected the verify command's output to match 'needle', but it did not"
  "the wrong-reason message names the pattern that did not match")

# Both declared and both satisfied: caught.
byte_machine_mutation_verdict("2" "hello caught world" "2" "caught" verdict reason)
spec_check_equal("${verdict}" "caught"
  "both EXPECT_STATUS and EXPECT_OUTPUT_MATCHES satisfied is caught")

# A satisfied EXPECT_STATUS must not excuse a failed EXPECT_OUTPUT_MATCHES.
byte_machine_mutation_verdict("2" "hello world" "2" "needle" verdict reason)
spec_check_equal("${verdict}" "wrong-reason"
  "a satisfied EXPECT_STATUS does not excuse a failed EXPECT_OUTPUT_MATCHES")

# "0" is a legitimate regex matching a literal zero, and CMake reads it as
# false. Truthiness on expect_output_matches would silently skip this case and
# report caught; only a presence test written as STREQUAL "" enforces it.
byte_machine_mutation_verdict("1" "no digits here" "" "0" verdict reason)
spec_check_equal("${verdict}" "wrong-reason"
  "an EXPECT_OUTPUT_MATCHES pattern that reads as CMake-false ('0') is still enforced")

# Seeded, so a function that writes nothing cannot satisfy the assertion by
# coincidence: an unseeded "verdict" could already hold "caught" or
# "not-caught" from an earlier call in this same process.
set(verdict "sentinel-verdict")
set(reason "sentinel-reason")
byte_machine_mutation_verdict("0" "" "" "" verdict reason)
spec_check_equal("${verdict}" "not-caught" "rc 0 overwrites a seeded verdict")
spec_check_equal("${reason}" "" "rc 0 clears a seeded reason")

set(reason "sentinel-reason")
byte_machine_mutation_verdict("1" "" "" "" verdict reason)
spec_check_equal("${reason}" "" "a plain caught verdict clears a seeded reason")

# A verify command that had to be killed for running too long comes back from
# byte_machine_mutation_run_spec as CMake's non-numeric timeout diagnostic, not an
# exit code. That is a mutation that made the program hang: neither caught nor
# not-caught, so it gets its own verdict the run surfaces by name. Seeded so a
# branch that writes nothing cannot pass by leaving an earlier call's value in place.
set(verdict "sentinel-verdict")
set(reason "sentinel-reason")
byte_machine_mutation_verdict("Process terminated due to timeout" "partial output" "" "" verdict reason)
spec_check_equal("${verdict}" "did-not-terminate"
  "a non-numeric result (a killed, non-terminating command) is neither caught nor not-caught")
spec_check_equal("${reason}" "" "a did-not-terminate verdict carries no wrong-reason detail")

# The non-numeric guard is checked first, so a killed command is did-not-terminate
# even when EXPECT_STATUS and EXPECT_OUTPUT_MATCHES were declared -- never mistaken
# for a satisfied or a mismatched expectation.
byte_machine_mutation_verdict("Timeout" "" "1" "needle" verdict reason)
spec_check_equal("${verdict}" "did-not-terminate"
  "a killed command is did-not-terminate even when expectations were declared")

# --- byte_machine_mutation: EXPECT_SURVIVES beside EXPECT_STATUS/EXPECT_OUTPUT_MATCHES ---
#
# byte_machine_mutation_run judges a declared survivor only by whether the
# verify command exited zero -- its `survives` branch checks the verdict only
# against `not-caught`. EXPECT_STATUS and EXPECT_OUTPUT_MATCHES would be
# parsed and stored for such a mutation but never read. Declaring the
# combination is refused at registration rather than silently meaning less
# than it says.
spec_expect_all_rejected("${SPEC_SELF}"
  "mutation-rejects-survives-with-expect-status|declares EXPECT_SURVIVES together with EXPECT_STATUS or EXPECT_OUTPUT_MATCHES"
  "mutation-rejects-survives-with-expect-output-matches|declares EXPECT_SURVIVES together with EXPECT_STATUS or EXPECT_OUTPUT_MATCHES")

# --- byte_machine_mutation_run: a wrong-reason verdict must cause a failure ---
#
# byte_machine_mutation_verdict computing `wrong-reason` correctly, checked
# directly above, is only half of what makes EXPECT_STATUS and
# EXPECT_OUTPUT_MATCHES mean anything: byte_machine_mutation_run has to act on
# that verdict by failing. This is the branch a re-review found undetectable
# by hand-deleting it and running the real CMake-layer suite: 89/89,
# unaffected, because nothing declared anywhere is genuinely caught for a
# different reason than the one it names. The case dispatched to above is
# built to be exactly that on purpose, so this is a real staged run, not a
# direct call: byte_machine_mutation_run is the imperative shell under test,
# and it cannot be exercised any other way.
spec_expect_rejected("${SPEC_SELF}" "run-fails-a-wrong-reason-mutation"
  "but for the wrong reason -- expected the verify command's output to match 'BYTE-MACHINE-SENTINEL-NEVER-PRODUCED-BY-SPECSUPPORTSPEC'")

spec_finish("MutationRunner")
