# Specification for cmake/ByteMachineSchemeLane.cmake.
#
# A lane's command line is where a source lane quietly stops being a source
# lane. Chez needs its object-guard pair to make a compiled object unloadable,
# and Gambit needs -f so a developer's .gambini cannot change a test result.
# Both are invisible when they are missing: the lane still runs and still
# passes, having proved something other than what it claims.

cmake_minimum_required(VERSION 3.26)

include("${CMAKE_CURRENT_LIST_DIR}/../../../cmake/ByteMachineSchemeLane.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/SpecSupport.cmake")

set(SPEC_SELF "${CMAKE_CURRENT_LIST_FILE}")

if(DEFINED BYTE_MACHINE_SPEC_CASE)
  set(c "${BYTE_MACHINE_SPEC_CASE}")

  # Neither registrar belongs to a project context this script does not have
  # -- add_test is not scriptable under cmake -P. Stubbing both is what keeps
  # a rejection that stopped rejecting from crashing on that unrelated error
  # instead of falling through to the "must be rejected" check below, which is
  # what actually proves the case.
  function(byte_machine_add_test)
  endfunction()
  function(byte_machine_add_exit_code_test)
  endfunction()

  if(c STREQUAL "lane-rejects-unparsed-arguments")
    byte_machine_add_scheme_lane(
      NAME byte-machine.harness.example.chez.source
      BACKEND chez
      PROGRAM "${SPEC_SELF}"
      TIMEOUT 10
      unexpected-extra-argument)
  elseif(c STREQUAL "lane-requires-name")
    byte_machine_add_scheme_lane(
      BACKEND chez
      PROGRAM "${SPEC_SELF}"
      TIMEOUT 10)
  elseif(c STREQUAL "lane-requires-backend")
    byte_machine_add_scheme_lane(
      NAME byte-machine.harness.example.chez.source
      PROGRAM "${SPEC_SELF}"
      TIMEOUT 10)
  elseif(c STREQUAL "lane-requires-program")
    byte_machine_add_scheme_lane(
      NAME byte-machine.harness.example.chez.source
      BACKEND chez
      TIMEOUT 10)
  elseif(c STREQUAL "lane-requires-timeout")
    byte_machine_add_scheme_lane(
      NAME byte-machine.harness.example.chez.source
      BACKEND chez
      PROGRAM "${SPEC_SELF}")
  elseif(c STREQUAL "lane-requires-shared-bodies")
    byte_machine_add_scheme_lane(
      NAME byte-machine.harness.example.chez.source
      BACKEND chez
      PROGRAM "${SPEC_SELF}"
      TIMEOUT 10)
  elseif(c STREQUAL "lane-requires-existing-program")
    byte_machine_add_scheme_lane(
      NAME byte-machine.harness.example.chez.source
      BACKEND chez
      PROGRAM "/h/self/does-not-exist.chez.sps"
      SHARED_BODIES "${SPEC_SELF}"
      TIMEOUT 10)
  elseif(c STREQUAL "lane-rejects-missing-shared-body")
    byte_machine_add_scheme_lane(
      NAME byte-machine.harness.example.chez.source
      BACKEND chez
      PROGRAM "${SPEC_SELF}"
      SHARED_BODIES "${SPEC_SELF}" "/nonexistent/body.scm"
      TIMEOUT 10)
  elseif(c STREQUAL "lane-rejects-unknown-backend")
    byte_machine_add_scheme_lane(
      NAME byte-machine.harness.example.chez.source
      BACKEND guile
      PROGRAM "${SPEC_SELF}"
      SHARED_BODIES "${SPEC_SELF}"
      TIMEOUT 10)
  elseif(c STREQUAL "lane-rejects-relative-gambit-root")
    set(BYTE_MACHINE_GAMBIT_EXECUTABLE "/opt/gsi")
    set(BYTE_MACHINE_HARNESS_GAMBIT_LIBRARY_ROOT "h/gambit")
    set(BYTE_MACHINE_SRC_GAMBIT_LIBRARY_ROOT "/s/gambit")
    byte_machine_add_scheme_lane(
      NAME byte-machine.harness.example.gambit.source
      BACKEND gambit
      PROGRAM "${SPEC_SELF}"
      SHARED_BODIES "${SPEC_SELF}"
      TIMEOUT 10)
  elseif(c STREQUAL "lane-rejects-comma-in-gambit-root")
    set(BYTE_MACHINE_GAMBIT_EXECUTABLE "/opt/gsi")
    set(BYTE_MACHINE_HARNESS_GAMBIT_LIBRARY_ROOT "/h/gam,bit")
    set(BYTE_MACHINE_SRC_GAMBIT_LIBRARY_ROOT "/s/gambit")
    byte_machine_add_scheme_lane(
      NAME byte-machine.harness.example.gambit.source
      BACKEND gambit
      PROGRAM "${SPEC_SELF}"
      SHARED_BODIES "${SPEC_SELF}"
      TIMEOUT 10)
  else()
    message(FATAL_ERROR "byte-machine-spec: unknown case '${c}'")
  endif()

  message(FATAL_ERROR "byte-machine-spec: case '${c}' was accepted but must be rejected")
