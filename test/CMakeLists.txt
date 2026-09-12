# byte-machine test tree.
#
# Milestone 0 slice 1 registers only the CMake-layer specifications: the build's
# own discovery and registration logic, which decides what every later lane can
# even see. The portable Scheme harness and its execution lanes arrive in
# slice 2.

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
# ran it -- the exact defect this slice exists to prevent. No task in its plan
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

# Milestone 1 semantic-core libraries (Phase 2). Defined here beside the harness
# manifest so every semantic-core lane below can name the exact .sls set it
# loads; each fragment grows the previous one in dependency order, mirroring the
# library dependency direction (parent §7.2): private conditions ← private ir.
# names.sls (Milestone 6 Slice ⓪: the one portable-name grammar) imports only
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
# sole mechanism that makes `mode=source` an honest claim. Three places in this
# tree say so -- the spec's section 7.1, ByteMachineSchemeLane.cmake, and the
# Chez adapter -- and until these lanes existed none of them checked it: every
# decision in the launcher could be deleted, and a file dropped into the guard
# directory, with all twenty tests still green, because a healthy lane never
# reaches a refusal.
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

# The harness is the instrument every later milestone is measured with, so a
# passing self-test suite is not evidence until something has proved it can
# fail. This breaks each decision in the runner on a staged copy and requires
# the self-tests to notice. Registered only when a Chez was discovered: it runs
# a real lane and cannot be verified under the no-scheme preset.
#
# The self-tests load the fingerprint fixture through adapter-file-bytes; staged
# lanes inherit this process's environment through execute_process, so the
# variable must be set here. Pass 38 (D6 determinism, Slice B) reads the
# committed golden the same way, through BYTE_MACHINE_GOLDEN_FILE, so it is
# set here too rather than inside SchemeMutationSuite.cmake -- the same
# mechanism, for the same reason, as BYTE_MACHINE_FINGERPRINT_SAMPLE. Pass 49
# (Slice ③, the sequence golden) adds the third variable for the same reason;
# without it that pass's BASELINE fails, and a failing baseline reads as a
# mutation defect rather than as the missing environment it is. Milestone 4
# Slice ③'s accumulate golden adds the fourth, before its pass exists rather
# than after: the failure mode is a red BASELINE that names neither the variable
# nor the lane, and it is the same failure every time.
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
                "BYTE_MACHINE_COUNTED_GOLDEN_FILE=${CMAKE_SOURCE_DIR}/test/fixtures/generated-counted.golden.sls")
endif()

# --- Provenance ------------------------------------------------------------
#
# Every lane above checks the fingerprint of the text it ran against the value
# the build computed. These prove that check can fail. Without them the
# mechanism would be a claim: protium recorded two occasions where two of its
# lanes printed different digests for text both said they ran, and the suite
# stayed green, because nothing read the values back.
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

# Provenance configured and never performed. SOURCES guarantees the
# environment carries a manifest; nothing until now guaranteed anything read
# it. This program reaches harness-summary without ever reaching
# harness-verify-provenance!, which is precisely the shape harness-bootstrap
# would have had if its hand-placed call had been forgotten -- and that would
# have run un-provenanced with nothing failing.
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
# tree per pass and cannot express "built before the edit, run after it"
# (design W12, slice 5a task 6).
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

# --- Milestone 1 semantic core (Phase 2) -----------------------------------
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

# The runtime now depends on (byte-machine private conditions) for coded API
# contract conditions (decision 0013); conditions.sls imports only (rnrs), so no
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

# conditions.sls now reaches CORE_ALL twice — once via CORE_VERIFY's ir manifest,
# once via CORE_RUNTIME (decision 0013) — and names.sls reaches it twice by the
# same two routes (Milestone 6 Slice ⓪). REMOVE_DUPLICATES keeps the first (early,
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

# Milestone 2 Slice ②b-1 Task 3: the shared idle-vs-truncation proving machine
# (built only through (byte-machine graph), reused by Slice ②b-2's
# interpreter≡generated differential) driven exhaustively through the
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

# Milestone 2 Slice ③: the shared pause/resume proving machine driven through
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

# --- Milestone 1 Phase 3 Slice A: normalizer ------------------------------
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

# --- Milestone 1 Phase 3 Slice A: emitter ---------------------------------
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
  # Milestone 7 Slice ④: the §16.2:910 witness reads compile.sls as a datum for its
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

# --- Milestone 7 Slice ④: the §16.2:911 compile-file witness (§4.12 item 2) ----
# The limits lane. It both compiles a machine and executes one (it imports the
# emitter AND the interpreter and runtime -- ${BYTE_MACHINE_CORE_EMIT}), which is
# exactly why it is its own lane pair and not a group in the rejections program
# (F7). It compile-files the largest emittable machine (a 256-exact-case dispatch
# plus a complement-matcher dispatch) at run time, loads the object, and asserts one
# feed agrees with the interpreter. TIMEOUT from the measured wall-clock (0.29 s
# source) plus a wide margin -- compile-file of a ~36 KB library is fast.
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

