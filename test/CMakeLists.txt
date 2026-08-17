# byte-machine test tree.
#
# Milestone 0 slice 1 registers only the CMake-layer specifications: the build's
# own discovery and registration logic, which decides what every later lane can
# even see. The portable Scheme harness and its four execution lanes arrive in
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

# Gambit discovery has to tell Gambit apart from a PostScript interpreter that
# answers to the same name and exits 0 while doing it.
byte_machine_add_test(
  NAME byte-machine.harness.cmake-gambit.cmake.direct
  COMMAND "${CMAKE_COMMAND}" -P
          "${CMAKE_CURRENT_LIST_DIR}/support/cmake/ByteMachineGambitSpec.cmake"
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
# notice. It runs in CI because evidence that only exists in someone's terminal
# cannot fail when the code changes.
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
set(BYTE_MACHINE_HARNESS_SHARED_DIR "${BYTE_MACHINE_HARNESS_DIR}/shared")
set(BYTE_MACHINE_HARNESS_SELF_DIR "${BYTE_MACHINE_HARNESS_DIR}/self")
set(BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT "${BYTE_MACHINE_HARNESS_DIR}/chez")
set(BYTE_MACHINE_HARNESS_GAMBIT_LIBRARY_ROOT "${BYTE_MACHINE_HARNESS_DIR}/gambit")
set(BYTE_MACHINE_HARNESS_CHEZ_LAUNCHER
    "${CMAKE_CURRENT_LIST_DIR}/support/launchers/chez-source.ss")

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
set(BYTE_MACHINE_SRC_COMMON_DIR "${CMAKE_SOURCE_DIR}/src/common/byte-machine")
set(BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT "${CMAKE_SOURCE_DIR}/src/chez")
set(BYTE_MACHINE_SRC_GAMBIT_LIBRARY_ROOT "${CMAKE_SOURCE_DIR}/src/gambit")
set(BYTE_MACHINE_TEST_COMMON_DIR "${CMAKE_CURRENT_LIST_DIR}/common")

# The bodies every harness lane executes. Named once: a lane that listed them
# itself would drift, and a manifest that drifts is one that quietly stops
# describing the run.
set(BYTE_MACHINE_HARNESS_MANIFEST
    "${BYTE_MACHINE_HARNESS_SHARED_DIR}/fingerprint.scm"
    "${BYTE_MACHINE_HARNESS_SHARED_DIR}/harness-runner.scm")

# --- Build-time fingerprint expectations -----------------------------------

set(BYTE_MACHINE_FINGERPRINT_LAUNCHER
    "${CMAKE_CURRENT_LIST_DIR}/support/launchers/fingerprint-manifest.ss")
set(BYTE_MACHINE_FINGERPRINT_DIR "${CMAKE_BINARY_DIR}/fingerprints")

# byte_machine_expected_fingerprint(<name> <out_var> <body>...)
#
# Produce, at build time, the combined fingerprint the named lane must report,
# and set <out_var> to the file holding it.
#
# A build output rather than a configure-time value, because a registration's
# environment is fixed when CMake configures and this must be recomputed
# whenever a body changes -- which is precisely the case it exists to catch.
# The DEPENDS list is what makes that true, so a body added to a manifest
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
      "bodies. An empty manifest fingerprints to the seed on every lane, which "
      "would compare equal forever and check nothing.")
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
              "${BYTE_MACHINE_HARNESS_SHARED_DIR}"
              "${expect_file}"
              ${ARGN}
      DEPENDS ${ARGN}
              "${BYTE_MACHINE_FINGERPRINT_LAUNCHER}"
              "${BYTE_MACHINE_HARNESS_SHARED_DIR}/fingerprint.scm"
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

# Checked before any lane is registered, and before the working-directory
# matrix's own fixture copies below: a body missing a wrapper must stop the
# build with this guard's own named diagnostic, not with a bare
# configure_file error from a copy step that has no idea why the file it
# wanted is missing. This call used to sit after that copy step; moved here,
# removing a shared body reports "every shared test body needs a wrapper..."
# instead of "configure_file Problem opening file for copying".
# src/common holds bodies included by a library, so they owe no program
# wrapper; test/common holds bodies included by a program, so each owes both.
# Every body from either kind of directory shares one basename namespace, which
# now spans the harness and src/ for the first time.
byte_machine_portability_guard(
  SHARED_DIRS "${BYTE_MACHINE_HARNESS_SHARED_DIR}" "${BYTE_MACHINE_SRC_COMMON_DIR}"
  WRAPPED_DIRS "${BYTE_MACHINE_HARNESS_SELF_DIR}" "${BYTE_MACHINE_TEST_COMMON_DIR}")

