# byte-machine test tree.
#
# The CMake-layer specifications come first: the build's own discovery and
# registration logic decides what every later lane can even see.

# The registration helper decides which tests exist at all, so its functional
# core is specified before anything relies on it.
byte_machine_add_test(
  NAME byte-machine.harness.cmake-testing.cmake.direct
  COMMAND "${CMAKE_COMMAND}" -P
          "${CMAKE_CURRENT_LIST_DIR}/support/cmake/ByteMachineTestingSpec.cmake"
  TIMEOUT 120
  LABELS unit)

# Runtime discovery reads key=value probe output. Reading it wrong yields a
# plausible answer rather than an error, so the accessor is specified before
# either runtime module relies on it.
byte_machine_add_test(
  NAME byte-machine.harness.cmake-probe.cmake.direct
  COMMAND "${CMAKE_COMMAND}" -P
          "${CMAKE_CURRENT_LIST_DIR}/support/cmake/ByteMachineProbeSpec.cmake"
  TIMEOUT 120
  LABELS unit)

# Chez discovery must reject Petite, which cannot run the ahead-of-time lane,
# and must not mistake an unrelated `scheme` on PATH for Chez.
byte_machine_add_test(
  NAME byte-machine.harness.cmake-chez.cmake.direct
  COMMAND "${CMAKE_COMMAND}" -P
          "${CMAKE_CURRENT_LIST_DIR}/support/cmake/ByteMachineChezSpec.cmake"
  TIMEOUT 120
  LABELS unit)

# Every assertion in every specification above routes through SpecSupport, so a
# silent break there would leave all of them green while checking nothing. This
# is the only specification that may not use the helpers it tests.
byte_machine_add_test(
  NAME byte-machine.harness.cmake-spec-support.cmake.direct
  COMMAND "${CMAKE_COMMAND}" -P
          "${CMAKE_CURRENT_LIST_DIR}/support/cmake/SpecSupportSpec.cmake"
  TIMEOUT 120
  LABELS unit)

# byte_machine_mutation_verdict decides whether a mutation was caught, and for
# the declared reason -- the decision every specification in this tree is
# ultimately trusted through, including the mutation suite below, which
# mutates it. Specified here, immediately before that suite, for the same
# reason SpecSupportSpec precedes it: a mutation against machinery a proof
# depends on must not be judged by the very thing it just broke.
byte_machine_add_test(
  NAME byte-machine.harness.cmake-mutation-runner.cmake.direct
  COMMAND "${CMAKE_COMMAND}" -P
          "${CMAKE_CURRENT_LIST_DIR}/support/cmake/MutationRunnerSpec.cmake"
  TIMEOUT 120
  LABELS unit)

# A passing specification proves nothing by itself. This breaks each decision in
# each module in turn, on a staged copy, and requires the owning specification to
# notice. It runs under `ctest` because evidence that only exists in someone's
# terminal cannot fail when the code changes.
byte_machine_add_test(
  NAME byte-machine.harness.cmake-mutation.cmake.direct
  COMMAND "${CMAKE_COMMAND}" -P
          "${CMAKE_CURRENT_LIST_DIR}/support/cmake/MutationSuite.cmake"
  TIMEOUT 600
  LABELS unit)

# The exact-status assertion decides whether every expected-red test below is
# checking anything at all, so its functional core is specified before any of
# them relies on it.
byte_machine_add_test(
  NAME byte-machine.harness.cmake-expect-exit.cmake.direct
  COMMAND "${CMAKE_COMMAND}" -P
          "${CMAKE_CURRENT_LIST_DIR}/support/cmake/ByteMachineExpectExitSpec.cmake"
  TIMEOUT 120
  LABELS unit)

# A lane's command line decides whether a source lane is really a source lane.
# Specified before any lane is registered against it.
byte_machine_add_test(
  NAME byte-machine.harness.cmake-scheme-lane.cmake.direct
  COMMAND "${CMAKE_COMMAND}" -P
          "${CMAKE_CURRENT_LIST_DIR}/support/cmake/ByteMachineSchemeLaneSpec.cmake"
  TIMEOUT 120
  LABELS unit)

# --- Harness paths ---------------------------------------------------------

set(BYTE_MACHINE_HARNESS_DIR "${CMAKE_CURRENT_LIST_DIR}/support/harness")
set(BYTE_MACHINE_HARNESS_SELF_DIR "${BYTE_MACHINE_HARNESS_DIR}/self")
set(BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT "${BYTE_MACHINE_HARNESS_DIR}")
set(BYTE_MACHINE_HARNESS_CHEZ_LAUNCHER
    "${CMAKE_CURRENT_LIST_DIR}/support/launchers/chez-source.ss")

# Per-runtime, per-machine object roots for the AOT lane. Keyed this way so a
# parallel build cannot race and an object built by one Chez is never loaded by
# another; nothing is written into the source tree.
set(BYTE_MACHINE_CHEZ_OBJECT_ROOT
    "${CMAKE_BINARY_DIR}/chez-objects/${BYTE_MACHINE_CHEZ_VERSION}/${BYTE_MACHINE_CHEZ_MACHINE_TYPE}")
# The keying above is only as real as these two variables. Empty, every Chez
# version and every machine type would share one object root, a `.so` built by
# a different Chez could be loaded as though it were current, and every AOT
# lane would stay green while proving nothing about the runtime that actually
# ran it -- the exact defect the keyed roots exist to prevent. Nothing else
# re-derives BYTE_MACHINE_CHEZ_VERSION or BYTE_MACHINE_CHEZ_MACHINE_TYPE to
# catch a regression here, so this is the one place that can. Guarded on
# BYTE_MACHINE_CHEZ_EXECUTABLE: on a host with no Chez neither variable is
# ever set, no AOT lane is registered, and an empty root is inert rather than
# a keying failure.
if(BYTE_MACHINE_CHEZ_EXECUTABLE)
  if(NOT BYTE_MACHINE_CHEZ_VERSION OR NOT BYTE_MACHINE_CHEZ_MACHINE_TYPE)
    message(FATAL_ERROR
      "byte-machine: BYTE_MACHINE_CHEZ_VERSION ('${BYTE_MACHINE_CHEZ_VERSION}') "
      "and BYTE_MACHINE_CHEZ_MACHINE_TYPE ('${BYTE_MACHINE_CHEZ_MACHINE_TYPE}') "
      "must both be non-empty once a Chez has been discovered. They key "
      "BYTE_MACHINE_CHEZ_OBJECT_ROOT so a compiled object can never outlive "
      "the runtime that produced it; empty, every AOT lane would share one "
      "root across every Chez version and machine type ever built here, and a "
      "stale object could load silently while every lane stayed green.")
  endif()
endif()
set(BYTE_MACHINE_HARNESS_CHEZ_AOT_LAUNCHER
    "${CMAKE_CURRENT_LIST_DIR}/support/launchers/chez-aot.ss")
set(BYTE_MACHINE_HARNESS_CHEZ_COMPILE_LAUNCHER
    "${CMAKE_CURRENT_LIST_DIR}/support/launchers/chez-compile.ss")

# The object guard is what makes the Chez source lane honest: Chez looks for a
# compiled library only in the object half of a library-directories pair, so
# pairing the source root with a directory that is always empty makes a stale
# .so unloadable. It lives in the build tree precisely because nothing may ever
# be written into it.
set(BYTE_MACHINE_HARNESS_OBJECT_GUARD_DIR "${CMAKE_BINARY_DIR}/chez-object-guard")
file(MAKE_DIRECTORY "${BYTE_MACHINE_HARNESS_OBJECT_GUARD_DIR}")

# --- Source tree paths -----------------------------------------------------
#
# Read by byte_machine_scheme_lane_command. src/ holds the product libraries;
# the harness above is test infrastructure. A lane imports from both, which is
# why the launcher takes repeatable roots.
set(BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT "${CMAKE_SOURCE_DIR}/src")
set(BYTE_MACHINE_TEST_COMMON_DIR "${CMAKE_CURRENT_LIST_DIR}/common")

# The sources every harness lane executes -- the two libraries; each lane
# appends its own program. Named once: a lane that listed them itself would
# drift, and a manifest that drifts is one that quietly stops describing the
# run.
set(BYTE_MACHINE_HARNESS_MANIFEST
    "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/fingerprint.sls"
    "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/harness.sls")

# Semantic-core libraries. Defined here beside the harness manifest so every
# semantic-core lane below can name the exact .sls set it loads; each fragment
# grows the previous one in dependency order, mirroring the library dependency
# direction: private conditions ← private ir.
# names.sls (the one portable-name grammar) imports only
# (rnrs) and is imported by verify.sls, compile.sls and runtime.sls; it sits
# beside conditions.sls in both leaf fragments so every AOT lane compiles it
# before anything that imports it.
set(BYTE_MACHINE_CORE_PRIVATE
    "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}/byte-machine/private/conditions.sls"
    "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}/byte-machine/private/names.sls"
    "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}/byte-machine/private/ir.sls")

# --- Build-time fingerprint expectations -----------------------------------

set(BYTE_MACHINE_FINGERPRINT_LAUNCHER
    "${CMAKE_CURRENT_LIST_DIR}/support/launchers/fingerprint-manifest.ss")
set(BYTE_MACHINE_FINGERPRINT_DIR "${CMAKE_BINARY_DIR}/fingerprints")

