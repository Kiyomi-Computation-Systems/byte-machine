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