byte_machine_add_test(
  NAME byte-machine.harness.cmake-portability-guard.cmake.direct
  COMMAND "${CMAKE_COMMAND}" -P
          "${CMAKE_CURRENT_LIST_DIR}/support/cmake/ByteMachinePortabilityGuardSpec.cmake"
  TIMEOUT 120
  LABELS unit)

# --- The working-directory matrix ------------------------------------------
#
# Three directories, each catching a different failure of the include
# mechanism. Under a correct mechanism all three lanes pass and the decoy is
# simply ignored, so the matrix proves nothing on its own: what proves it is the
# launcher mutation in SchemeMutationSuite.cmake, whose expected outcome is
# asymmetric -- empty and decoy fail, identical passes.
#
# Six lane names below read as six units of evidence, but only the three Chez
# ones are: Gambit resolves an `include` inside `define-library` against the
# including file itself, not against the process working directory, so no
# launcher mutation can make a Gambit lane depend on where it was launched
# from (decision record 0002, point 3). The three Gambit lanes here are
# non-discriminating by construction -- they still have to pass, as parity
# proof that the shared body loads identically through both wrappers, but
# nothing in SchemeMutationSuite.cmake can fail them the way the Chez mutation
# fails the Chez ones, and nothing here should be added trying to make it.
#
# Both non-empty directories carry a copy of EVERY body the lane includes, the
# harness runner included. A directory holding only a placeholder body would
# fail to build (byte-machine test harness) under that mutation, before reaching
# the code under test, and all three lanes would fail identically -- destroying
# the only evidence that the lanes differ.
#
# They live in the build tree, which keeps intact byte_machine_add_test's rule
# that a test never runs from the repository. They cannot be checked in in any
# case: they share basenames with real bodies on purpose, and the portability
# guard forbids exactly that.
set(BYTE_MACHINE_CWD_MATRIX_DIR "${CMAKE_BINARY_DIR}/cwd-matrix")
set(BYTE_MACHINE_CWD_IDENTICAL_DIR "${BYTE_MACHINE_CWD_MATRIX_DIR}/same-name-identical")
set(BYTE_MACHINE_CWD_DECOY_DIR "${BYTE_MACHINE_CWD_MATRIX_DIR}/same-name-decoy")
set(BYTE_MACHINE_CWD_EMPTY_DIR "${BYTE_MACHINE_CWD_MATRIX_DIR}/empty")
file(MAKE_DIRECTORY "${BYTE_MACHINE_CWD_IDENTICAL_DIR}")
file(MAKE_DIRECTORY "${BYTE_MACHINE_CWD_DECOY_DIR}")
file(MAKE_DIRECTORY "${BYTE_MACHINE_CWD_EMPTY_DIR}")

# COPYONLY rather than file(COPY): configure_file records a dependency, so
# editing a body re-runs configure and refreshes the copies.
configure_file("${BYTE_MACHINE_SRC_COMMON_DIR}/placeholder.scm"
               "${BYTE_MACHINE_CWD_IDENTICAL_DIR}/placeholder.scm" COPYONLY)
configure_file("${BYTE_MACHINE_HARNESS_SHARED_DIR}/harness-runner.scm"
               "${BYTE_MACHINE_CWD_IDENTICAL_DIR}/harness-runner.scm" COPYONLY)
configure_file("${BYTE_MACHINE_HARNESS_SHARED_DIR}/harness-runner.scm"
               "${BYTE_MACHINE_CWD_DECOY_DIR}/harness-runner.scm" COPYONLY)
# fingerprint.scm (M0 slice 5a Task 1) is a second body the harness library
# includes, alongside harness-runner.scm above. The "every body the lane
# includes" rule in the comment above this block applies to it identically.
configure_file("${BYTE_MACHINE_HARNESS_SHARED_DIR}/fingerprint.scm"
               "${BYTE_MACHINE_CWD_IDENTICAL_DIR}/fingerprint.scm" COPYONLY)