# byte_machine_expected_fingerprint(<name> <out_var> <source>...)
#
# Produce, at build time, the combined fingerprint the named lane must report,
# and set <out_var> to the file holding it.
#
# A build output rather than a configure-time value, because a registration's
# environment is fixed when CMake configures and this must be recomputed
# whenever a source changes -- which is precisely the case it exists to catch.
# The DEPENDS list is what makes that true, so a source added to a manifest
# without being added there produces an expectation that silently never
# refreshes.
#
# Keyed by a digest of the manifest, not by lane name: the value depends only on
# the manifest, and keying by name would spawn one Chez process per lane to
# produce a handful of distinct answers while hiding which lanes claim to run
# the same text.
function(byte_machine_expected_fingerprint name out_var)
  if(NOT ARGN)
    message(FATAL_ERROR
      "byte-machine: '${name}' asked for a fingerprint expectation over no "
      "sources. An empty manifest fingerprints to the seed on every lane, "
      "which would compare equal forever and check nothing.")
  endif()

  string(JOIN "|" manifest ${ARGN})
  string(SHA256 manifest_digest "${manifest}")
  string(SUBSTRING "${manifest_digest}" 0 16 manifest_key)
  set(expect_file "${BYTE_MACHINE_FINGERPRINT_DIR}/${manifest_key}.fingerprint")

  # add_custom_command rejects a second rule for the same OUTPUT, so the first
  # lane to need a manifest creates the rule and the rest reuse it.
  get_property(known GLOBAL PROPERTY BYTE_MACHINE_FINGERPRINT_MANIFESTS)
  if(NOT manifest_key IN_LIST known)
    set_property(GLOBAL APPEND PROPERTY BYTE_MACHINE_FINGERPRINT_MANIFESTS
                 "${manifest_key}")

    add_custom_command(
      OUTPUT "${expect_file}"
      COMMAND "${CMAKE_COMMAND}" -E make_directory "${BYTE_MACHINE_FINGERPRINT_DIR}"
      COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}" --script
              "${BYTE_MACHINE_FINGERPRINT_LAUNCHER}"
              "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}"
              "${BYTE_MACHINE_HARNESS_OBJECT_GUARD_DIR}"
              "${expect_file}"
              ${ARGN}
      DEPENDS ${ARGN}
              "${BYTE_MACHINE_FINGERPRINT_LAUNCHER}"
              "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/fingerprint.sls"
      COMMENT "byte-machine: fingerprint manifest ${manifest_key} (first needed by ${name})"
      VERBATIM)

    add_custom_target("byte_machine_fingerprint_${manifest_key}"
                      DEPENDS "${expect_file}")
    if(NOT TARGET byte_machine_fingerprints)
      add_custom_target(byte_machine_fingerprints ALL)
    endif()
    add_dependencies(byte_machine_fingerprints
                     "byte_machine_fingerprint_${manifest_key}")
  endif()

  set(${out_var} "${expect_file}" PARENT_SCOPE)
endfunction()

# A deliberately wrong expectation, so the provenance check is proved to fire by
# a registered lane rather than by editing a build artifact during a mutation
# gate. It is not a fingerprint of anything and cannot become one: every real
# value is lowercase hex, so no manifest can ever produce this text.
function(byte_machine_wrong_fingerprint name out_var)
  set(expect_file "${BYTE_MACHINE_FINGERPRINT_DIR}/${name}.wrong")
  file(MAKE_DIRECTORY "${BYTE_MACHINE_FINGERPRINT_DIR}")
  file(WRITE "${expect_file}" "not-a-fingerprint")
  set(${out_var} "${expect_file}" PARENT_SCOPE)
endfunction()

# --- Harness lanes ---------------------------------------------------------

# The harness must be able to fail before it can be trusted to pass. This is
# that proof: a program that fails one assertion, with the exact status
# compared from outside, because a program cannot report its own exit status.
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.failing-body.chez.source
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-failing.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-failing.sps"
  EXPECT_EXIT 1
  TIMEOUT 120
  LABELS expected-red)

# The runner cannot be its own only witness. This judges its primitives with
# raw conditionals, using none of the facilities it is checking.
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.bootstrap.chez.source
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-bootstrap.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-bootstrap.sps"
  TIMEOUT 120)

# The runner tested with the runner. Safe only because the bootstrap already
# established its primitives, and because every deliberate failure here runs
# inside a probe.
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.self.chez.source
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.sps"
  TIMEOUT 120)

# A duplicate id is a defect in the suite, not a failing assertion: one
# registration silently became unreachable. Status 2, distinct from 1.
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.duplicate-case.chez.source
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-duplicate-case.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-duplicate-case.sps"
  EXPECT_EXIT 2
  TIMEOUT 120
  LABELS expected-red)

# A suite that selected nothing must not report success, for the same reason
# the presets refuse an empty CTest selection one layer up.
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.empty-selection.chez.source
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-empty-selection.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-empty-selection.sps"
  EXPECT_EXIT 2
  TIMEOUT 120
  LABELS expected-red
  ENVIRONMENT "BYTE_MACHINE_TEST_FILTER=no-case-has-this-in-its-name")

# --- The verbose pass line -------------------------------------------------
#
# BYTE_MACHINE_TEST_VERBOSE makes the runner announce every passing case.
# Nothing else in this tree sets it, so without this lane the feature would
# never be executed by any test at all: the environment read, the empty-string
# rule, and the print itself would first run for whoever turned the variable on,
# and a typo in any of them would surface there rather than here.
#
# One registration is enough: the decision lives in the runner section of
# harness.sls, which reads nothing runtime-specific to make it, so a second lane
# would not exercise a different code path -- the same argument the mutation
# suite's first pass makes for every other decision in it.
#
# What this lane cannot check is that the line was printed. The adapter
# protocol exposes no output-capture service, and the runner may not reach past
# its protocol for one -- so it has no way to read back its own output, and the
# registration layer asserts exit status, not output. Both decisions are
# therefore declared survivors in SchemeMutationSuite.cmake with their reason
# recorded, alongside probe output suppression, which is unwitnessable for
# exactly the same reason.
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.verbose.chez.source
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.sps"
  TIMEOUT 120
  ENVIRONMENT "BYTE_MACHINE_TEST_VERBOSE=1")

# --- The Chez launcher's refusals ------------------------------------------
#
# The launcher decides whether a lane runs at all, and its object guard is the
# sole mechanism that makes `mode=source` an honest claim. A healthy lane never
# reaches a refusal, so without these lanes every decision in the launcher
# could be deleted, and a file dropped into the guard directory, with every
# other test still green.
#
# One lane per `die` path, each asserting status 2 exactly. Registered through
# the exact-status helper directly rather than through
# byte_machine_add_scheme_lane, whose whole purpose is to build the one correct
# command line; these three need deliberately wrong ones. Guarded on a
# discovered Chez the same way the mutation suite below is, so
# `ctest --preset no-scheme` stays green on a host with no Scheme runtime.
if(BYTE_MACHINE_CHEZ_EXECUTABLE)
  # A guard directory that has acquired a file is no longer a guard. The file is
  # written into the build tree rather than committed: a file checked into the
  # source tree solely to make a directory non-empty is one every future glob,
  # packaging step, and reader has to be told to ignore.
  set(BYTE_MACHINE_HARNESS_DIRTY_GUARD_DIR
      "${CMAKE_BINARY_DIR}/chez-object-guard-dirty")
  file(MAKE_DIRECTORY "${BYTE_MACHINE_HARNESS_DIRTY_GUARD_DIR}")
  file(WRITE "${BYTE_MACHINE_HARNESS_DIRTY_GUARD_DIR}/stray-object.so"
    "Not a compiled library. Its only job is to stop this directory being empty,\n"
    "so byte-machine.harness.launcher-dirty-guard.chez.source can prove the\n"
    "launcher refuses a guard directory that has acquired a file.\n")

  # Deliberately never created. The launcher must refuse a guard directory that
  # is not there rather than assume it, since `directory-list` on a missing path
  # raises and would report a crash where a named harness error belongs.
  set(BYTE_MACHINE_HARNESS_ABSENT_GUARD_DIR
      "${CMAKE_BINARY_DIR}/chez-object-guard-absent")

  # A launcher invoked with nothing at all. Replaces the exact-arity refusal the
  # positional protocol had; with flags, "no arguments" is the natural form of
  # the same mistake.
  byte_machine_add_exit_code_test(
    NAME byte-machine.harness.launcher-no-program.chez.source
    COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
            "--script" "${BYTE_MACHINE_HARNESS_CHEZ_LAUNCHER}"
    EXPECT_EXIT 2
    TIMEOUT 120
    LABELS expected-red)

  byte_machine_add_exit_code_test(
    NAME byte-machine.harness.launcher-absent-guard.chez.source
    COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
            "--script" "${BYTE_MACHINE_HARNESS_CHEZ_LAUNCHER}"
            "--library-root" "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}"
            "--object-guard" "${BYTE_MACHINE_HARNESS_ABSENT_GUARD_DIR}"
            "--program" "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-bootstrap.sps"
    EXPECT_EXIT 2
    TIMEOUT 120
    LABELS expected-red
    ENVIRONMENT "BYTE_MACHINE_EXECUTION_MODE=source")

  byte_machine_add_exit_code_test(
    NAME byte-machine.harness.launcher-dirty-guard.chez.source
    COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
            "--script" "${BYTE_MACHINE_HARNESS_CHEZ_LAUNCHER}"
            "--library-root" "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}"
            "--object-guard" "${BYTE_MACHINE_HARNESS_DIRTY_GUARD_DIR}"
            "--program" "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-bootstrap.sps"
    EXPECT_EXIT 2
    TIMEOUT 120
    LABELS expected-red
    ENVIRONMENT "BYTE_MACHINE_EXECUTION_MODE=source")

  # One lane per parse decision. A correctly set-up lane never reaches a
  # refusal, so nothing else in this tree can notice one being deleted. Each
  # names a real program where it can, so that deleting the refusal produces a
  # lane that runs and exits 0 rather than one that fails for another reason.
  byte_machine_add_exit_code_test(
    NAME byte-machine.harness.launcher-unknown-flag.chez.source
    COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
            "--script" "${BYTE_MACHINE_HARNESS_CHEZ_LAUNCHER}"
            "--library-root" "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}"
            "--object-guard" "${BYTE_MACHINE_HARNESS_OBJECT_GUARD_DIR}"
            "--librarie-root" "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}"
            "--program" "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-bootstrap.sps"
    EXPECT_EXIT 2
    TIMEOUT 120
    LABELS expected-red
    ENVIRONMENT "BYTE_MACHINE_EXECUTION_MODE=source")

  # A trailing flag. Without this refusal it would mean "no program" and be
  # reported as a missing required flag, sending the reader to the wrong line.
  byte_machine_add_exit_code_test(
    NAME byte-machine.harness.launcher-missing-value.chez.source
    COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
            "--script" "${BYTE_MACHINE_HARNESS_CHEZ_LAUNCHER}"
            "--library-root" "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}"
            "--object-guard" "${BYTE_MACHINE_HARNESS_OBJECT_GUARD_DIR}"
            "--program"
    EXPECT_EXIT 2
    TIMEOUT 120
    LABELS expected-red)

  byte_machine_add_exit_code_test(
    NAME byte-machine.harness.launcher-repeated-flag.chez.source
    COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
            "--script" "${BYTE_MACHINE_HARNESS_CHEZ_LAUNCHER}"
            "--library-root" "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}"
            "--object-guard" "${BYTE_MACHINE_HARNESS_OBJECT_GUARD_DIR}"
            "--program" "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-bootstrap.sps"
            "--program" "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.sps"
    EXPECT_EXIT 2
    TIMEOUT 120
    LABELS expected-red
    ENVIRONMENT "BYTE_MACHINE_EXECUTION_MODE=source")

  # The lane above witnesses the single-valued-flag check only through
  # --program; --object-guard has never been exercised as a repeated flag.
  # Both occurrences name the same real, empty guard directory -- the check
  # counts occurrences, not distinct values, so that is enough to trigger it.
  byte_machine_add_exit_code_test(
    NAME byte-machine.harness.launcher-repeated-object-guard.chez.source
    COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
            "--script" "${BYTE_MACHINE_HARNESS_CHEZ_LAUNCHER}"
            "--library-root" "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}"
            "--object-guard" "${BYTE_MACHINE_HARNESS_OBJECT_GUARD_DIR}"
            "--object-guard" "${BYTE_MACHINE_HARNESS_OBJECT_GUARD_DIR}"
            "--program" "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-bootstrap.sps"
    EXPECT_EXIT 2
    TIMEOUT 120
    LABELS expected-red
    ENVIRONMENT "BYTE_MACHINE_EXECUTION_MODE=source")

  # The three remaining required-flag entries. Each is a separate lane because
  # required-flags is a list: an entry dropped from it is invisible to every
  # lane but the one that omits that flag.
  byte_machine_add_exit_code_test(
    NAME byte-machine.harness.launcher-no-library-root.chez.source
    COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
            "--script" "${BYTE_MACHINE_HARNESS_CHEZ_LAUNCHER}"
            "--object-guard" "${BYTE_MACHINE_HARNESS_OBJECT_GUARD_DIR}"
            "--program" "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-bootstrap.sps"
    EXPECT_EXIT 2
    TIMEOUT 120
    LABELS expected-red
    ENVIRONMENT "BYTE_MACHINE_EXECUTION_MODE=source")

  byte_machine_add_exit_code_test(
    NAME byte-machine.harness.launcher-no-object-guard.chez.source
    COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
            "--script" "${BYTE_MACHINE_HARNESS_CHEZ_LAUNCHER}"
            "--library-root" "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}"
            "--program" "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-bootstrap.sps"
    EXPECT_EXIT 2
    TIMEOUT 120
    LABELS expected-red
    ENVIRONMENT "BYTE_MACHINE_EXECUTION_MODE=source")
