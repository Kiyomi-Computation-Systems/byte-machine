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

# Checked before any lane is registered: a body missing a wrapper must stop the
# build, not produce a suite that quietly proves one runtime.
byte_machine_portability_guard(
  SHARED_DIRS "${BYTE_MACHINE_HARNESS_SHARED_DIR}"
  WRAPPED_DIRS "${BYTE_MACHINE_HARNESS_SELF_DIR}")

byte_machine_add_test(
  NAME byte-machine.harness.cmake-portability-guard.cmake.direct
  COMMAND "${CMAKE_COMMAND}" -P
          "${CMAKE_CURRENT_LIST_DIR}/support/cmake/ByteMachinePortabilityGuardSpec.cmake"
  TIMEOUT 120
  LABELS unit)

# --- Harness lanes ---------------------------------------------------------

# The harness must be able to fail before it can be trusted to pass. This is
# that proof: a body that fails one assertion, with the exact status compared
# from outside, because a program cannot report its own exit status.
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.failing-body.chez.source
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-failing.chez.sps"
  EXPECT_EXIT 1
  TIMEOUT 120
  LABELS expected-red)

# The runner cannot be its own only witness. This judges its primitives with
# raw conditionals, using none of the facilities it is checking.
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.bootstrap.chez.source
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-bootstrap.chez.sps"
  TIMEOUT 120)

# The runner tested with the runner. Safe only because the bootstrap already
# established its primitives, and because every deliberate failure here runs
# inside a probe.
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.self.chez.source
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.chez.sps"
  TIMEOUT 120)

# A duplicate id is a defect in the suite, not a failing assertion: one
# registration silently became unreachable. Status 2, distinct from 1.
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.duplicate-case.chez.source
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-duplicate-case.chez.sps"
  EXPECT_EXIT 2
  TIMEOUT 120
  LABELS expected-red)

# A suite that selected nothing must not report success, for the same reason
# the presets refuse an empty CTest selection one layer up.
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.empty-selection.chez.source
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-empty-selection.chez.sps"
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
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.harness.self.gambit.source
  BACKEND gambit
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.gambit.scm"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.harness.failing-body.gambit.source
  BACKEND gambit
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-failing.gambit.scm"
  EXPECT_EXIT 1
  TIMEOUT 120
  LABELS expected-red)

byte_machine_add_scheme_lane(
  NAME byte-machine.harness.duplicate-case.gambit.source
  BACKEND gambit
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-duplicate-case.gambit.scm"
  EXPECT_EXIT 2
  TIMEOUT 120
  LABELS expected-red)

byte_machine_add_scheme_lane(
  NAME byte-machine.harness.empty-selection.gambit.source
  BACKEND gambit
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-empty-selection.gambit.scm"
  EXPECT_EXIT 2
  TIMEOUT 120
  LABELS expected-red
  ENVIRONMENT "BYTE_MACHINE_TEST_FILTER=no-case-has-this-in-its-name")

# --- Mutation proof for the harness ----------------------------------------

# The harness is the instrument every later milestone is measured with, so a
# passing self-test suite is not evidence until something has proved it can
# fail. This breaks each decision in the runner on a staged copy and requires
# the self-tests to notice. Registered only when a Chez was discovered: it runs
# a real lane and cannot be verified under the no-scheme preset. Gambit's path
# is forwarded too, empty when none was discovered, which drops only the pass
# that checks the Gambit adapter's export list.
if(BYTE_MACHINE_CHEZ_EXECUTABLE)
  byte_machine_add_test(
    NAME byte-machine.harness.scheme-mutation.cmake.direct
    COMMAND "${CMAKE_COMMAND}"
            "-DBYTE_MACHINE_CHEZ_EXECUTABLE=${BYTE_MACHINE_CHEZ_EXECUTABLE}"
            "-DBYTE_MACHINE_GAMBIT_EXECUTABLE=${BYTE_MACHINE_GAMBIT_EXECUTABLE}"
            -P "${CMAKE_CURRENT_LIST_DIR}/support/cmake/SchemeMutationSuite.cmake"
    TIMEOUT 900
    LABELS unit
    ENVIRONMENT "BYTE_MACHINE_EXECUTION_MODE=source")
endif()