# --- Milestone 1 Phase 3 Slice A: differential and example ----------------
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

# Milestone 4 Slice ①b task 7: parser-field-ref across both executors. Named
# `differential`, not `unit`: the design's exit evidence asks for
# `byte-machine.differential.field.chez.{source,aot}` and the label vocabulary
# reserves `differential` for exactly this shape -- a lane that runs the
# interpreter and the emitted library over the same fixture and compares. It
# shipped as `unit.field-access` and was renamed by the whole-branch review. It
# emits
# and runtime-loads a generated library, so it needs BYTE_MACHINE_CORE_EMIT and
# the same TIMEOUT as the differential lanes -- and it imports (byte-machine
# private conditions) to name the contract-violation code, which is already in
# BYTE_MACHINE_CORE_EMIT. Every imported library is listed in BOTH lanes'
# SOURCES: a library reached only through `environment` must be statically
# imported or the AOT lane alone fails.
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

# --- Milestone 5 Slice ①b: declarations are separable from nodes -------------
# The slice's oracle, and the one property NO LATER SLICE CAN ESTABLISH: once a
# callback-invocation node exists, "declared but unused" stops being the only
# thing a declaration can be. Both lanes, because the claim is that they agree
# AND that the shipped value tuple did not move.
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

# --- Milestone 5 Slice ②: the callback-invocation node ------------------------
# The first fixture whose machine CALLS OUT, so the first place the two lanes can
# disagree about something the APPLICATION supplied rather than something the IR
# fixed. Both lanes, over every one of §13:803-808's outcomes plus the resumed
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

# --- Milestone 5 Slice ③ task 7: Slice ④'s liveness probe, measured early ---
# It tests an INSTRUMENT, not the parser: design §9's retention oracle rests on
# a weak reference reading `bwp` once the test drops its own, and §9 says in its
# own words that the measurement behind that "was taken in a throwaway scratch
# driver and does not count". Both lanes, because AOT compilation is where a
# probe like this is most likely to stop discriminating -- and learning that
# while ③ is in flight is much cheaper than learning it inside ④.
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

# --- Milestone 5 Slice ③: the two span kinds --------------------------------
# What is compared here is not a parser result but the FRAGMENT TRACE: two lanes
# can agree on every tuple while handing the application different bytes, because
# the range a data callback receives is chosen by §14:831, §14:833 and §14:834
# and appears in no result. Six rules, one group each, plus the substep pause
# §14:838 resumes into and the reset §12.5:739 requires.
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

# --- Milestone 6 Slice ①: the counted consume in both lanes -------------------
# §22.3:1254's four cases under §22.5's schedules, EOF truncation, the two-message
# feed of §25:1609, the u64 count, decision 0030 item 1's two ordering witnesses,
# the only-consumer machine compile.sls's reached-declaration walk owes, the
# structural witness for §25:1607, and Slice ②'s §10.6:603 placement oracle as
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

# --- Milestone 6 Slice ②: the counted body inside a span, both lanes ----------
# The fragment trace with per-feed event placement over every schedule: the six
# §14 rules over a counted body, §10.6:603's placement asserted against a table
# derived from the schedule before the run, §22.5's exactness and coalesced
# invariance, the error path, and §25:1609's span variant. No mechanism is added
# by the slice; this lane is its oracle. Both lanes list counted-machine.sls.
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

# --- Milestone 5 Slice ④: the input-retention oracle (§25:1591) --------------
# The lane Slice ③'s liveness probe was brought forward FOR. Unlike that probe,
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

# --- Milestone 2 Slice 1: incremental execution over a multi-byte sequence ----
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

# --- Milestone 2 Slice ②b-2: interpreter≡generated differential over EOF ------
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

# --- Milestone 2 Slice ③: interpreter≡generated pause/resume differential -----
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

# --- Milestone 3 Slice ①: all-byte class coverage through the interpreter ----
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

# --- Milestone 3 Slice ①: interpreter≡generated over every class matcher -----
# The complement fixture renders 254 sibling arms inside the single `(case b ...)`
# -- the concrete proof that decision 0014's per-byte lowering needed no emitter
# change.
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

# --- Milestone 3 Slice ②: sequence dispatch through the interpreter -----------
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

# --- Milestone 3 Slice ②: interpreter≡generated over a sequence node ----------
# The slice's independent oracle. A single-alternative sequence node must
# reproduce sequence-machine.sls -- four CHAINED DISPATCH NODES -- exactly: the
# construct is new, the expected behaviour is not, and it was measured by a
# different mechanism before this node kind existed.
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

# --- Milestone 3 Slice ③: multiple alternatives over a shared prefix ---------
# The §21.2 `version = "HTTP/1.0" / "HTTP/1.1"` production. Both lanes list the
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

# --- Milestone 4 Slice ①a task 7: all three §12.7 position kinds -------------
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

# --- Milestone 1 Phase 3 Slice B: D7 identifier repertoire + binary LF -------
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