endif()

# A lane that is set up correctly never reaches a launcher refusal, so each one
# needs a lane of its own or a deleted refusal is invisible. The same argument
# the nine chez-source.ss refusals above are registered under.
#
# Three lanes, not one per refusal in these files. The flag-vocabulary
# refusals below the parser, and --source-guard's own absent-directory check,
# are the same shape as refusals chez-source.ss already carries and already
# has lanes for; re-proving a verbatim shape in a new file buys nothing. These
# three are what is actually new here: chez-aot.ss's missing-program check,
# chez-compile.ss's unpaired-roots check, and --source-guard's non-empty-guard
# check -- the one that most directly proves the hazard the flag exists to
# close.
if(BYTE_MACHINE_CHEZ_EXECUTABLE)
  byte_machine_add_exit_code_test(
    NAME byte-machine.harness.chez-aot-launcher-missing-program.chez.aot
    COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}" --script
            "${BYTE_MACHINE_HARNESS_CHEZ_AOT_LAUNCHER}"
            --object-dir "${CMAKE_BINARY_DIR}"
            --source-guard "${BYTE_MACHINE_HARNESS_OBJECT_GUARD_DIR}"
            --program "${CMAKE_BINARY_DIR}/no-such-program.so"
    EXPECT_EXIT 2
    TIMEOUT 60
    LABELS expected-red)

  byte_machine_add_exit_code_test(
    NAME byte-machine.harness.chez-compile-launcher-unpaired-roots.chez.aot
    COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}" --script
            "${BYTE_MACHINE_HARNESS_CHEZ_COMPILE_LAUNCHER}"
            --library-root "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}"
            --library-root "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}"
            --object-dir "${CMAKE_BINARY_DIR}"
            --program "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-bootstrap.sps"
            --output "${CMAKE_BINARY_DIR}/unused.so"
    EXPECT_EXIT 2
    TIMEOUT 60
    LABELS expected-red)

  # The one new decision --source-guard's own checks add over chez-source.ss's
  # object-guard shape: chez-source.ss's launcher-dirty-guard.chez.source lane
  # already proves this die branch works when a guard has acquired a file, but
  # only for chez-source.ss's own copy of the check. Reuses
  # BYTE_MACHINE_HARNESS_DIRTY_GUARD_DIR rather than declaring a second dirty
  # directory: both are the same fixture -- a build-tree directory holding one
  # stray file for the sole purpose of not being empty.
  byte_machine_add_exit_code_test(
    NAME byte-machine.harness.chez-aot-launcher-dirty-source-guard.chez.aot
    COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}" --script
            "${BYTE_MACHINE_HARNESS_CHEZ_AOT_LAUNCHER}"
            --object-dir "${CMAKE_BINARY_DIR}"
            --source-guard "${BYTE_MACHINE_HARNESS_DIRTY_GUARD_DIR}"
            --program "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-bootstrap.sps"
    EXPECT_EXIT 2
    TIMEOUT 60
    LABELS expected-red)
endif()

# --- Chez ahead-of-time lanes ----------------------------------------------
#
# Two of the programs the source lanes run, compiled. Nothing about the
# sources changes; what changes is that the text reaching the process came
# out of objects built earlier, which is why these lanes measure the copies
# the compile step kept rather than the repository sources. Two lanes, not
# one per source lane: bootstrap (the runner's primitives with no runner)
# and self (the runner on itself).
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.bootstrap.chez.aot
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-bootstrap.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-bootstrap.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.harness.self.chez.aot
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.sps"
  TIMEOUT 120)

# --- Mutation proof for the harness ----------------------------------------

# The harness is the instrument everything else is measured with, so a
# passing self-test suite is not evidence until something has proved it can
# fail. This breaks each decision in the runner on a staged copy and requires
# the self-tests to notice. Registered only when a Chez was discovered: it runs
# a real lane and cannot be verified under the no-scheme preset.
#
# The self-tests load the fingerprint fixture through adapter-file-bytes; staged
# lanes inherit this process's environment through execute_process, so the
# variable must be set here. The determinism passes read their committed
# goldens the same way, through the BYTE_MACHINE_*_GOLDEN_FILE variables, so
# those are set here too rather than inside SchemeMutationSuite.cmake -- the
# same mechanism, for the same reason, as BYTE_MACHINE_FINGERPRINT_SAMPLE.
# Without one, that pass's BASELINE fails, and a failing baseline reads as a
# mutation defect rather than as the missing environment it is: a red BASELINE
# that names neither the variable nor the lane. Add a golden's variable here
# before its pass exists, not after.
# This is one ctest entry that runs the whole mutation suite (~5 min), and ctest
# buffers a single test's output until it finishes -- so on a plain run this line
# sits silent for minutes, which is easy to mistake for a hang. To watch it work,
# run `make test-mutation` (or `ctest --preset release -V -R scheme-mutation`),
# which streams SchemeMutationSuite's per-pass progress live. The TIMEOUT below is
# the whole-lane ceiling; MutationRunner bounds each individual mutation with its
# own per-command timeout, so one non-terminating mutation fails by name rather
# than consuming this budget in silence.
if(BYTE_MACHINE_CHEZ_EXECUTABLE)
  byte_machine_add_test(
    NAME byte-machine.harness.scheme-mutation.cmake.direct
    COMMAND "${CMAKE_COMMAND}"
            "-DBYTE_MACHINE_CHEZ_EXECUTABLE=${BYTE_MACHINE_CHEZ_EXECUTABLE}"
            -P "${CMAKE_CURRENT_LIST_DIR}/support/cmake/SchemeMutationSuite.cmake"
    TIMEOUT 900
    LABELS unit
    ENVIRONMENT "BYTE_MACHINE_EXECUTION_MODE=source"
                "BYTE_MACHINE_FINGERPRINT_SAMPLE=${CMAKE_SOURCE_DIR}/test/fixtures/fingerprint-sample.bin"
                "BYTE_MACHINE_GOLDEN_FILE=${CMAKE_SOURCE_DIR}/test/fixtures/generated-one-byte.golden.sls"
                "BYTE_MACHINE_HTTP_VERSION_GOLDEN_FILE=${CMAKE_SOURCE_DIR}/test/fixtures/generated-http-version.golden.sls"
                "BYTE_MACHINE_ACCUMULATE_GOLDEN_FILE=${CMAKE_SOURCE_DIR}/test/fixtures/generated-accumulate.golden.sls"
                "BYTE_MACHINE_COUNTED_GOLDEN_FILE=${CMAKE_SOURCE_DIR}/test/fixtures/generated-counted.golden.sls"
                # The keyword-table determinism pass reads
                # its committed golden the same way, so the ABI-literal mutation's
                # baseline is green rather than a missing-env failure.
                "BYTE_MACHINE_KEYWORD_TABLE_GOLDEN_FILE=${CMAKE_SOURCE_DIR}/test/fixtures/generated-keyword-table.golden.sls")
endif()

# --- Provenance ------------------------------------------------------------
#
# Every lane above checks the fingerprint of the text it ran against the value
# the build computed. These prove that check can fail. Without them the
# mechanism would be a claim: two lanes can print different digests for text
# both say they ran, and the suite stays green if nothing reads the values
# back.
#
# Status 3 is what makes them falsifiable. Several lanes in this tree
# legitimately expect 1 or 2, so a provenance failure sharing either status
# would be indistinguishable from those fixtures' own expected outcomes.
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.provenance.chez.source
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.sps"
  WRONG_FINGERPRINT
  EXPECT_EXIT 3
  TIMEOUT 120
  LABELS expected-red)

# Two more refusals. Neither is wrapped in if(BYTE_MACHINE_CHEZ_EXECUTABLE):
# each is a BACKEND chez lane, so byte_machine_add_scheme_lane's own
# no-runtime return already skips it on a Chez-less host, the same mechanism
# that skips the lane above.

# The build never produced this file, and never will: no rule names it as an
# output. That is the "you did not build before running the tests" case, which
# would otherwise escape as a raw I/O condition and a status outside the
# vocabulary.
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.provenance-absent-expectation.chez.source
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.sps"
  EXPECT_EXIT 3
  TIMEOUT 120
  LABELS expected-red
  ENVIRONMENT "BYTE_MACHINE_EXPECT_FINGERPRINT_FILE=${CMAKE_BINARY_DIR}/fingerprints/never-produced.fingerprint")

