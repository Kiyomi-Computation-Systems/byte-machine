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

set(BYTE_MACHINE_HARNESS_CHEZ_LAUNCHER "/h/launchers/chez-source.ss")
set(BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT "/h/chez")
set(BYTE_MACHINE_HARNESS_GAMBIT_LIBRARY_ROOT "/h/gambit")
set(BYTE_MACHINE_HARNESS_SHARED_DIR "/h/shared")
set(BYTE_MACHINE_HARNESS_OBJECT_GUARD_DIR "/b/guard")

# --- Chez ------------------------------------------------------------------

set(BYTE_MACHINE_CHEZ_EXECUTABLE "/opt/chez")
byte_machine_scheme_lane_command(chez "/h/self/p.chez.sps" command status message)
spec_check_equal("${status}" "ok" "chez lane classifies")
spec_check_equal("${command}"
  "/opt/chez;--script;/h/launchers/chez-source.ss;/h/chez;/h/shared;/b/guard;/h/self/p.chez.sps"
  "chez lane command line")

# The guard directory is the entire mechanism that stops a stale .so from being
# loaded in a lane that calls itself source. Asserted by position, because
# dropping it would leave a command that still runs.
list(GET command 5 guard)
spec_check_equal("${guard}" "/b/guard" "chez lane passes the object guard directory")

# --- Gambit ----------------------------------------------------------------

set(BYTE_MACHINE_GAMBIT_EXECUTABLE "/opt/gsi")
byte_machine_scheme_lane_command(gambit "/h/self/p.gambit.scm" command status message)
spec_check_equal("${status}" "ok" "gambit lane classifies")
spec_check_equal("${command}"
  "/opt/gsi;-:search=/h/gambit;-f;/h/self/p.gambit.scm"
  "gambit lane command line")

# Gambit requires its -: runtime options to be the very first argument, and -f
# must be present or a developer's .gambini can change what a test proves.
list(GET command 1 first_option)
spec_check_equal("${first_option}" "-:search=/h/gambit" "gambit runtime option comes first")
list(FIND command "-f" f_index)
spec_check_equal("${f_index}" "2" "gambit lane skips initialisation files")

# --- Rejections ------------------------------------------------------------

byte_machine_scheme_lane_command(guile "/h/self/p.scm" command status message)
spec_check_equal("${status}" "unknown-backend" "an unknown backend is rejected")

set(BYTE_MACHINE_CHEZ_EXECUTABLE "")
byte_machine_scheme_lane_command(chez "/h/self/p.chez.sps" command status message)
spec_check_equal("${status}" "no-runtime" "a chez lane without a chez is not registered")
spec_check_equal("${command}" "" "a rejected lane returns no command")

set(BYTE_MACHINE_GAMBIT_EXECUTABLE "")
byte_machine_scheme_lane_command(gambit "/h/self/p.gambit.scm" command status message)
spec_check_equal("${status}" "no-runtime" "a gambit lane without a gambit is not registered")

spec_finish("ByteMachineSchemeLane")