# --- Milestone 1 Phase 3 Slice B: D6 determinism against a committed golden ---
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

# --- Milestone 2 Slice ③: determinism against a committed golden (pause) ------
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

# --- Milestone 4 Slice ③: determinism against a committed golden (accumulate) -
# The FOURTH golden, and the reason §8's "an empty test/fixtures diff" was
# reworded rather than obeyed: an integer-accumulate node renders an arm no
# existing golden contains -- three disjoint digit ranges, a checked multiply-add
# and two distinct EOF routes -- so a determinism claim that excluded it would be
# a claim about the other three machines. Like the pause and sequence lanes this
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

# --- Milestone 6 Slice ①: determinism against a committed golden (counted) -----
# The FIFTH golden, for the accumulate golden's reason: a counted-consume node
# renders an arm no other golden contains -- a zero-count jump, a bulk commit
# through `min`, an exhausted clause that is not the shared preamble -- so a
# determinism claim about emission that excluded it would be a claim about the
# other four machines. Both lanes list counted-machine.sls in SOURCES.
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

# --- Milestone 3 Slice ③: determinism against a committed golden (sequence) ---
# The third golden. Unlike the one-byte and pause goldens, this machine has a
# BRANCHING prefix state, which is the only shape whose child order can be
# unstable at all -- decision 0016's ascending-byte child rule, and the way
# §25:1539's "normalized output is deterministic" would otherwise be lost. The
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

# --- Milestone 1 Phase 3 Slice B: property generator + differential ----------
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
  # shipped datum reader raises when it is unset (this is NOT decision 0033 item
  # 3's "the registrations pass nothing" -- that clause is about the SEED). Under
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

# --- Milestone 7 Slice ③: the printer, the fixture saver, and the minimizer ----
# The fixture lane. SOURCES gains machine-print.sls beside machine-gen.sls and
# property-driver.sls; the driver does NOT import machine-print, so machine-print
# is in only THIS lane's manifest, not the differential's (Task 7 Step 1).
# BYTE_MACHINE_SOURCE_ROOT for the same reason as the differential lane: the
# printer's totality rows read ir.sls as a datum and the reader raises when it is
# unset (NOT the seed clause of decision 0033 item 3). No seed is passed. TIMEOUT
# is set from THIS lane's measured wall-clock -- one machine through the saver and
# the minimizer, 0.53 s source / 0.29 s aot registered -- plus a wide margin, NOT
# copied from the differential's 180. (The fixture lane is far below the differential
# lanes' ~4 s of §4.10, which drive 64 machines through the full sweep, not one.)
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

# --- Milestone 7 Slice ④: the corruption catalogue and the independent oracle --
# The rejections lane. Its SOURCES are ${BYTE_MACHINE_CORE_VERIFY} -- CORE_GRAPH
# plus verify.sls and NO executor -- and the test-support libraries the two
# instruments read: prng/machine-gen (the draws), machine-print (the corruption
# datum), rejection-ledger (the property lane's rejected draws, F6/F13),
# machine-corrupt (the catalogue) and verify-oracle (the independent oracle). It
# deliberately omits ${BYTE_MACHINE_CORE_EMIT}'s executor libraries and
# property-driver.sls, so (byte-machine interpret/compile/runtime) are absent: under
# the AOT lane the program's static-import closure CANNOT reach an executor, which
# is what makes "the corrupted machine is never handed to an executor" (§22.6:1297,
# F7) structurally enforceable rather than a runtime claim. BYTE_MACHINE_SOURCE_ROOT
# for the code sentinel (reads verify.sls as a datum) and BYTE_MACHINE_HARNESS_ROOT
# for the matcher-bytes prohibition (reads verify-oracle.sls as a datum), both loud
# when unset. TIMEOUT from the measured wall-clock (2.90 s source; the oracle's
# three-source drive over 834 machines x 9 rules and the AOT build are the cost, not
# the catalogue arithmetic -- P3 priced that at 0.83 s) plus a wide margin, NOT
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

# --- Milestone 1 Phase 3 Slice B: member-2 runtime-export drift guard ---------
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

# --- Milestone 5 Slice ⓪ task 2: the kind x position matrix ------------------
# Reads ir.sls as data for its closed-set drift row (S2), so it needs the same
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

# --- Milestone 5 Slice ⓪ task 6: the verifier's diagnostic census ------------
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
  ENVIRONMENT "BYTE_MACHINE_SOURCE_ROOT=${CMAKE_SOURCE_DIR}/src")

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.diagnostic-census.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/diagnostic-census-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_VERIFY}
          "${CMAKE_SOURCE_DIR}/test/common/diagnostic-census-tests.sps"
  TIMEOUT 120
  ENVIRONMENT "BYTE_MACHINE_SOURCE_ROOT=${CMAKE_SOURCE_DIR}/src")

# --- Milestone 4 Slice ①a task 4.7-2: the member-3 drift guard ---------------
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