# A manifest naming a source that is not there. What fails is reading the text,
# before any comparison happens.
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.provenance-missing-body.chez.source
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.sps"
  EXPECT_EXIT 3
  TIMEOUT 120
  LABELS expected-red
  ENVIRONMENT "BYTE_MACHINE_FINGERPRINT_FILES=${CMAKE_BINARY_DIR}/fingerprints/no-such-body.scm")

# Provenance configured and never performed. SOURCES guarantees the environment
# carries a manifest; this lane guarantees something reads it. This program
# reaches harness-summary without ever reaching harness-verify-provenance!,
# which is precisely the shape harness-bootstrap would have had if its
# hand-placed call had been forgotten -- and that would have run un-provenanced
# with nothing failing.
#
# A real manifest, deliberately: with none, the run is a process no lane
# registration started, and skipping is correct rather than a defect.
#
# Not wrapped in if(BYTE_MACHINE_CHEZ_EXECUTABLE): this is a BACKEND chez
# lane, so byte_machine_add_scheme_lane's own no-runtime return already skips
# it on a Chez-less host.
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.unreached-provenance.chez.source
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-unreached-provenance.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-unreached-provenance.sps"
  EXPECT_EXIT 3
  TIMEOUT 120
  LABELS expected-red)

# An artifact built from text this registration does not declare. The
# expectation comes from the real harness.sls; the compile step resolves
# (byte-machine test harness) from a divergent fixture copy instead and
# keeps that copy as what the run measures. The two disagree, so the lane
# exits 3. This is the only lane in the tree that can fail when a compiled
# lane's fingerprint stops describing its artifact -- a lane rather than a
# mutation because the Scheme mutation suite stages one already-mutated
# tree per pass and cannot express "built before the edit, run after it".
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.stale-artifact.chez.aot
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.sps"
  STALE_LIBRARY_ROOT "${CMAKE_CURRENT_LIST_DIR}/fixtures/stale-root"
  EXPECT_EXIT 3
  TIMEOUT 120
  LABELS expected-red)

# --- Semantic core ---------------------------------------------------------
#
# The in-memory pipeline for the one-byte machine, proven through the reference
# interpreter across all 256 byte values. Each feature owns a source and an AOT
# lane; the SOURCES manifest names every .sls the program loads plus the program
# itself, and basenames are unique within a lane. The core manifest fragments
# (BYTE_MACHINE_CORE_PRIVATE and its successors) are defined beside the harness
# manifest above and here, in dependency order.

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.ir.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/ir-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_PRIVATE}
          "${CMAKE_SOURCE_DIR}/test/common/ir-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.ir.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/ir-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_PRIVATE}
          "${CMAKE_SOURCE_DIR}/test/common/ir-tests.sps"
  TIMEOUT 120)

# The public construction façade re-exports the private ir constructors.
set(BYTE_MACHINE_CORE_GRAPH
    ${BYTE_MACHINE_CORE_PRIVATE}
    "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}/byte-machine/graph.sls")

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.graph.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/graph-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_GRAPH}
          "${CMAKE_SOURCE_DIR}/test/common/graph-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.graph.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/graph-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_GRAPH}
          "${CMAKE_SOURCE_DIR}/test/common/graph-tests.sps"
  TIMEOUT 120)

# The runtime depends on (byte-machine private conditions) for coded API
# contract conditions; conditions.sls imports only (rnrs), so no
# cycle. It is listed first so the AOT lane compiles it before runtime.sls.
set(BYTE_MACHINE_CORE_RUNTIME
    "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}/byte-machine/private/conditions.sls"
    "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}/byte-machine/private/names.sls"
    "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}/byte-machine/runtime.sls")

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.runtime.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/runtime-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_RUNTIME}
          "${CMAKE_SOURCE_DIR}/test/common/runtime-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.runtime.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/runtime-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_RUNTIME}
          "${CMAKE_SOURCE_DIR}/test/common/runtime-tests.sps"
  TIMEOUT 120)

# The verifier reads the IR through the graph façade's constructors.
set(BYTE_MACHINE_CORE_VERIFY
    ${BYTE_MACHINE_CORE_GRAPH}
    "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}/byte-machine/verify.sls")

byte_machine_add_scheme_lane(
  NAME byte-machine.verify.rejections.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/verify-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_VERIFY}
          "${CMAKE_SOURCE_DIR}/test/common/verify-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.verify.rejections.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/verify-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_VERIFY}
          "${CMAKE_SOURCE_DIR}/test/common/verify-tests.sps"
  TIMEOUT 120)

# The interpreter closes an op over the verified IR and hands it to the runtime,
# so its manifest unites the verify and runtime cores with interpret.sls.
set(BYTE_MACHINE_CORE_ALL
    ${BYTE_MACHINE_CORE_VERIFY}
    ${BYTE_MACHINE_CORE_RUNTIME}
    "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}/byte-machine/interpret.sls")

# conditions.sls reaches CORE_ALL twice — once via CORE_VERIFY's ir manifest,
# once via CORE_RUNTIME — and names.sls reaches it twice by the
# same two routes. REMOVE_DUPLICATES keeps the first (early,
# before ir.sls) occurrence, so load/compile order stays conditions -> names ->
# ir -> ... -> runtime -> interpret, and the per-lane duplicate-basename guard
# stays green.
list(REMOVE_DUPLICATES BYTE_MACHINE_CORE_ALL)

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.interpret.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/interpret-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_ALL}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/eof-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/interpret-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.interpret.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/interpret-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_ALL}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/eof-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/interpret-tests.sps"
  TIMEOUT 120)

# The shared idle-vs-truncation proving machine (built only through
# (byte-machine graph), reused by the EOF interpreter≡generated differential)
# driven exhaustively through the
# interpreter's parser-finish!/eof-target path.
byte_machine_add_scheme_lane(
  NAME byte-machine.unit.eof-interpret.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/eof-interpret-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_ALL}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/eof-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/eof-interpret-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.eof-interpret.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/eof-interpret-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_ALL}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/eof-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/eof-interpret-tests.sps"
  TIMEOUT 120)

# The shared pause/resume proving machine driven through
# the interpreter's pause arms and the runtime's paused-feed/paused-finish/
# finish-ready lifecycle.
byte_machine_add_scheme_lane(
  NAME byte-machine.unit.pause-interpret.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/pause-interpret-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_ALL}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/pause-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/pause-interpret-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.pause-interpret.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/pause-interpret-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_ALL}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/pause-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/pause-interpret-tests.sps"
  TIMEOUT 120)

# --- Normalizer ------------------------------------------------------------
set(BYTE_MACHINE_CORE_NORMAL_IR
    ${BYTE_MACHINE_CORE_VERIFY}
    "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}/byte-machine/private/normal-ir.sls")

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.normal-ir.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/normal-ir-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_NORMAL_IR}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/eof-machine.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/pause-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/normal-ir-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.normal-ir.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/normal-ir-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_NORMAL_IR}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/eof-machine.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/pause-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/normal-ir-tests.sps"
  TIMEOUT 120)

# --- Emitter ---------------------------------------------------------------
set(BYTE_MACHINE_CORE_COMPILE
    ${BYTE_MACHINE_CORE_NORMAL_IR}
    "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}/byte-machine/compile.sls")

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.compile.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/compile-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_COMPILE}
          "${CMAKE_SOURCE_DIR}/test/common/compile-tests.sps"
  # The emitter-totality witness reads compile.sls as a datum for its
  # derived totality row (render-state-arm's thirteen kind arms), loud when unset.
  ENVIRONMENT "BYTE_MACHINE_SOURCE_ROOT=${CMAKE_SOURCE_DIR}/src"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.compile.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/compile-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_COMPILE}
          "${CMAKE_SOURCE_DIR}/test/common/compile-tests.sps"
  ENVIRONMENT "BYTE_MACHINE_SOURCE_ROOT=${CMAKE_SOURCE_DIR}/src"
  TIMEOUT 120)

# --- The compile-file witness ----------------------------------------------
# The limits lane. It both compiles a machine and executes one (it imports the
# emitter AND the interpreter and runtime -- ${BYTE_MACHINE_CORE_EMIT}), which
# is exactly why it is its own lane pair and not a group in the rejections
# program, which must import no executor. It compile-files the largest emittable
# machine (a 256-exact-case dispatch plus a complement-matcher dispatch) at run
# time, loads the object, and asserts one feed agrees with the interpreter.
# TIMEOUT from the measured wall-clock (0.29 s source) plus a wide margin --
# compile-file of a ~36 KB library is fast.
byte_machine_add_scheme_lane(
  NAME byte-machine.unit.compile-limits.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/compile-limits-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${CMAKE_SOURCE_DIR}/test/common/compile-limits-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.compile-limits.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/compile-limits-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${CMAKE_SOURCE_DIR}/test/common/compile-limits-tests.sps"
  TIMEOUT 120)

# --- Differential and example ----------------------------------------------
set(BYTE_MACHINE_CORE_EMIT
    ${BYTE_MACHINE_CORE_ALL}
    "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}/byte-machine/private/normal-ir.sls"
    "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}/byte-machine/compile.sls")

byte_machine_add_scheme_lane(
  NAME byte-machine.differential.one-byte.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-one-byte-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/error-projection.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/one-byte-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/differential-one-byte-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.differential.one-byte.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-one-byte-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/error-projection.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/one-byte-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/differential-one-byte-tests.sps"
  TIMEOUT 120)

# parser-field-ref across both executors. Named `differential`, not `unit`: the
# label vocabulary reserves `differential` for exactly this shape -- a lane that
# runs the interpreter and the emitted library over the same fixture and
# compares. It emits and runtime-loads a generated library, so it needs
# BYTE_MACHINE_CORE_EMIT and the same TIMEOUT as the differential lanes -- and
# it imports (byte-machine private conditions) to name the contract-violation
# code, which is already in BYTE_MACHINE_CORE_EMIT. Every imported library is
# listed in BOTH lanes' SOURCES: a library reached only through `environment`
# must be statically imported or the AOT lane alone fails.
byte_machine_add_scheme_lane(
  NAME byte-machine.differential.field.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/field-access-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${CMAKE_SOURCE_DIR}/test/common/field-access-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.differential.field.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/field-access-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${CMAKE_SOURCE_DIR}/test/common/field-access-tests.sps"
  TIMEOUT 120)