endif()

set(BYTE_MACHINE_HARNESS_CHEZ_LAUNCHER "/h/launchers/chez-source.ss")
set(BYTE_MACHINE_CHEZ_OBJECT_ROOT "/objects")
set(BYTE_MACHINE_HARNESS_CHEZ_AOT_LAUNCHER "/launchers/chez-aot.ss")
set(BYTE_MACHINE_HARNESS_CHEZ_COMPILE_LAUNCHER "/launchers/chez-compile.ss")
set(BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT "/h/chez")
set(BYTE_MACHINE_HARNESS_GAMBIT_LIBRARY_ROOT "/h/gambit")
set(BYTE_MACHINE_HARNESS_SHARED_DIR "/h/shared")
set(BYTE_MACHINE_HARNESS_OBJECT_GUARD_DIR "/b/guard")
set(BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT "/s/chez")
set(BYTE_MACHINE_SRC_GAMBIT_LIBRARY_ROOT "/s/gambit")
set(BYTE_MACHINE_SRC_COMMON_DIR "/s/common/byte-machine")

# --- Chez ------------------------------------------------------------------

set(BYTE_MACHINE_CHEZ_EXECUTABLE "/opt/chez")
byte_machine_scheme_lane_command(byte-machine.harness.example.chez.source
  chez source "/h/self/p.chez.sps" command measured status message)
spec_check_equal("${status}" "ok" "chez lane classifies")
spec_check_equal("${command}"
  "/opt/chez;--script;/h/launchers/chez-source.ss;--library-root;/h/chez;--library-root;/s/chez;--source-dir;/h/shared;--source-dir;/s/common/byte-machine;--object-guard;/b/guard;--program;/h/self/p.chez.sps"
  "chez lane command line")

# The guard directory is the entire mechanism that stops a stale .so from being
# loaded in a lane that calls itself source. Asserted through its flag rather
# than by position: with a repeatable-flag protocol a position is no longer
# stable, and a lane that dropped the guard would still run.
list(FIND command "--object-guard" guard_index)
math(EXPR guard_value_index "${guard_index} + 1")
list(GET command "${guard_value_index}" guard)
spec_check_equal("${guard}" "/b/guard" "chez lane passes the object guard directory")

# --- Gambit ----------------------------------------------------------------

set(BYTE_MACHINE_GAMBIT_EXECUTABLE "/opt/gsi")
byte_machine_scheme_lane_command(byte-machine.harness.example.gambit.source
  gambit source "/h/self/p.gambit.scm" command measured status message)
spec_check_equal("${status}" "ok" "gambit lane classifies")
spec_check_equal("${command}"
  "/opt/gsi;-:search=/h/gambit,search=/s/gambit;-f;/h/self/p.gambit.scm"
  "gambit lane command line")

# Gambit requires its -: runtime options to be the very first argument, and -f
# must be present or a developer's .gambini can change what a test proves.
list(GET command 1 first_option)
spec_check_equal("${first_option}" "-:search=/h/gambit,search=/s/gambit"
  "gambit runtime option comes first")
list(FIND command "-f" f_index)
spec_check_equal("${f_index}" "2" "gambit lane skips initialisation files")

