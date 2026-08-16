# byte-machine: a byte-oriented deterministic state-machine generator for
# Chez and Gambit Scheme.
#
# CMake is the canonical build frontend on every platform, with a thin Makefile
# over it for the usual Unix entry points.
#
# The 3.26 floor is set by the preset schema this project uses -- version 6,
# which requires 3.25 -- plus a margin. It is not what enables JUnit output or
# refusing an empty test selection; both of those arrive earlier, in 3.21. Only
# 4.3.3 has actually been exercised, so 3.26 is a declared floor rather than a
# tested one (docs/decisions/0001-toolchain-discovery.md).
#
# LANGUAGES NONE is deliberate: byte-machine has no C of its own. Gambit's `gsc`
# shells out to a C compiler for its native lanes, but that toolchain belongs to
# Gambit's own installation and is not configured here -- so asking CMake for a
# C compiler would impose a requirement the project does not have and would fail
# on hosts where only the source lanes are wanted.
cmake_minimum_required(VERSION 3.26)

project(byte-machine
  VERSION 0.1.0
  DESCRIPTION "Byte-oriented deterministic state-machine generator for Chez and Gambit Scheme"
  HOMEPAGE_URL "https://github.com/Kiyomi-Computation-Systems/byte-machine"
  LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/cmake")

option(BYTE_MACHINE_BUILD_TESTS "Build the test suite" ${PROJECT_IS_TOP_LEVEL})

# Discovery is opt-out so the CMake-layer specifications can be configured and
# run on a host with neither Scheme installed. Every lane that needs a runtime
# is registered only when its runtime was found.
option(BYTE_MACHINE_REQUIRE_CHEZ "Require a usable Chez Scheme at configure time" ON)
option(BYTE_MACHINE_REQUIRE_GAMBIT "Require a usable Gambit Scheme at configure time" ON)

include(ByteMachineChez)
include(ByteMachineGambit)

if(BYTE_MACHINE_REQUIRE_CHEZ)
  byte_machine_chez_discover()
endif()

if(BYTE_MACHINE_REQUIRE_GAMBIT)
  byte_machine_gambit_discover()
endif()

if(BYTE_MACHINE_BUILD_TESTS)
  enable_testing()
  # CTest will not create the directory for --output-junit itself.
  file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/test-results")
  include(ByteMachineTesting)
  include(ByteMachineExpectExit)
  include(ByteMachineSchemeLane)
  add_subdirectory(test)
endif()

message(STATUS
  "byte-machine ${PROJECT_VERSION}: tests=${BYTE_MACHINE_BUILD_TESTS} "
  "chez=${BYTE_MACHINE_REQUIRE_CHEZ} gambit=${BYTE_MACHINE_REQUIRE_GAMBIT}")