# --- Declarations are separable from nodes ---------------------------------
# A machine that DECLARES callbacks and spans and contains no callback or span
# NODE verifies, normalizes, emits and runs identically. Both lanes, because the
# claim is that they agree AND that the differential's value tuple did not move.
byte_machine_add_scheme_lane(
  NAME byte-machine.differential.declaration-separability.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/declaration-separability-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${CMAKE_SOURCE_DIR}/test/common/declaration-separability-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.differential.declaration-separability.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/declaration-separability-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${CMAKE_SOURCE_DIR}/test/common/declaration-separability-tests.sps"
  TIMEOUT 120)

# --- The callback-invocation node -------------------------------------------
# The first fixture whose machine CALLS OUT, so the first place the two lanes can
# disagree about something the APPLICATION supplied rather than something the IR
# fixed. Both lanes, over every callback outcome plus the resumed
# pause, the unbound-optional short circuit and a callback on the EOF chain.
byte_machine_add_scheme_lane(
  NAME byte-machine.differential.callback.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-callback-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${CMAKE_SOURCE_DIR}/test/common/differential-callback-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.differential.callback.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-callback-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${CMAKE_SOURCE_DIR}/test/common/differential-callback-tests.sps"
  TIMEOUT 120)

# --- The liveness probe ----------------------------------------------------
# It tests an INSTRUMENT, not the parser: the input-retention oracle rests on
# a weak reference reading `bwp` once the test drops its own, and this lane
# measures that through the real harness rather than a scratch driver. Both
# lanes, because AOT compilation is where a probe like this is most likely to
# stop discriminating.
byte_machine_add_scheme_lane(
  NAME byte-machine.unit.liveness-probe.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/liveness-probe-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${CMAKE_SOURCE_DIR}/test/common/liveness-probe-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.liveness-probe.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/liveness-probe-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${CMAKE_SOURCE_DIR}/test/common/liveness-probe-tests.sps"
  TIMEOUT 120)

# --- The two span kinds ----------------------------------------------------
# What is compared here is not a parser result but the FRAGMENT TRACE: two lanes
# can agree on every tuple while handing the application different bytes, because
# the range a data callback receives is chosen by the span rules and appears in
# no result. Six rules, one group each, plus the substep pause a resume
# re-enters and the span state a reset must clear.
byte_machine_add_scheme_lane(
  NAME byte-machine.differential.span.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-span-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${CMAKE_SOURCE_DIR}/test/common/differential-span-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.differential.span.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-span-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${CMAKE_SOURCE_DIR}/test/common/differential-span-tests.sps"
  TIMEOUT 120)

# --- The span an error abandons --------------------------------------------
# An error withholds the bytes an open span took in the feed that failed, so an
# embedder counting a span's delivered bytes alone gets an answer that depends on
# the schedule. The error names the span and where its withheld bytes begin; this
# lane pins each path to that, and checks the property itself -- delivered then
# withheld is the span's bytes up to the error -- under every schedule of up to
# three slices, in both lanes.
byte_machine_add_scheme_lane(
  NAME byte-machine.differential.abandoned-span.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-abandoned-span-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${CMAKE_SOURCE_DIR}/test/common/differential-abandoned-span-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.differential.abandoned-span.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-abandoned-span-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${CMAKE_SOURCE_DIR}/test/common/differential-abandoned-span-tests.sps"
  TIMEOUT 120)

# --- The counted consume in both lanes -------------------------------------
# Zero, partial, exact and surplus input under every schedule, EOF truncation,
# a two-message feed, the u64 count, the two ordering witnesses, the
# only-consumer machine compile.sls's reached-declaration walk needs, the
# structural witness (one count-step per feed), and the placement oracle as
# one case. Both lanes list counted-machine.sls in SOURCES: the aot lane resolves
# libraries only through objects compiled from its own SOURCES.
byte_machine_add_scheme_lane(
  NAME byte-machine.differential.counted.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-counted-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/counted-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/differential-counted-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.differential.counted.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-counted-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/counted-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/differential-counted-tests.sps"
  TIMEOUT 120)

# --- The counted body inside a span, both lanes ----------------------------
# The fragment trace with per-feed event placement over every schedule: the six
# span rules over a counted body, the completion's placement asserted against a
# table derived from the schedule before the run, same-schedule exactness and
# coalesced invariance, the error path, and the two-message span variant. Both
# lanes list counted-machine.sls.
byte_machine_add_scheme_lane(
  NAME byte-machine.differential.counted-span.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-counted-span-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/counted-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/differential-counted-span-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.differential.counted-span.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-counted-span-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/counted-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/differential-counted-span-tests.sps"
  TIMEOUT 120)

# --- The input-retention oracle --------------------------------------------
# The lane the liveness probe above validates. Unlike that probe,
# this one imports `byte-machine` source and drives a real parser, so it is
# inside the mutation suite and carries pins -- do not copy the probe lane's
# "imports no project source" exemption onto it.
#
# Both lanes, because a retention defect that appears only under AOT compilation
# is exactly what the probe was measured in both lanes to rule out. `collect` is
# not free: sixteen probes per lane, one full collection each (eight distinct
# FIXTURES, driven more than once apiece).
byte_machine_add_scheme_lane(
  NAME byte-machine.unit.retention.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/retention-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${CMAKE_SOURCE_DIR}/test/common/retention-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.retention.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/retention-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${CMAKE_SOURCE_DIR}/test/common/retention-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.example.one-byte.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/example-one-byte-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/one-byte-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/example-one-byte-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.example.one-byte.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/example-one-byte-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/one-byte-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/example-one-byte-tests.sps"
  TIMEOUT 120)

# --- Incremental execution over a multi-byte sequence ----------------------
byte_machine_add_scheme_lane(
  NAME byte-machine.differential.sequence.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-sequence-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/prng.sls"
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/error-projection.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/sequence-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/differential-sequence-tests.sps"
  TIMEOUT 180)

byte_machine_add_scheme_lane(
  NAME byte-machine.differential.sequence.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-sequence-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/prng.sls"
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/error-projection.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/sequence-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/differential-sequence-tests.sps"
  TIMEOUT 180)

# --- Interpreter≡generated differential over EOF --------------------------
# Proves the generated /v2 finish path (exec closure's finish? EOF branch) equals
# the interpreter's parser-finish!/eof-target execution over the shared
# idle-vs-truncation eof-machine, for feed-then-finish across all 256 first bytes.
byte_machine_add_scheme_lane(
  NAME byte-machine.differential.eof.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-eof-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/error-projection.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/eof-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/differential-eof-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.differential.eof.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-eof-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/error-projection.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/eof-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/differential-eof-tests.sps"
  TIMEOUT 120)

# --- Interpreter≡generated pause/resume differential -----------------------
byte_machine_add_scheme_lane(
  NAME byte-machine.differential.pause.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-pause-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/error-projection.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/pause-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/differential-pause-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.differential.pause.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-pause-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/error-projection.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/pause-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/differential-pause-tests.sps"
  TIMEOUT 120)

# --- Interpreter≡generated settable-mode differential ----------------------
# Two parsers from one machine started in two modes through make-parser's
# initial-values argument agree across executors, survive reset, and refuse an
# illegal override identically.
byte_machine_add_scheme_lane(
  NAME byte-machine.differential.settable.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-settable-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/settable-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/differential-settable-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.differential.settable.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-settable-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/settable-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/differential-settable-tests.sps"
  TIMEOUT 120)

# --- All-byte class coverage through the interpreter -----------------------
# ABSOLUTE expected outcomes over all 256 bytes for a set, a range, a complement,
# a nested complement and an ASCII set. Absolute rather than differential because
# both executors canonicalize through the same matcher-bytes: a defect there is
# invisible to a comparison and visible here.
byte_machine_add_scheme_lane(
  NAME byte-machine.unit.byte-class.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/byte-class-interpret-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_ALL}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/class-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/byte-class-interpret-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.byte-class.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/byte-class-interpret-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_ALL}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/class-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/byte-class-interpret-tests.sps"
  TIMEOUT 120)

# --- Interpreter≡generated over every class matcher ------------------------
# The complement fixture is the widest class: every byte but two, 254 members.
byte_machine_add_scheme_lane(
  NAME byte-machine.differential.byte-class.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-byte-class-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/error-projection.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/class-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/differential-byte-class-tests.sps"
  TIMEOUT 180)

byte_machine_add_scheme_lane(
  NAME byte-machine.differential.byte-class.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-byte-class-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/error-projection.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/class-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/differential-byte-class-tests.sps"
  TIMEOUT 180)

# --- Sequence dispatch through the interpreter -----------------------------
# ABSOLUTE expected outcomes for a single-alternative sequence node and its
# advance-mismatch twin. Absolute rather than differential because both executors
# read the same source IR: a defect there is invisible to a comparison and
# visible here.
byte_machine_add_scheme_lane(
  NAME byte-machine.unit.sequence-node.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/sequence-interpret-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_ALL}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/sequence-node-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/sequence-interpret-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.sequence-node.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/sequence-interpret-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_ALL}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/sequence-node-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/sequence-interpret-tests.sps"
  TIMEOUT 120)

# --- Interpreter≡generated over a sequence node ----------------------------
# An independent oracle: a single-alternative sequence node must reproduce
# sequence-machine.sls -- four CHAINED DISPATCH NODES -- exactly, so the
# expected behaviour comes from a different mechanism than the node kind under
# test.
byte_machine_add_scheme_lane(
  NAME byte-machine.differential.sequence-node.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-sequence-node-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/prng.sls"
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/error-projection.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/sequence-node-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/differential-sequence-node-tests.sps"
  TIMEOUT 180)

byte_machine_add_scheme_lane(
  NAME byte-machine.differential.sequence-node.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-sequence-node-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/prng.sls"
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/error-projection.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/sequence-node-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/differential-sequence-node-tests.sps"
  TIMEOUT 180)

# --- Multiple alternatives over a shared prefix ----------------------------
# The HTTP `version = "HTTP/1.0" / "HTTP/1.1"` production. Both lanes list the
# fixture .sls in SOURCES because the aot lane resolves libraries only through
# objects compiled from its own SOURCES (the source-guard blocks fallback).
byte_machine_add_scheme_lane(
  NAME byte-machine.unit.http-version.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/http-version-interpret-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_ALL}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-version-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/http-version-interpret-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.http-version.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/http-version-interpret-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_ALL}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-version-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/http-version-interpret-tests.sps"
  TIMEOUT 120)