# --- The Gambit search list ------------------------------------------------
#
# Gambit's -: options are comma-separated, so a search root containing a comma
# does not produce a wrong path: gsi prints its runtime-options usage banner and
# runs no Scheme at all, naming nothing this project owns. Measured on
# 2026-08-16; see docs/plans/milestone-0-slice-3-shared-body.md section 2.
byte_machine_scheme_lane_gambit_search(option status message "/a" "/b")
spec_check_equal("${status}" "ok" "two roots are accepted")
spec_check_equal("${option}" "-:search=/a,search=/b" "two roots join with a comma")

byte_machine_scheme_lane_gambit_search(option status message "/a")
spec_check_equal("${option}" "-:search=/a" "one root needs no separator")

byte_machine_scheme_lane_gambit_search(option status message "/a" "/b,c")
spec_check_equal("${status}" "comma-in-path" "a comma in a root is rejected")
spec_check_equal("${option}" "" "a rejected search list yields no option")
spec_check_equal("${message}"
  "a Gambit search root must not contain a comma, but '/b,c' does. Gambit's -: options are comma-separated, so gsi would print its usage banner and run no Scheme at all."
  "comma rejection message")

# A relative root is refused for a different reason than a comma, and needs its
# own status: gsi resolves it against its own working directory, so the lane
# would find its libraries or not depending on where CTest happened to launch
# it -- which is the one thing the working-directory matrix exists to rule out.
# Nothing else can see this: ByteMachineSchemeLaneSpec sets its own fixture
# paths, so it cannot notice test/CMakeLists.txt handing over a relative one.
byte_machine_scheme_lane_gambit_search(option status message "/a" "relative/root")
spec_check_equal("${status}" "relative-path" "a relative root is rejected")
spec_check_equal("${option}" "" "a rejected search list yields no option")
spec_check_equal("${message}"
  "a Gambit search root must be absolute, but 'relative/root' is not. Gambit resolves a relative root against its own working directory, so the lane would find its libraries or not depending on where it was launched."
  "relative root message")

# A root that is both relative and contains a comma must report
# comma-in-path, not relative-path: the comma check runs first, and that is
# the useful precedence, because a comma malforms the -: option list and
# silences gsi -- and therefore every Gambit lane at once -- while a relative
# root only misleads the one lane that carries it. Nothing else in this
# specification can see the two checks swapped: every other case here
# supplies a root with exactly one defect, so either order produces the same
# status.
byte_machine_scheme_lane_gambit_search(option status message "/a" "rel,ative/root")
spec_check_equal("${status}" "comma-in-path"
  "a root with both defects is rejected for the comma, not the relative path")

# Seeded with sentinel values no correct call could produce. An assertion
# against an unseeded variable is satisfied by a function that does nothing
# at all: CMake variables persist across calls, so an unseeded "message"
# could already read "" by coincidence, and a deleted up-front clear would go
# unnoticed. The function never writes its message on the success path -- the
# up-front clear is the only thing that empties it there -- so a seeded
# sentinel surviving to this assertion is exactly the defect.
set(option "sentinel-option")
set(message "sentinel-message")
byte_machine_scheme_lane_gambit_search(option status message "/a")
spec_check_equal("${message}" "" "an accepted search list clears the message")

# Same seeding, on the rejection path. The function never writes the option
# once it has decided to reject, so again the up-front clear is the only
# thing that empties it, and a seeded sentinel surviving would be the same
# defect on the other output.
set(option "sentinel-option")
set(message "sentinel-message")
byte_machine_scheme_lane_gambit_search(option status message "/a" "/b,c")
spec_check_equal("${option}" "" "a rejected search list clears the option")

# --- Rejections ------------------------------------------------------------

# Diagnostics carry a stable prefix precisely so a specification can assert the
# exact wording, not merely a nonzero status. Asserted here for all three
# messages the functional core can produce: a typo, a dropped interpolation, or
# a garbled string would otherwise pass every existing assertion undetected.
byte_machine_scheme_lane_command(byte-machine.harness.example.guile.source
  guile source "/h/self/p.scm" command measured status message)
spec_check_equal("${status}" "unknown-backend" "an unknown backend is rejected")
spec_check_equal("${message}"
  "'guile' is not a Scheme lane backend. Known backends: chez gambit."
  "unknown backend message")