configure_file("${BYTE_MACHINE_HARNESS_SHARED_DIR}/fingerprint.scm"
               "${BYTE_MACHINE_CWD_DECOY_DIR}/fingerprint.scm" COPYONLY)

# The impostor. It implements the complete export list on purpose: an
# incomplete one would fail the lane at library construction, which is a
# different failure. The claim under test is that resolution picked the wrong
# file, and that is only tested if the wrong file would otherwise work.
file(WRITE "${BYTE_MACHINE_CWD_DECOY_DIR}/placeholder.scm"
";;; Impostor placeholder body. Not part of the product.
;;;
;;; Shares a basename with src/common/byte-machine/placeholder.scm and answers
;;; every question wrongly. It is only ever reachable by an include that
;;; resolved against the process working directory, which is the defect
;;; byte-machine.portability.placeholder-cwd-decoy.* exists to catch.

(define (make-placeholder value) (vector 'decoy value))
(define (placeholder? x) #f)
(define (placeholder-value p) 'decoy)
(define (placeholder-marker) (vector 'decoy))
")

# --- Harness lanes ---------------------------------------------------------

# The harness must be able to fail before it can be trusted to pass. This is
# that proof: a body that fails one assertion, with the exact status compared
# from outside, because a program cannot report its own exit status.
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.failing-body.chez.source
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-failing.chez.sps"
  SHARED_BODIES ${BYTE_MACHINE_HARNESS_MANIFEST}
                "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-failing.scm"
  EXPECT_EXIT 1
  TIMEOUT 120
  LABELS expected-red)

# The runner cannot be its own only witness. This judges its primitives with
# raw conditionals, using none of the facilities it is checking.
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.bootstrap.chez.source
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-bootstrap.chez.sps"
  SHARED_BODIES ${BYTE_MACHINE_HARNESS_MANIFEST}
                "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-bootstrap.scm"
  TIMEOUT 120)

# The runner tested with the runner. Safe only because the bootstrap already
# established its primitives, and because every deliberate failure here runs
# inside a probe.
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.self.chez.source
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.chez.sps"
  SHARED_BODIES ${BYTE_MACHINE_HARNESS_MANIFEST}
                "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.scm"
  TIMEOUT 120)

# A duplicate id is a defect in the suite, not a failing assertion: one
# registration silently became unreachable. Status 2, distinct from 1.
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.duplicate-case.chez.source
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-duplicate-case.chez.sps"
  SHARED_BODIES ${BYTE_MACHINE_HARNESS_MANIFEST}
                "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-duplicate-case.scm"
  EXPECT_EXIT 2
  TIMEOUT 120
  LABELS expected-red)

# A suite that selected nothing must not report success, for the same reason
# the presets refuse an empty CTest selection one layer up.
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.empty-selection.chez.source
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-empty-selection.chez.sps"
  SHARED_BODIES ${BYTE_MACHINE_HARNESS_MANIFEST}
                "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-empty-selection.scm"
  EXPECT_EXIT 2
  TIMEOUT 120
  LABELS expected-red
  ENVIRONMENT "BYTE_MACHINE_TEST_FILTER=no-case-has-this-in-its-name")

# --- Gambit lanes ------------------------------------------------------------
#
# The same five bodies as above, unchanged, run through the Gambit adapter
# instead of the Chez one. This is the parity proof the milestone exists to
# establish: one wrapper-free body, two runtimes, no duplicated test
# semantics. See the rationale comments on the Chez lanes above for why each
# body exists; only the runtime differs here.
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.bootstrap.gambit.source
  BACKEND gambit
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-bootstrap.gambit.scm"
  SHARED_BODIES ${BYTE_MACHINE_HARNESS_MANIFEST}
                "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-bootstrap.scm"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.harness.self.gambit.source
  BACKEND gambit
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.gambit.scm"
  SHARED_BODIES ${BYTE_MACHINE_HARNESS_MANIFEST}
                "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.scm"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.harness.failing-body.gambit.source
  BACKEND gambit
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-failing.gambit.scm"
  SHARED_BODIES ${BYTE_MACHINE_HARNESS_MANIFEST}
                "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-failing.scm"
  EXPECT_EXIT 1
  TIMEOUT 120
  LABELS expected-red)

byte_machine_add_scheme_lane(
  NAME byte-machine.harness.duplicate-case.gambit.source
  BACKEND gambit
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-duplicate-case.gambit.scm"
  SHARED_BODIES ${BYTE_MACHINE_HARNESS_MANIFEST}
                "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-duplicate-case.scm"
  EXPECT_EXIT 2
  TIMEOUT 120
  LABELS expected-red)

byte_machine_add_scheme_lane(
  NAME byte-machine.harness.empty-selection.gambit.source
  BACKEND gambit
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-empty-selection.gambit.scm"
  SHARED_BODIES ${BYTE_MACHINE_HARNESS_MANIFEST}
                "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-empty-selection.scm"
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
# One runtime is enough. The decision lives in the shared runner body, which is
# identical text on both, and that is the same argument the mutation suite's
# first pass makes for every other decision in it.
#
# What this lane cannot check is that the line was printed. The harness has no
# portable way to read back its own output -- string ports are outside the
# common R6RS/R7RS subset -- and the registration layer asserts exit status, not
# output. Both decisions are therefore declared survivors in
# SchemeMutationSuite.cmake with their reason recorded, alongside probe output
# suppression, which is unwitnessable for exactly the same reason.
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.verbose.chez.source
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.chez.sps"
  SHARED_BODIES ${BYTE_MACHINE_HARNESS_MANIFEST}
                "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.scm"
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
            "--source-dir" "${BYTE_MACHINE_HARNESS_SHARED_DIR}"
            "--object-guard" "${BYTE_MACHINE_HARNESS_ABSENT_GUARD_DIR}"
            "--program" "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-bootstrap.chez.sps"
    EXPECT_EXIT 2
    TIMEOUT 120
    LABELS expected-red
    ENVIRONMENT "BYTE_MACHINE_EXECUTION_MODE=source")

  byte_machine_add_exit_code_test(
    NAME byte-machine.harness.launcher-dirty-guard.chez.source
    COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
            "--script" "${BYTE_MACHINE_HARNESS_CHEZ_LAUNCHER}"
            "--library-root" "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}"
            "--source-dir" "${BYTE_MACHINE_HARNESS_SHARED_DIR}"
            "--object-guard" "${BYTE_MACHINE_HARNESS_DIRTY_GUARD_DIR}"
            "--program" "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-bootstrap.chez.sps"
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
            "--source-dir" "${BYTE_MACHINE_HARNESS_SHARED_DIR}"
            "--object-guard" "${BYTE_MACHINE_HARNESS_OBJECT_GUARD_DIR}"
            "--librarie-root" "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}"
            "--program" "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-bootstrap.chez.sps"
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
            "--source-dir" "${BYTE_MACHINE_HARNESS_SHARED_DIR}"
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
            "--source-dir" "${BYTE_MACHINE_HARNESS_SHARED_DIR}"
            "--object-guard" "${BYTE_MACHINE_HARNESS_OBJECT_GUARD_DIR}"
            "--program" "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-bootstrap.chez.sps"
            "--program" "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.chez.sps"
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
            "--source-dir" "${BYTE_MACHINE_HARNESS_SHARED_DIR}"
            "--object-guard" "${BYTE_MACHINE_HARNESS_OBJECT_GUARD_DIR}"
            "--object-guard" "${BYTE_MACHINE_HARNESS_OBJECT_GUARD_DIR}"
            "--program" "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-bootstrap.chez.sps"
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
            "--source-dir" "${BYTE_MACHINE_HARNESS_SHARED_DIR}"
            "--object-guard" "${BYTE_MACHINE_HARNESS_OBJECT_GUARD_DIR}"
            "--program" "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-bootstrap.chez.sps"
    EXPECT_EXIT 2
    TIMEOUT 120
    LABELS expected-red
    ENVIRONMENT "BYTE_MACHINE_EXECUTION_MODE=source")

  byte_machine_add_exit_code_test(
    NAME byte-machine.harness.launcher-no-source-dir.chez.source
    COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
            "--script" "${BYTE_MACHINE_HARNESS_CHEZ_LAUNCHER}"
            "--library-root" "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}"
            "--object-guard" "${BYTE_MACHINE_HARNESS_OBJECT_GUARD_DIR}"
            "--program" "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-bootstrap.chez.sps"
    EXPECT_EXIT 2
    TIMEOUT 120
    LABELS expected-red
    ENVIRONMENT "BYTE_MACHINE_EXECUTION_MODE=source")

  byte_machine_add_exit_code_test(
    NAME byte-machine.harness.launcher-no-object-guard.chez.source
    COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
            "--script" "${BYTE_MACHINE_HARNESS_CHEZ_LAUNCHER}"
            "--library-root" "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}"
            "--source-dir" "${BYTE_MACHINE_HARNESS_SHARED_DIR}"
            "--program" "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-bootstrap.chez.sps"
    EXPECT_EXIT 2
    TIMEOUT 120
    LABELS expected-red
    ENVIRONMENT "BYTE_MACHINE_EXECUTION_MODE=source")
endif()

# --- Mutation proof for the harness ----------------------------------------

# The harness is the instrument every later milestone is measured with, so a
# passing self-test suite is not evidence until something has proved it can
# fail. This breaks each decision in the runner on a staged copy and requires
# the self-tests to notice. Registered only when a Chez was discovered: it runs
# a real lane and cannot be verified under the no-scheme preset. Gambit's path
# is forwarded too, empty when none was discovered, which drops only the pass
# that checks the Gambit adapter's export list.
#
# The self-tests load the fingerprint fixture through adapter-file-bytes; staged
# lanes inherit this process's environment through execute_process, so the
# variable must be set here.
if(BYTE_MACHINE_CHEZ_EXECUTABLE)
  byte_machine_add_test(
    NAME byte-machine.harness.scheme-mutation.cmake.direct
    COMMAND "${CMAKE_COMMAND}"
            "-DBYTE_MACHINE_CHEZ_EXECUTABLE=${BYTE_MACHINE_CHEZ_EXECUTABLE}"
            "-DBYTE_MACHINE_GAMBIT_EXECUTABLE=${BYTE_MACHINE_GAMBIT_EXECUTABLE}"
            "-DBYTE_MACHINE_CWD_MATRIX_DIR=${BYTE_MACHINE_CWD_MATRIX_DIR}"
            -P "${CMAKE_CURRENT_LIST_DIR}/support/cmake/SchemeMutationSuite.cmake"
    TIMEOUT 900
    LABELS unit
    ENVIRONMENT "BYTE_MACHINE_EXECUTION_MODE=source"
                "BYTE_MACHINE_FINGERPRINT_SAMPLE=${CMAKE_SOURCE_DIR}/test/fixtures/fingerprint-sample.bin")
endif()

# --- The placeholder library, from three working directories ---------------
#
# Same program, same body, three launch directories. See the matrix comment
# above for what each one catches and why passing here is not yet evidence.
foreach(cwd_case identical decoy empty)
  if(cwd_case STREQUAL "identical")
    set(cwd_dir "${BYTE_MACHINE_CWD_IDENTICAL_DIR}")
  elseif(cwd_case STREQUAL "decoy")
    set(cwd_dir "${BYTE_MACHINE_CWD_DECOY_DIR}")
  else()
    set(cwd_dir "${BYTE_MACHINE_CWD_EMPTY_DIR}")
  endif()

  byte_machine_add_scheme_lane(
    NAME "byte-machine.portability.placeholder-cwd-${cwd_case}.chez.source"
    BACKEND chez
    PROGRAM "${BYTE_MACHINE_TEST_COMMON_DIR}/placeholder-tests.chez.sps"
    SHARED_BODIES ${BYTE_MACHINE_HARNESS_MANIFEST}
                  "${BYTE_MACHINE_SRC_COMMON_DIR}/placeholder.scm"
                  "${BYTE_MACHINE_TEST_COMMON_DIR}/placeholder-tests.scm"
    TIMEOUT 120
    WORKING_DIRECTORY "${cwd_dir}")

  byte_machine_add_scheme_lane(
    NAME "byte-machine.portability.placeholder-cwd-${cwd_case}.gambit.source"
    BACKEND gambit
    PROGRAM "${BYTE_MACHINE_TEST_COMMON_DIR}/placeholder-tests.gambit.scm"
    SHARED_BODIES ${BYTE_MACHINE_HARNESS_MANIFEST}
                  "${BYTE_MACHINE_SRC_COMMON_DIR}/placeholder.scm"
                  "${BYTE_MACHINE_TEST_COMMON_DIR}/placeholder-tests.scm"
    TIMEOUT 120
    WORKING_DIRECTORY "${cwd_dir}")
endforeach()

# --- Cross-library identity ------------------------------------------------
#
# Slice 4, deliverable D3. One body, two libraries: the owner constructs, the
# consumer -- which imported the owner rather than including its body again --
# recognises, and the allocation-free singleton stays one object across both
# imports.
#
# No working-directory matrix here. The consumer adds a second include site per
# runtime but no new resolution mechanism: Chez resolves it by bare filename
# through source-directories exactly as it resolves the owner's body, and Gambit
# resolves it relative to the including file exactly as before. Slice 3 proved
# that mechanism; a second instance of a proven mechanism is not a second proof.
#
# Passing here is not yet evidence. What makes it evidence is passes 24 to 27 in
# SchemeMutationSuite.cmake, and in particular the double-include mutation --
# under which both cases below answer wrongly, nothing raises, and every other
# lane in this tree still passes.
byte_machine_add_scheme_lane(
  NAME byte-machine.portability.placeholder-identity.chez.source
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_TEST_COMMON_DIR}/placeholder-identity-tests.chez.sps"
  SHARED_BODIES ${BYTE_MACHINE_HARNESS_MANIFEST}
                "${BYTE_MACHINE_SRC_COMMON_DIR}/placeholder.scm"
                "${BYTE_MACHINE_SRC_COMMON_DIR}/placeholder-consumer.scm"
                "${BYTE_MACHINE_TEST_COMMON_DIR}/placeholder-identity-tests.scm"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.portability.placeholder-identity.gambit.source
  BACKEND gambit
  PROGRAM "${BYTE_MACHINE_TEST_COMMON_DIR}/placeholder-identity-tests.gambit.scm"
  SHARED_BODIES ${BYTE_MACHINE_HARNESS_MANIFEST}
                "${BYTE_MACHINE_SRC_COMMON_DIR}/placeholder.scm"
                "${BYTE_MACHINE_SRC_COMMON_DIR}/placeholder-consumer.scm"
                "${BYTE_MACHINE_TEST_COMMON_DIR}/placeholder-identity-tests.scm"
  TIMEOUT 120)