# The interpreter≡generated differential over the same production. Separate from
# the unit lanes above because it emits, loads and evals a generated library:
# that needs the emitter (CORE_EMIT rather than CORE_ALL) and prng.sls for the
# seeded split schedules, neither of which the absolute interpreter lane uses.
byte_machine_add_scheme_lane(
  NAME byte-machine.differential.http-version.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-http-version-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/prng.sls"
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/error-projection.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-version-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/differential-http-version-tests.sps"
  TIMEOUT 180)

byte_machine_add_scheme_lane(
  NAME byte-machine.differential.http-version.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-http-version-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/prng.sls"
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/error-projection.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-version-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/differential-http-version-tests.sps"
  TIMEOUT 180)

# --- The HTTP fixture: the request line ------------------------------------
# The fixture machine (http-machine.sls) and the shared event-order oracle
# (http-event-order.sls) serve every HTTP lane below. The unit lane pins the
# request-line events and error positions absolutely (CORE_ALL); the
# differential lane emits/loads a generated library and compares it to the
# interpreter across split points (CORE_EMIT + prng + error-projection), over
# the whole fixture.
byte_machine_add_scheme_lane(
  NAME byte-machine.unit.http-request-line.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/http-request-line-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_ALL}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-event-order.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/http-request-line-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.http-request-line.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/http-request-line-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_ALL}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-event-order.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/http-request-line-tests.sps"
  TIMEOUT 120)

# Headers, the empty line, and the no-body message loop.
byte_machine_add_scheme_lane(
  NAME byte-machine.unit.http-message.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/http-message-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_ALL}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-event-order.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/http-message-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.http-message.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/http-message-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_ALL}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-event-order.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/http-message-tests.sps"
  TIMEOUT 120)

# Framing recognition, checked Content-Length, and the fixed body.
byte_machine_add_scheme_lane(
  NAME byte-machine.unit.http-framing.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/http-framing-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_ALL}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-event-order.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/http-framing-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.http-framing.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/http-framing-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_ALL}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-event-order.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/http-framing-tests.sps"
  TIMEOUT 120)

# The chunked body, extensions, the zero chunk, and trailers.
byte_machine_add_scheme_lane(
  NAME byte-machine.unit.http-chunked.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/http-chunked-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_ALL}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-event-order.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/http-chunked-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.http-chunked.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/http-chunked-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_ALL}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-event-order.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/http-chunked-tests.sps"
  TIMEOUT 120)

# --- The HTTP fixture: close ----------------------------------------------
# The malformed sweep, pipelining, and the EOF rules.
byte_machine_add_scheme_lane(
  NAME byte-machine.unit.http-close.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/http-close-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_ALL}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-error-table.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/http-close-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.http-close.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/http-close-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_ALL}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-error-table.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/http-close-tests.sps"
  TIMEOUT 120)

# The leak check reads src/ and the harness root as data.
byte_machine_add_scheme_lane(
  NAME byte-machine.unit.http-leak.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/http-leak-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${CMAKE_SOURCE_DIR}/test/common/http-leak-tests.sps"
  TIMEOUT 120
  ENVIRONMENT "BYTE_MACHINE_SOURCE_ROOT=${CMAKE_SOURCE_DIR}/src"
              "BYTE_MACHINE_HARNESS_ROOT=${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}")

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.http-leak.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/http-leak-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${CMAKE_SOURCE_DIR}/test/common/http-leak-tests.sps"
  TIMEOUT 120
  ENVIRONMENT "BYTE_MACHINE_SOURCE_ROOT=${CMAKE_SOURCE_DIR}/src"
              "BYTE_MACHINE_HARNESS_ROOT=${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}")

# The determinism golden (in-process byte-identical + load-and-run).
byte_machine_add_scheme_lane(
  NAME byte-machine.determinism.http.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/determinism-http-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/determinism-http-tests.sps"
  TIMEOUT 180
  ENVIRONMENT "BYTE_MACHINE_HTTP_GOLDEN_FILE=${CMAKE_SOURCE_DIR}/test/fixtures/generated-http.golden.sls")

byte_machine_add_scheme_lane(
  NAME byte-machine.determinism.http.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/determinism-http-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/determinism-http-tests.sps"
  TIMEOUT 180
  ENVIRONMENT "BYTE_MACHINE_HTTP_GOLDEN_FILE=${CMAKE_SOURCE_DIR}/test/fixtures/generated-http.golden.sls")

byte_machine_add_scheme_lane(
  NAME byte-machine.differential.http.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-http-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/prng.sls"
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/error-projection.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-event-order.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/differential-http-tests.sps"
  TIMEOUT 180)

byte_machine_add_scheme_lane(
  NAME byte-machine.differential.http.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-http-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/prng.sls"
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/error-projection.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-event-order.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/differential-http-tests.sps"
  TIMEOUT 180)

# --- The release ledger ----------------------------------------------------
# The fifteen release criteria and eleven documentation deliverables as data a
# lane reads. The two totality rows re-read the source lists and set-compare;
# mechanical rows are executed; judgement rows are recorded. No mutation entry:
# the totality rows self-ratchet.
#
# The native-artifact criterion's mechanical witness is `git ls-files` matching
# the native-artifact pattern being empty. The build layer runs git (the lane
# cannot) and writes the result to a file; the lane asserts it is empty.
# Regenerated every configure.
#
# The ledger audits the development record: it re-reads the release criteria
# from .plans/, which .gitattributes leaves out of release archives. So the two
# lanes are registered only where that record is present -- always in the
# repository, never in an exported source archive, where there is nothing for
# them to audit.
set(BYTE_MACHINE_RELEASE_PLAN
    "${CMAKE_SOURCE_DIR}/.plans/byte-machine-implementation-plan.md")
if(NOT EXISTS "${BYTE_MACHINE_RELEASE_PLAN}")
  message(STATUS
    "byte-machine: ${BYTE_MACHINE_RELEASE_PLAN} is absent (a release archive); "
    "the release-ledger lanes are not registered")
else()
set(BYTE_MACHINE_NATIVE_ARTIFACTS_FILE
    "${CMAKE_BINARY_DIR}/release-ledger-native-artifacts.txt")
execute_process(
  COMMAND git ls-files -- "*.so" "*.o" "*.a" "*.dylib" "*.dll" "*.exe" "*.obj" "*.lib"
  WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
  OUTPUT_FILE "${BYTE_MACHINE_NATIVE_ARTIFACTS_FILE}")

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.release-ledger.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/release-ledger-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/release-ledger.sls"
          "${CMAKE_SOURCE_DIR}/test/common/release-ledger-tests.sps"
  TIMEOUT 120
  ENVIRONMENT "BYTE_MACHINE_REPO_ROOT=${CMAKE_SOURCE_DIR}"
              "BYTE_MACHINE_SOURCE_ROOT=${CMAKE_SOURCE_DIR}/src"
              "BYTE_MACHINE_NATIVE_ARTIFACTS_FILE=${BYTE_MACHINE_NATIVE_ARTIFACTS_FILE}")

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.release-ledger.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/release-ledger-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/release-ledger.sls"
          "${CMAKE_SOURCE_DIR}/test/common/release-ledger-tests.sps"
  TIMEOUT 120
  ENVIRONMENT "BYTE_MACHINE_REPO_ROOT=${CMAKE_SOURCE_DIR}"
              "BYTE_MACHINE_SOURCE_ROOT=${CMAKE_SOURCE_DIR}/src"
              "BYTE_MACHINE_NATIVE_ARTIFACTS_FILE=${BYTE_MACHINE_NATIVE_ARTIFACTS_FILE}")
endif()

# --- The dry Windows-cell audit -------------------------------------------
# The Windows portability questions this tree can answer without a Windows
# host, as assertions (the machine-type identity, the discovery names, the
# executable fallback). The two that need a Windows runner are not asserted.
byte_machine_add_scheme_lane(
  NAME byte-machine.unit.windows-audit.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/windows-audit-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${CMAKE_SOURCE_DIR}/test/common/windows-audit-tests.sps"
  TIMEOUT 60
  ENVIRONMENT "BYTE_MACHINE_REPO_ROOT=${CMAKE_SOURCE_DIR}")

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.windows-audit.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/windows-audit-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${CMAKE_SOURCE_DIR}/test/common/windows-audit-tests.sps"
  TIMEOUT 60
  ENVIRONMENT "BYTE_MACHINE_REPO_ROOT=${CMAKE_SOURCE_DIR}")

# --- The allocation audit -------------------------------------------------
# The gated, deterministic half of the allocation criterion: the generated
# per-byte path allocates nothing (slope 0.0), proved against a live control,
# both executors measured. Loads the emitted generated library, so SOURCES
# mirror the determinism-http lane. The committed benchmark baseline is produced
# by bench/runner/benchmark.sps and recorded in bench/fixtures/ — not a gating
# lane (no noisy CI perf gate); its existence and shape are checked by the
# release-ledger lane.
#
# The op census READS compile.sls as data to derive every
# runtime procedure emitted code can call, so it needs the source tree that is
# actually running -- the same BYTE_MACHINE_SOURCE_ROOT contract as the
# diagnostic census, overridden to the staged copy by the mutation suite. The
# keyword-header machine is the census's witness that emitted code reaches the
# keyword walk, not only a direct call.
byte_machine_add_scheme_lane(
  NAME byte-machine.unit.allocation-audit.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/allocation-audit-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-machine.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/keyword-header-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/allocation-audit-tests.sps"
  TIMEOUT 180
  ENVIRONMENT "BYTE_MACHINE_SOURCE_ROOT=${CMAKE_SOURCE_DIR}/src")

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.allocation-audit.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/allocation-audit-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-machine.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/keyword-header-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/allocation-audit-tests.sps"
  TIMEOUT 180
  ENVIRONMENT "BYTE_MACHINE_SOURCE_ROOT=${CMAKE_SOURCE_DIR}/src")

# --- Every position kind --------------------------------------------------
byte_machine_add_scheme_lane(
  NAME byte-machine.differential.position-kind.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/position-kind-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/error-projection.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-version-machine.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/eof-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/position-kind-tests.sps"
  TIMEOUT 180)

byte_machine_add_scheme_lane(
  NAME byte-machine.differential.position-kind.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/position-kind-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/error-projection.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-version-machine.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/eof-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/position-kind-tests.sps"
  TIMEOUT 180)

# --- Identifier repertoire + binary LF -------------------------------------
byte_machine_add_scheme_lane(
  NAME byte-machine.verify.identifier-repertoire.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/identifier-repertoire-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${CMAKE_SOURCE_DIR}/test/common/identifier-repertoire-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.verify.identifier-repertoire.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/identifier-repertoire-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${CMAKE_SOURCE_DIR}/test/common/identifier-repertoire-tests.sps"
  TIMEOUT 120)