set(BYTE_MACHINE_CHEZ_EXECUTABLE "")
byte_machine_scheme_lane_command(byte-machine.harness.example.chez.source
  chez source "/h/self/p.chez.sps" command measured status message)
spec_check_equal("${status}" "no-runtime" "a chez lane without a chez is not registered")
spec_check_equal("${command}" "" "a rejected lane returns no command")
spec_check_equal("${message}"
  "no Chez was discovered, so the chez source lane for '/h/self/p.chez.sps' is not registered."
  "chez lane no-runtime message")

# Both no-runtime REPLACEs in MutationSuite.cmake hardcode the literal
# "source" (see that file's own comment on this exact hazard), so a mutation
# that reverted ${mode} back to a hardcoded "source" would pass every
# assertion above -- every one of them calls with mode source. Asserted here
# with mode aot instead, the one mode value able to tell the fixed code from
# the reverted one.
byte_machine_scheme_lane_command(byte-machine.harness.example.chez.aot
  chez aot "/h/self/p.chez.sps" command measured status message)
spec_check_equal("${status}" "no-runtime" "a chez aot lane without a chez is not registered")
spec_check_equal("${command}" "" "a rejected lane returns no command")
spec_check_equal("${message}"
  "no Chez was discovered, so the chez aot lane for '/h/self/p.chez.sps' is not registered."
  "chez lane no-runtime message names the aot mode, not a hardcoded source")

set(BYTE_MACHINE_GAMBIT_EXECUTABLE "")
byte_machine_scheme_lane_command(byte-machine.harness.example.gambit.source
  gambit source "/h/self/p.gambit.scm" command measured status message)
spec_check_equal("${status}" "no-runtime" "a gambit lane without a gambit is not registered")
spec_check_equal("${message}"
  "no Gambit was discovered, so the gambit source lane for '/h/self/p.gambit.scm' is not registered."
  "gambit lane no-runtime message")

# --- Declared bodies versus measured bodies --------------------------------
#
# A source lane reads the repository sources, so the two lists coincide and
# the distinction is invisible. It is not invisible for a compiled lane, where
# the expectation is computed from the originals and the run must read what
# the artifact was actually built from -- and this is the one place a
# specification can see the rule with no runtime present.
set(BYTE_MACHINE_CHEZ_EXECUTABLE "/opt/chez")
byte_machine_scheme_lane_command(byte-machine.harness.example.chez.source
  chez source "/h/self/p.chez.sps"
  command measured status message "/h/shared/a.scm" "/h/shared/b.scm")
spec_check_equal("${status}" "ok" "a chez source lane is accepted")
spec_check_equal("${measured}" "/h/shared/a.scm;/h/shared/b.scm"
  "a source lane measures the bodies it declares, in the declared order")

byte_machine_scheme_lane_command(byte-machine.harness.example.chez.unknown-mode-name
  chez unknown-mode-name "/h/self/p.chez.sps"
  command measured status message "/h/shared/a.scm")
spec_check_equal("${status}" "unknown-mode" "an unregistered mode is rejected")
spec_check_equal("${command}" "" "a rejected lane returns no command")
spec_check_equal("${measured}" "" "a rejected lane measures nothing")
spec_check_equal("${message}"
  "'unknown-mode-name' is not an execution mode this lane module can build a command for. Known modes: source aot."
  "unknown mode message")

# --- Gambit's narrower mode vocabulary --------------------------------------
#
# .gambit.aot and .gambit.o1 are legal lane names -- BYTE_MACHINE_TEST_MODES_gambit
# in ByteMachineTesting.cmake accepts both -- so both reach this branch, even
# though this module can only build a Gambit command for source today. Tested
# with mode aot specifically, because that is the self-refuting case for the
# message the Chez and Gambit branches used to share: it named its own
# rejected mode among the "known" modes it listed. The Gambit branch's message
# is backend-scoped now, so it cannot make that claim.
set(BYTE_MACHINE_GAMBIT_EXECUTABLE "/opt/gsi")
byte_machine_scheme_lane_command(byte-machine.harness.example.gambit.aot
  gambit aot "/h/self/p.gambit.scm" command measured status message)