# --- Provenance ------------------------------------------------------------
#
# Every lane above checks the fingerprint of the text it ran against the value
# the build computed. These prove that check can fail. Without them the
# mechanism would be a claim: protium recorded two occasions where two of its
# lanes printed different digests for text both said they ran, and the suite
# stayed green, because nothing read the values back.
#
# Status 3 is what makes them falsifiable. Six lanes in this tree legitimately
# expect 1 or 2, so a provenance failure sharing either status would be
# indistinguishable from those fixtures' own expected outcomes.
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.provenance.chez.source
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.chez.sps"
  SHARED_BODIES ${BYTE_MACHINE_HARNESS_MANIFEST}
                "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.scm"
  WRONG_FINGERPRINT
  EXPECT_EXIT 3
  TIMEOUT 120
  LABELS expected-red)

# The Gambit half. This one is not a duplicate of the Chez lane: the path it
# exercises reads the expectation through adapter-file-bytes, which is
# per-runtime code, and exits through adapter-exit. The two refusals below run
# on Chez alone under slice 2's rule S6 -- they are decisions in the shared
# runner body, identical text on both runtimes, and this pair already
# establishes that both reach it.
#
# Three of the four are textually inside this if(BYTE_MACHINE_CHEZ_EXECUTABLE)
# block; the fourth, byte-machine.harness.provenance.chez.source above, is
# skipped on a Chez-less host by a different mechanism:
# byte_machine_add_scheme_lane's own no-runtime return for a chez-backend
# lane. byte_machine_expected_fingerprint runs its launcher under Chez, and
# ByteMachineSchemeLane.cmake gates the call to either fingerprint function --
# byte_machine_wrong_fingerprint included -- on that same discovered-Chez
# check, so on a Chez-less host neither BYTE_MACHINE_FINGERPRINT_FILES nor
# BYTE_MACHINE_EXPECT_FINGERPRINT_FILE is ever set for this Gambit lane, its
# own runtime notwithstanding -- and harness-verify-provenance! skips rather
# than refuses when the manifest variable is unset. Without this guard the
# lane would still run, still find nothing to disagree with, and exit 0 where
# EXPECT_EXIT 3 requires 3.
if(BYTE_MACHINE_CHEZ_EXECUTABLE)
  byte_machine_add_scheme_lane(
    NAME byte-machine.harness.provenance.gambit.source
    BACKEND gambit
    PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.gambit.scm"
    SHARED_BODIES ${BYTE_MACHINE_HARNESS_MANIFEST}
                  "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.scm"
    WRONG_FINGERPRINT
    EXPECT_EXIT 3
    TIMEOUT 120
    LABELS expected-red)

  # The build never produced this file, and never will: no rule names it as an
  # output. That is the "you did not build before running the tests" case, which
  # would otherwise escape as a raw I/O condition and a status outside the
  # vocabulary.
  byte_machine_add_scheme_lane(
    NAME byte-machine.harness.provenance-absent-expectation.chez.source
    BACKEND chez
    PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.chez.sps"
    SHARED_BODIES ${BYTE_MACHINE_HARNESS_MANIFEST}
                  "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.scm"
    EXPECT_EXIT 3
    TIMEOUT 120
    LABELS expected-red
    ENVIRONMENT "BYTE_MACHINE_EXPECT_FINGERPRINT_FILE=${CMAKE_BINARY_DIR}/fingerprints/never-produced.fingerprint")

  # A manifest naming a body that is not there. What fails is reading the text,
  # before any comparison happens.
  byte_machine_add_scheme_lane(
    NAME byte-machine.harness.provenance-missing-body.chez.source
    BACKEND chez
    PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.chez.sps"
    SHARED_BODIES ${BYTE_MACHINE_HARNESS_MANIFEST}
                  "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.scm"
    EXPECT_EXIT 3
    TIMEOUT 120
    LABELS expected-red
    ENVIRONMENT "BYTE_MACHINE_FINGERPRINT_FILES=${CMAKE_BINARY_DIR}/fingerprints/no-such-body.scm")