# --- Determinism against a committed golden (one-byte) ---------------------
byte_machine_add_scheme_lane(
  NAME byte-machine.determinism.one-byte.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/determinism-one-byte-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${CMAKE_SOURCE_DIR}/test/common/determinism-one-byte-tests.sps"
  TIMEOUT 120
  ENVIRONMENT "BYTE_MACHINE_GOLDEN_FILE=${CMAKE_SOURCE_DIR}/test/fixtures/generated-one-byte.golden.sls")

byte_machine_add_scheme_lane(
  NAME byte-machine.determinism.one-byte.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/determinism-one-byte-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${CMAKE_SOURCE_DIR}/test/common/determinism-one-byte-tests.sps"
  TIMEOUT 120
  ENVIRONMENT "BYTE_MACHINE_GOLDEN_FILE=${CMAKE_SOURCE_DIR}/test/fixtures/generated-one-byte.golden.sls")

# --- Determinism against a committed golden (pause) ------------------------
# Unlike the one-byte neighbor above, this program imports (byte-machine test
# pause-machine) rather than building its machine inline, so both lanes below
# list pause-machine.sls in SOURCES -- exactly as the differential.pause block
# above does -- because the aot lane resolves libraries only through objects
# compiled from its own SOURCES (the source-guard blocks fallback).
byte_machine_add_scheme_lane(
  NAME byte-machine.determinism.pause.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/determinism-pause-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/pause-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/determinism-pause-tests.sps"
  TIMEOUT 120
  ENVIRONMENT "BYTE_MACHINE_PAUSE_GOLDEN_FILE=${CMAKE_SOURCE_DIR}/test/fixtures/generated-pause.golden.sls")

byte_machine_add_scheme_lane(
  NAME byte-machine.determinism.pause.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/determinism-pause-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/pause-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/determinism-pause-tests.sps"
  TIMEOUT 120
  ENVIRONMENT "BYTE_MACHINE_PAUSE_GOLDEN_FILE=${CMAKE_SOURCE_DIR}/test/fixtures/generated-pause.golden.sls")

# --- Determinism against a committed golden (accumulate) -------------------
# An integer-accumulate node renders an arm no other golden contains -- three
# disjoint digit ranges, a checked multiply-add and two distinct EOF routes --
# so a determinism claim that excluded it would be a claim about the other
# machines only. Like the pause and sequence lanes this
# program imports its machine from a harness library, so both lanes list
# accumulate-machine.sls in SOURCES: the aot lane resolves libraries only through
# objects compiled from its own SOURCES.
byte_machine_add_scheme_lane(
  NAME byte-machine.determinism.accumulate.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/determinism-accumulate-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/accumulate-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/determinism-accumulate-tests.sps"
  TIMEOUT 120
  ENVIRONMENT "BYTE_MACHINE_ACCUMULATE_GOLDEN_FILE=${CMAKE_SOURCE_DIR}/test/fixtures/generated-accumulate.golden.sls")

byte_machine_add_scheme_lane(
  NAME byte-machine.determinism.accumulate.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/determinism-accumulate-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/accumulate-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/determinism-accumulate-tests.sps"
  TIMEOUT 120
  ENVIRONMENT "BYTE_MACHINE_ACCUMULATE_GOLDEN_FILE=${CMAKE_SOURCE_DIR}/test/fixtures/generated-accumulate.golden.sls")

# --- Determinism against a committed golden (counted) ----------------------
# For the accumulate golden's reason: a counted-consume node renders an arm no
# other golden contains -- a zero-count jump, a bulk commit through `min`, an
# exhausted clause that is not the shared preamble -- so a determinism claim
# about emission that excluded it would be a claim about the other machines
# only. Both lanes list counted-machine.sls in SOURCES.
byte_machine_add_scheme_lane(
  NAME byte-machine.determinism.counted.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/determinism-counted-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/counted-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/determinism-counted-tests.sps"
  TIMEOUT 120
  ENVIRONMENT "BYTE_MACHINE_COUNTED_GOLDEN_FILE=${CMAKE_SOURCE_DIR}/test/fixtures/generated-counted.golden.sls")

byte_machine_add_scheme_lane(
  NAME byte-machine.determinism.counted.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/determinism-counted-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/counted-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/determinism-counted-tests.sps"
  TIMEOUT 120
  ENVIRONMENT "BYTE_MACHINE_COUNTED_GOLDEN_FILE=${CMAKE_SOURCE_DIR}/test/fixtures/generated-counted.golden.sls")

# --- Determinism against a committed golden (sequence) ---------------------
# Unlike the one-byte and pause goldens, this machine has a BRANCHING prefix
# state, which is the only shape whose child order can be unstable at all --
# the ascending-byte child rule is what keeps normalized output deterministic
# there. The
# rule lives in trie-put, not in the `list-sort` that orders a byte-dispatch
# node's transitions; SchemeMutationSuite.cmake's Pass 49 carries the
# measurement that separates the two. Like the pause block above, this program
# imports its machine from a fixture library, so both lanes list
# http-version-machine.sls in SOURCES: the aot lane resolves libraries only
# through objects compiled from its own SOURCES.
byte_machine_add_scheme_lane(
  NAME byte-machine.determinism.http-version.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/determinism-http-version-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-version-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/determinism-http-version-tests.sps"
  TIMEOUT 120
  ENVIRONMENT "BYTE_MACHINE_HTTP_VERSION_GOLDEN_FILE=${CMAKE_SOURCE_DIR}/test/fixtures/generated-http-version.golden.sls")

byte_machine_add_scheme_lane(
  NAME byte-machine.determinism.http-version.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/determinism-http-version-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-version-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/determinism-http-version-tests.sps"
  TIMEOUT 120
  ENVIRONMENT "BYTE_MACHINE_HTTP_VERSION_GOLDEN_FILE=${CMAKE_SOURCE_DIR}/test/fixtures/generated-http-version.golden.sls")

# --- Property generator + differential ------------------------------------
byte_machine_add_scheme_lane(
  NAME byte-machine.property.differential.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/property-differential-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/prng.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/machine-gen.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/rejection-ledger.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/property-driver.sls"
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/error-projection.sls"
          "${CMAKE_SOURCE_DIR}/test/common/property-differential-tests.sps"
  # BYTE_MACHINE_SOURCE_ROOT: the totality rows read ir.sls as a datum and every
  # datum reader raises when it is unset. (No SEED is passed: an unset seed
  # selects the committed default.) Under
  # the mutation suite the variable is set process-wide, so the failure appears
  # only under an ordinary ctest run -- the harder direction to notice.
  ENVIRONMENT "BYTE_MACHINE_SOURCE_ROOT=${CMAKE_SOURCE_DIR}/src"
  TIMEOUT 180)

byte_machine_add_scheme_lane(
  NAME byte-machine.property.differential.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/property-differential-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/prng.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/machine-gen.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/rejection-ledger.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/property-driver.sls"
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/error-projection.sls"
          "${CMAKE_SOURCE_DIR}/test/common/property-differential-tests.sps"
  ENVIRONMENT "BYTE_MACHINE_SOURCE_ROOT=${CMAKE_SOURCE_DIR}/src"
  TIMEOUT 180)

# --- The printer, the fixture saver, and the minimizer ---------------------
# The fixture lane. SOURCES carries machine-print.sls beside machine-gen.sls and
# property-driver.sls; the driver does NOT import machine-print, so machine-print
# is in only THIS lane's manifest, not the differential's.
# BYTE_MACHINE_SOURCE_ROOT for the same reason as the differential lane: the
# printer's totality rows read ir.sls as a datum and the reader raises when it is
# unset. No seed is passed. TIMEOUT
# is set from THIS lane's measured wall-clock -- one machine through the saver and
# the minimizer, 0.53 s source / 0.29 s aot registered -- plus a wide margin, NOT
# copied from the differential's 180. (The fixture lane is far below the differential
# lanes' ~4 s, which drive 64 machines through the full sweep, not one.)
byte_machine_add_scheme_lane(
  NAME byte-machine.property.fixture.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/property-fixture-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/prng.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/machine-gen.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/rejection-ledger.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/property-driver.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/machine-print.sls"
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/error-projection.sls"
          "${CMAKE_SOURCE_DIR}/test/common/property-fixture-tests.sps"
  ENVIRONMENT "BYTE_MACHINE_SOURCE_ROOT=${CMAKE_SOURCE_DIR}/src"
  TIMEOUT 60)

byte_machine_add_scheme_lane(
  NAME byte-machine.property.fixture.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/property-fixture-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/prng.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/machine-gen.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/rejection-ledger.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/property-driver.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/machine-print.sls"
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/error-projection.sls"
          "${CMAKE_SOURCE_DIR}/test/common/property-fixture-tests.sps"
  ENVIRONMENT "BYTE_MACHINE_SOURCE_ROOT=${CMAKE_SOURCE_DIR}/src"
  TIMEOUT 60)

# --- The corruption catalogue and the independent oracle ------------------
# The rejections lane. Its SOURCES are ${BYTE_MACHINE_CORE_VERIFY} -- CORE_GRAPH
# plus verify.sls and NO executor -- and the test-support libraries the two
# instruments read: prng/machine-gen (the draws), machine-print (the corruption
# datum), rejection-ledger (the property lane's rejected draws),
# machine-corrupt (the catalogue) and verify-oracle (the independent oracle). It
# deliberately omits ${BYTE_MACHINE_CORE_EMIT}'s executor libraries and
# property-driver.sls, so (byte-machine interpret/compile/runtime) are absent: under
# the AOT lane the program's static-import closure CANNOT reach an executor, which
# is what makes "the corrupted machine is never handed to an executor"
# structurally enforceable rather than a runtime claim. BYTE_MACHINE_SOURCE_ROOT
# for the code sentinel (reads verify.sls as a datum) and BYTE_MACHINE_HARNESS_ROOT
# for the matcher-bytes prohibition (reads verify-oracle.sls as a datum), both loud
# when unset. TIMEOUT from the measured wall-clock (2.90 s source; the oracle's
# three-source drive over 834 machines x 9 rules and the AOT build are the cost, not
# the catalogue arithmetic, about 0.83 s) plus a wide margin, NOT
# copied from the differential's 180.
byte_machine_add_scheme_lane(
  NAME byte-machine.property.rejections.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/property-rejections-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/prng.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/machine-gen.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/machine-print.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/rejection-ledger.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/machine-corrupt.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/verify-oracle.sls"
          ${BYTE_MACHINE_CORE_VERIFY}
          "${CMAKE_SOURCE_DIR}/test/common/property-rejections-tests.sps"
  ENVIRONMENT "BYTE_MACHINE_SOURCE_ROOT=${CMAKE_SOURCE_DIR}/src"
              "BYTE_MACHINE_HARNESS_ROOT=${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.property.rejections.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/property-rejections-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/prng.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/machine-gen.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/machine-print.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/rejection-ledger.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/machine-corrupt.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/verify-oracle.sls"
          ${BYTE_MACHINE_CORE_VERIFY}
          "${CMAKE_SOURCE_DIR}/test/common/property-rejections-tests.sps"
  ENVIRONMENT "BYTE_MACHINE_SOURCE_ROOT=${CMAKE_SOURCE_DIR}/src"
              "BYTE_MACHINE_HARNESS_ROOT=${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}"
  TIMEOUT 120)