spec_check_equal("${status}" "unknown-mode" "gambit rejects a mode it cannot build yet")
spec_check_equal("${command}" "" "a rejected lane returns no command")
spec_check_equal("${measured}" "" "a rejected lane measures nothing")
spec_check_equal("${message}"
  "'aot' is not an execution mode the gambit backend of this lane module can build a command for yet. Known modes: source. Gambit's compiled modes (o1, aot) arrive in a later slice."
  "gambit's unknown-mode message names only what gambit can build today, not the mode it just rejected")

# --- Registration (byte_machine_add_scheme_lane) ----------------------------
#
# add_test is not scriptable under cmake -P, so the two registrars are stubbed
# here too, this time to record which one byte_machine_add_scheme_lane reached
# and with what arguments rather than to stand aside for a rejection. Routing
# and the environment prefix live directly in this function with no pure
# helper underneath, so stubbing its two dependencies is the only way to
# observe them at all.
# Both stubs below record WORKING_DIRECTORY two ways: the value cmake_parse_arguments
# extracted, and whether the literal "WORKING_DIRECTORY" keyword appears anywhere
# in the raw argument list at all. The second is not redundant with the first. A
# lane that omitted WORKING_DIRECTORY and a lane that forwarded it with an empty
# value can both leave the parsed variable unset at this project's declared 3.26
# floor (CMP0174, which would tell them apart, is 3.31+) -- so only a scan of the
# raw arguments can tell "the keyword never appeared" from "it appeared with
# nothing after it", and the whole point of ByteMachineSchemeLane.cmake building
# working_directory_args conditionally is to never produce the second shape.
function(byte_machine_add_test)
  cmake_parse_arguments(PARSE_ARGV 0 s "" "NAME;TIMEOUT;WORKING_DIRECTORY" "COMMAND;LABELS;ENVIRONMENT")
  set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_REGISTRAR "plain")
  set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_ENVIRONMENT "${s_ENVIRONMENT}")
  set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_WORKING_DIRECTORY "${s_WORKING_DIRECTORY}")
  list(FIND ARGN "WORKING_DIRECTORY" wd_at)
  if(wd_at EQUAL -1)
    set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_WORKING_DIRECTORY_KEYWORD "absent")
  else()
    set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_WORKING_DIRECTORY_KEYWORD "present")
  endif()
endfunction()

function(byte_machine_add_exit_code_test)
  cmake_parse_arguments(PARSE_ARGV 0 s "" "NAME;EXPECT_EXIT;TIMEOUT;WORKING_DIRECTORY" "COMMAND;LABELS;ENVIRONMENT")
  set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_REGISTRAR "exit-code")
  set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_EXPECT_EXIT "${s_EXPECT_EXIT}")
  set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_ENVIRONMENT "${s_ENVIRONMENT}")
  set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_WORKING_DIRECTORY "${s_WORKING_DIRECTORY}")
  list(FIND ARGN "WORKING_DIRECTORY" wd_at)
  if(wd_at EQUAL -1)
    set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_WORKING_DIRECTORY_KEYWORD "absent")
  else()
    set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_WORKING_DIRECTORY_KEYWORD "present")
  endif()
endfunction()

# byte_machine_expected_fingerprint and byte_machine_wrong_fingerprint are
# defined in test/CMakeLists.txt (Task 3, M0 slice 5a), which this standalone
# script does not include, so they are stubbed for the same reason the two
# registrars above are: every direct registration below sets
# BYTE_MACHINE_CHEZ_EXECUTABLE, which is exactly what makes
# byte_machine_add_scheme_lane's manifest block call one of these two. The
# environment assertions below account for what the stub adds. Each stub also
# records which one ran, in BYTE_MACHINE_SPEC_FINGERPRINT_FUNCTION, so the
# WRONG_FINGERPRINT routing further down can be asserted directly.
function(byte_machine_expected_fingerprint name out_var)
  set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_FINGERPRINT_FUNCTION "expected")
  set(${out_var} "/fingerprints/${name}.fingerprint" PARENT_SCOPE)
endfunction()

function(byte_machine_wrong_fingerprint name out_var)
  set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_FINGERPRINT_FUNCTION "wrong")
  set(${out_var} "/fingerprints/${name}.wrong" PARENT_SCOPE)