endif()

# Provenance configured and never performed. SHARED_BODIES guarantees the
# environment carries a manifest; nothing until now guaranteed anything read
# it. This body reaches harness-summary without ever reaching
# harness-verify-provenance!, which is precisely the shape harness-bootstrap
# would have had if its hand-placed call had been forgotten -- and that would
# have run un-provenanced with nothing failing.
#
# A real manifest, deliberately: with none, the run is a process no lane
# registration started, and skipping is correct rather than a defect.
#
# Both lanes below expect exit 3 for the same reason byte-machine.harness.
# provenance.gambit.source above does: ByteMachineSchemeLane.cmake sets
# BYTE_MACHINE_FINGERPRINT_FILES only inside its own
# if(BYTE_MACHINE_CHEZ_EXECUTABLE) block, regardless of either lane's own
# BACKEND here. On a host with Gambit but no Chez, the Gambit lane is still
# registered -- its own runtime was found, so byte_machine_add_scheme_lane's
# no-runtime return does not apply to it -- but it carries no manifest, so
# harness-provenance-reachability-diagnosis finds an empty
# BYTE_MACHINE_FINGERPRINT_FILES and stays quiet, the same as a process no
# lane registration started. harness-provenance-unreached never gets set,
# harness-exit-status falls through to harness-status-pass, and the lane
# exits 0 where EXPECT_EXIT 3 requires 3. The Chez lane is wrapped here too,
# even though it would already self-gate on a Chez-less host through the
# same no-runtime return -- kept alongside the Gambit lane rather than left
# to stand alone, matching how the two Chez-backend lanes above stay inside
# the Gambit provenance lane's own if(BYTE_MACHINE_CHEZ_EXECUTABLE) block.
if(BYTE_MACHINE_CHEZ_EXECUTABLE)
  byte_machine_add_scheme_lane(
    NAME byte-machine.harness.unreached-provenance.chez.source
    BACKEND chez
    PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-unreached-provenance.chez.sps"
    SHARED_BODIES ${BYTE_MACHINE_HARNESS_MANIFEST}
                  "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-unreached-provenance.scm"
    EXPECT_EXIT 3
    TIMEOUT 120
    LABELS expected-red)

  byte_machine_add_scheme_lane(
    NAME byte-machine.harness.unreached-provenance.gambit.source
    BACKEND gambit
    PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-unreached-provenance.gambit.scm"
    SHARED_BODIES ${BYTE_MACHINE_HARNESS_MANIFEST}
                  "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-unreached-provenance.scm"
    EXPECT_EXIT 3
    TIMEOUT 120
    LABELS expected-red)
endif()