# --- The member-2 runtime-export drift guard ------------------------------
byte_machine_add_scheme_lane(
  NAME byte-machine.unit.reserved-drift.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/reserved-drift-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_COMPILE}
          "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}/byte-machine/runtime.sls"
          "${CMAKE_SOURCE_DIR}/test/common/reserved-drift-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.reserved-drift.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/reserved-drift-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_COMPILE}
          "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}/byte-machine/runtime.sls"
          "${CMAKE_SOURCE_DIR}/test/common/reserved-drift-tests.sps"
  TIMEOUT 120)

# --- The kind x position matrix -------------------------------------------
# Reads ir.sls as data for its closed-set drift row, so it needs the same
# BYTE_MACHINE_SOURCE_ROOT the diagnostic census does, and for the same reason:
# under the mutation suite it must read the STAGED tree.
byte_machine_add_scheme_lane(
  NAME byte-machine.unit.kind-position-census.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/kind-position-census-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_VERIFY}
          "${CMAKE_SOURCE_DIR}/test/common/kind-position-census-tests.sps"
  TIMEOUT 180
  ENVIRONMENT "BYTE_MACHINE_SOURCE_ROOT=${CMAKE_SOURCE_DIR}/src")

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.kind-position-census.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/kind-position-census-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_VERIFY}
          "${CMAKE_SOURCE_DIR}/test/common/kind-position-census-tests.sps"
  TIMEOUT 180
  ENVIRONMENT "BYTE_MACHINE_SOURCE_ROOT=${CMAKE_SOURCE_DIR}/src")

# --- The verifier's diagnostic census -------------------------------------
# The program READS `verify.sls` and `ir.sls` as data, so it needs a path to the
# source tree -- and it must be the tree that is actually RUNNING. Under the
# mutation suite that is the staged copy, not `${CMAKE_SOURCE_DIR}`: a census
# reading the pristine source while running a mutated object would report every
# source-side mutation as caught for no reason at all. The suite therefore
# overrides this variable to its own `STAGE_DIR` once, next to where STAGE_DIR is
# defined; these two registrations carry the un-staged value for ordinary runs.
# An unset variable RAISES in the program rather than defaulting.
byte_machine_add_scheme_lane(
  NAME byte-machine.unit.diagnostic-census.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/diagnostic-census-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_VERIFY}
          "${CMAKE_SOURCE_DIR}/test/common/diagnostic-census-tests.sps"
  TIMEOUT 120
  # REPO_ROOT is set only for the ordinary ctest lane, never by the mutation
  # suite (which sets only SOURCE_ROOT, to the staged tree). The diagnostic
  # catalog-vs-census check keys on it, so it runs here and is skipped under the
  # mutation suite — where the catalog is not staged and the check does not
  # belong.
  ENVIRONMENT "BYTE_MACHINE_SOURCE_ROOT=${CMAKE_SOURCE_DIR}/src"
              "BYTE_MACHINE_REPO_ROOT=${CMAKE_SOURCE_DIR}")

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.diagnostic-census.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/diagnostic-census-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_VERIFY}
          "${CMAKE_SOURCE_DIR}/test/common/diagnostic-census-tests.sps"
  TIMEOUT 120
  ENVIRONMENT "BYTE_MACHINE_SOURCE_ROOT=${CMAKE_SOURCE_DIR}/src"
              "BYTE_MACHINE_REPO_ROOT=${CMAKE_SOURCE_DIR}")

# --- The fixture-state -> expected-error table ----------------------------
# The error each HTTP fixture state must report, as data. The table library
# imports only (rnrs) -- pure data -- so the lane needs the harness manifest,
# the table library, and the program; no core.
byte_machine_add_scheme_lane(
  NAME byte-machine.unit.http-error-table.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/http-error-table-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-error-table.sls"
          "${CMAKE_SOURCE_DIR}/test/common/http-error-table-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.http-error-table.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/http-error-table-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-error-table.sls"
          "${CMAKE_SOURCE_DIR}/test/common/http-error-table-tests.sps"
  TIMEOUT 120)

# --- The member-3 drift guard ---------------------------------------------
byte_machine_add_scheme_lane(
  NAME byte-machine.unit.member3-drift.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/member3-drift-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_COMPILE}
          "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}/byte-machine/runtime.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/pause-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/member3-drift-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.member3-drift.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/member3-drift-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_COMPILE}
          "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}/byte-machine/runtime.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/pause-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/member3-drift-tests.sps"
  TIMEOUT 120)

# --- The keyword-table node kind ------------------------------------------
# An IR node kind that matches a set of keywords tolerating proper prefixes
# (GET vs GET-PARAMETER) and, per table, case-insensitively (an ASCII fold). It
# lowers to ONE compact table state walked by `byte-machine-keyword-step/v1`,
# not a trie of dispatch states.
# The two fixtures carry the same keyword set and differ only in the fold flag,
# so the differential can show the case-sensitive table refusing a mixed-case
# name the case-insensitive one accepts, with nothing else changed.

# The interpreter-absolute oracle. Absolute rather than differential because both
# executors read the same source IR: a walk-logic defect in the interpreter's own
# kw-step (derived independently) is invisible to a comparison and
# visible here.
byte_machine_add_scheme_lane(
  NAME byte-machine.unit.keyword-table.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/keyword-interpret-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_ALL}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/keyword-table-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/keyword-interpret-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.keyword-table.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/keyword-interpret-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_ALL}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/keyword-table-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/keyword-interpret-tests.sps"
  TIMEOUT 120)

# interpreter ≡ generated over the compact-table lowering. Every group but the
# exhaustive byte sweep also asserts the generated side absolutely, so a fold or
# walk mutation that hit both lanes identically cannot pass by agreement alone.
byte_machine_add_scheme_lane(
  NAME byte-machine.differential.keyword-table.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-keyword-table-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/keyword-table-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/differential-keyword-table-tests.sps"
  TIMEOUT 180)

byte_machine_add_scheme_lane(
  NAME byte-machine.differential.keyword-table.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-keyword-table-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/keyword-table-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/differential-keyword-table-tests.sps"
  TIMEOUT 180)

# --- Determinism against a committed golden (keyword-table) ---------------
# On the counted golden's reasoning: a keyword-table node
# renders an arm no other golden contains -- the tag-15 compact table datum, the
# keyword-step op, the resumable compound `current`, and the per-table fold byte
# -- so a determinism claim about emission that excluded it would be a claim
# about the other machines only. The case-insensitive fixture is the golden
# because it is the strictly richer render (it carries the fold datum the
# case-sensitive table omits).
byte_machine_add_scheme_lane(
  NAME byte-machine.determinism.keyword-table.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/determinism-keyword-table-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/keyword-table-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/determinism-keyword-table-tests.sps"
  TIMEOUT 120
  ENVIRONMENT "BYTE_MACHINE_KEYWORD_TABLE_GOLDEN_FILE=${CMAKE_SOURCE_DIR}/test/fixtures/generated-keyword-table.golden.sls")

byte_machine_add_scheme_lane(
  NAME byte-machine.determinism.keyword-table.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/determinism-keyword-table-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/keyword-table-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/determinism-keyword-table-tests.sps"
  TIMEOUT 120
  ENVIRONMENT "BYTE_MACHINE_KEYWORD_TABLE_GOLDEN_FILE=${CMAKE_SOURCE_DIR}/test/fixtures/generated-keyword-table.golden.sls")

# --- The HTTP-header case-insensitivity demonstration ---------------------
# A case-insensitive header table folds every casing of a name to one target
# and a case-sensitive one over the same names does not; and the per-table
# folded-collision rejection, verified directly
# (the case-insensitive collision machine is invalid by design, so it is never
# handed to make-interpreted-machine). interpreter ≡ generated with the generated
# side asserted absolutely.
byte_machine_add_scheme_lane(
  NAME byte-machine.differential.keyword-header.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-keyword-header-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/keyword-header-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/differential-keyword-header-tests.sps"
  TIMEOUT 180)

byte_machine_add_scheme_lane(
  NAME byte-machine.differential.keyword-header.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-keyword-header-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/keyword-header-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/differential-keyword-header-tests.sps"
  TIMEOUT 180)

# --- Span composition ----------------------------------------------------
# A method span opened before a keyword table closes at the matched keyword's
# length (span[method]="MKCOL" from six bytes of MKCOLA); interpreter ≡ generated
# with the delivered span DATA asserted absolutely on the generated side.
byte_machine_add_scheme_lane(
  NAME byte-machine.differential.keyword-span.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-keyword-span-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/keyword-span-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/differential-keyword-span-tests.sps"
  TIMEOUT 180)

byte_machine_add_scheme_lane(
  NAME byte-machine.differential.keyword-span.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-keyword-span-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/keyword-span-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/differential-keyword-span-tests.sps"
  TIMEOUT 180)

# --- The emitted-size measurement -----------------------------------------
# The 47 llhttp methods as ONE keyword-table node vs the equivalent 242-node
# byte-dispatch trie, both rendered through the emitter; the compact table emits
# ~34x fewer bytes. Labelled `unit` (an absolute self-contained measurement); an
# invented layer would be rejected by the closed layer vocabulary at configure.
byte_machine_add_scheme_lane(
  NAME byte-machine.unit.keyword-size.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/unit-keyword-size-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/keyword-method-table.sls"
          "${CMAKE_SOURCE_DIR}/test/common/unit-keyword-size-tests.sps"
  TIMEOUT 180)

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.keyword-size.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/unit-keyword-size-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/keyword-method-table.sls"
          "${CMAKE_SOURCE_DIR}/test/common/unit-keyword-size-tests.sps"
  TIMEOUT 180)