endfunction()

# An EXPECT_EXIT lane must route to the exit-code registrar and forward the
# code. Both this registration and the plain one below must carry the source
# execution mode, the fingerprint sample path, and the fingerprint manifest
# ahead of whatever the caller supplied -- facts the launcher itself cannot
# assert about its own invocation.
set(BYTE_MACHINE_CHEZ_EXECUTABLE "/opt/chez")
set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_REGISTRAR "none")
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.example.chez.source
  BACKEND chez
  PROGRAM "${SPEC_SELF}"
  SHARED_BODIES "${SPEC_SELF}"
  TIMEOUT 10
  EXPECT_EXIT 1
  ENVIRONMENT "FOO=bar")
get_property(registrar GLOBAL PROPERTY BYTE_MACHINE_SPEC_REGISTRAR)
spec_check_equal("${registrar}" "exit-code" "EXPECT_EXIT routes to the exit-code registrar")
get_property(expect_exit GLOBAL PROPERTY BYTE_MACHINE_SPEC_EXPECT_EXIT)
spec_check_equal("${expect_exit}" "1" "EXPECT_EXIT is forwarded to the exit-code registrar")
get_property(environment GLOBAL PROPERTY BYTE_MACHINE_SPEC_ENVIRONMENT)
spec_check_equal("${environment}"
  "BYTE_MACHINE_EXECUTION_MODE=source;BYTE_MACHINE_FINGERPRINT_SAMPLE=${CMAKE_SOURCE_DIR}/test/fixtures/fingerprint-sample.bin;BYTE_MACHINE_FINGERPRINT_FILES=${SPEC_SELF};BYTE_MACHINE_EXPECT_FINGERPRINT_FILE=/fingerprints/byte-machine.harness.example.chez.source.fingerprint;FOO=bar"
  "exit-code registration carries every default ahead of caller-supplied entries, which are appended last so they can override a default")

set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_REGISTRAR "none")
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.example.chez.source
  BACKEND chez
  PROGRAM "${SPEC_SELF}"
  SHARED_BODIES "${SPEC_SELF}"
  TIMEOUT 10
  ENVIRONMENT "FOO=bar")
get_property(registrar GLOBAL PROPERTY BYTE_MACHINE_SPEC_REGISTRAR)
spec_check_equal("${registrar}" "plain" "a lane without EXPECT_EXIT routes to the plain registrar")
get_property(environment GLOBAL PROPERTY BYTE_MACHINE_SPEC_ENVIRONMENT)
spec_check_equal("${environment}"
  "BYTE_MACHINE_EXECUTION_MODE=source;BYTE_MACHINE_FINGERPRINT_SAMPLE=${CMAKE_SOURCE_DIR}/test/fixtures/fingerprint-sample.bin;BYTE_MACHINE_FINGERPRINT_FILES=${SPEC_SELF};BYTE_MACHINE_EXPECT_FINGERPRINT_FILE=/fingerprints/byte-machine.harness.example.chez.source.fingerprint;FOO=bar"
  "plain registration carries every default ahead of caller-supplied entries, which are appended last so they can override a default")

# --- The mode is the name's, not a literal ---------------------------------
#
# A lane that declares a mode it is not running is the defect this whole slice
# exists to prevent, and the declaration is what every other lane's evidence
# is labelled with. Asserted over a name that is not `source`, because the
# literal it replaced was `source`: a mutation restoring the literal passes
# every assertion written over a source lane.
set(BYTE_MACHINE_CHEZ_EXECUTABLE "/opt/chez")
set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_REGISTRAR "none")
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.example.chez.aot
  BACKEND chez
  PROGRAM "${SPEC_SELF}"
  SHARED_BODIES "${SPEC_SELF}"
  TIMEOUT 10)
get_property(environment GLOBAL PROPERTY BYTE_MACHINE_SPEC_ENVIRONMENT)
list(GET environment 0 mode_entry)
spec_check_equal("${mode_entry}" "BYTE_MACHINE_EXECUTION_MODE=aot"
  "an aot lane declares the aot mode, read from its own name")

# The full list, not just the mode entry above: BYTE_MACHINE_FINGERPRINT_FILES
# here is the measured copy's path under the per-lane object directory, while
# BYTE_MACHINE_EXPECT_FINGERPRINT_FILE is still keyed by the lane's own name --
# the expectation comes from the declared body, the run's environment from the
# measured one. This assertion is the declared/measured asymmetry itself, the
# whole mechanism this task adds, visible here with no Scheme runtime present.
spec_check_equal("${environment}"
  "BYTE_MACHINE_EXECUTION_MODE=aot;BYTE_MACHINE_FINGERPRINT_SAMPLE=${CMAKE_SOURCE_DIR}/test/fixtures/fingerprint-sample.bin;BYTE_MACHINE_FINGERPRINT_FILES=/objects/byte-machine_harness_example_chez_aot/fingerprint/ByteMachineSchemeLaneSpec.cmake;BYTE_MACHINE_EXPECT_FINGERPRINT_FILE=/fingerprints/byte-machine.harness.example.chez.aot.fingerprint"
  "an aot lane's environment carries the measured copy's path in BYTE_MACHINE_FINGERPRINT_FILES, not the declared body's own path")

byte_machine_add_scheme_lane(
  NAME byte-machine.harness.example.chez.source
  BACKEND chez
  PROGRAM "${SPEC_SELF}"
  SHARED_BODIES "${SPEC_SELF}"
  TIMEOUT 10)
get_property(environment GLOBAL PROPERTY BYTE_MACHINE_SPEC_ENVIRONMENT)
list(GET environment 0 mode_entry)
spec_check_equal("${mode_entry}" "BYTE_MACHINE_EXECUTION_MODE=source"
  "a source lane still declares source")

# WRONG_FINGERPRINT chooses which function computes expect_file for the
# manifest block: present, byte_machine_wrong_fingerprint; absent,
# byte_machine_expected_fingerprint. Two assertions, since a branch has two
# sides -- a spec that checked only one would still pass if the branch were
# replaced by a constant that always called the same function.
set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_FINGERPRINT_FUNCTION "none")
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.example.chez.source
  BACKEND chez
  PROGRAM "${SPEC_SELF}"
  SHARED_BODIES "${SPEC_SELF}"
  TIMEOUT 10
  WRONG_FINGERPRINT)
get_property(fingerprint_function GLOBAL PROPERTY BYTE_MACHINE_SPEC_FINGERPRINT_FUNCTION)
spec_check_equal("${fingerprint_function}" "wrong"
  "a registration WITH WRONG_FINGERPRINT routes to byte_machine_wrong_fingerprint")

set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_FINGERPRINT_FUNCTION "none")
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.example.chez.source
  BACKEND chez
  PROGRAM "${SPEC_SELF}"
  SHARED_BODIES "${SPEC_SELF}"
  TIMEOUT 10)
get_property(fingerprint_function GLOBAL PROPERTY BYTE_MACHINE_SPEC_FINGERPRINT_FUNCTION)
spec_check_equal("${fingerprint_function}" "expected"
  "a registration WITHOUT WRONG_FINGERPRINT routes to byte_machine_expected_fingerprint")

# WORKING_DIRECTORY must be forwarded to whichever registrar the lane routed
# to, with its value, when the lane was given one -- and the keyword must not
# reach the registrar at all when it was not. Both directions, through both
# registrars: ByteMachineSchemeLane.cmake builds one working_directory_args
# list and splices it into both registration calls, so either could stop
# forwarding it independently of the other.
set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_REGISTRAR "none")
set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_WORKING_DIRECTORY "sentinel")
set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_WORKING_DIRECTORY_KEYWORD "sentinel")
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.example.chez.source
  BACKEND chez
  PROGRAM "${SPEC_SELF}"
  SHARED_BODIES "${SPEC_SELF}"
  TIMEOUT 10
  WORKING_DIRECTORY "/h/run")
get_property(wd GLOBAL PROPERTY BYTE_MACHINE_SPEC_WORKING_DIRECTORY)
spec_check_equal("${wd}" "/h/run"
  "a WORKING_DIRECTORY given to the plain registration path is forwarded with its value")
get_property(wd_keyword GLOBAL PROPERTY BYTE_MACHINE_SPEC_WORKING_DIRECTORY_KEYWORD)
spec_check_equal("${wd_keyword}" "present"
  "the WORKING_DIRECTORY keyword reaches the plain registrar when the lane gave one")

set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_REGISTRAR "none")
set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_WORKING_DIRECTORY "sentinel")
set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_WORKING_DIRECTORY_KEYWORD "sentinel")
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.example.chez.source
  BACKEND chez
  PROGRAM "${SPEC_SELF}"
  SHARED_BODIES "${SPEC_SELF}"
  TIMEOUT 10)
get_property(wd_keyword GLOBAL PROPERTY BYTE_MACHINE_SPEC_WORKING_DIRECTORY_KEYWORD)
spec_check_equal("${wd_keyword}" "absent"
  "no WORKING_DIRECTORY keyword reaches the plain registrar when the lane did not give one")

set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_REGISTRAR "none")
set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_WORKING_DIRECTORY "sentinel")
set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_WORKING_DIRECTORY_KEYWORD "sentinel")
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.example.chez.source
  BACKEND chez
  PROGRAM "${SPEC_SELF}"
  SHARED_BODIES "${SPEC_SELF}"
  TIMEOUT 10
  EXPECT_EXIT 1
  WORKING_DIRECTORY "/h/run")
get_property(wd GLOBAL PROPERTY BYTE_MACHINE_SPEC_WORKING_DIRECTORY)
spec_check_equal("${wd}" "/h/run"
  "a WORKING_DIRECTORY given to the exit-code registration path is forwarded with its value")
get_property(wd_keyword GLOBAL PROPERTY BYTE_MACHINE_SPEC_WORKING_DIRECTORY_KEYWORD)
spec_check_equal("${wd_keyword}" "present"
  "the WORKING_DIRECTORY keyword reaches the exit-code registrar when the lane gave one")

set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_REGISTRAR "none")
set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_WORKING_DIRECTORY "sentinel")
set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_WORKING_DIRECTORY_KEYWORD "sentinel")
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.example.chez.source
  BACKEND chez
  PROGRAM "${SPEC_SELF}"
  SHARED_BODIES "${SPEC_SELF}"
  TIMEOUT 10
  EXPECT_EXIT 1)
get_property(wd_keyword GLOBAL PROPERTY BYTE_MACHINE_SPEC_WORKING_DIRECTORY_KEYWORD)
spec_check_equal("${wd_keyword}" "absent"
  "no WORKING_DIRECTORY keyword reaches the exit-code registrar when the lane did not give one")

# A no-runtime backend must skip registration silently: neither registrar may
# be reached. This runs in-process rather than through spec_expect_rejected, so
# simply reaching the assertion below is itself proof that nothing raised.
set(BYTE_MACHINE_CHEZ_EXECUTABLE "")
set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_REGISTRAR "none")
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.example.chez.source
  BACKEND chez
  PROGRAM "${SPEC_SELF}"
  SHARED_BODIES "${SPEC_SELF}"
  TIMEOUT 10)
get_property(registrar GLOBAL PROPERTY BYTE_MACHINE_SPEC_REGISTRAR)
spec_check_equal("${registrar}" "none" "a no-runtime backend registers nothing and does not raise")

spec_expect_all_rejected("${SPEC_SELF}"
  "lane-rejects-unparsed-arguments|unexpected arguments to byte_machine_add_scheme_lane"
  "lane-requires-name|NAME is required for byte_machine_add_scheme_lane"
  "lane-requires-backend|BACKEND is required for byte_machine_add_scheme_lane"
  "lane-requires-program|PROGRAM is required for byte_machine_add_scheme_lane"
  "lane-requires-timeout|TIMEOUT is required for byte_machine_add_scheme_lane"
  "lane-requires-shared-bodies|SHARED_BODIES is required for byte_machine_add_scheme_lane"
  "lane-requires-existing-program|names a program that does not exist"
  "lane-rejects-missing-shared-body|names a shared body that does not exist"
  "lane-rejects-unknown-backend|is not a Scheme lane backend"
  "lane-rejects-comma-in-gambit-root|must not contain a comma"
  "lane-rejects-relative-gambit-root|must be absolute")

spec_finish("ByteMachineSchemeLane")
