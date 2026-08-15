# Specification for the functional core of cmake/ByteMachineChez.cmake.
#
# Discovery has to decide, from a probe's output alone, whether a binary is the
# Chez byte-machine needs. Three things can go wrong and only one of them is
# obvious:
#
#   - the binary is not Chez at all (a `scheme` on PATH may be anything);
#   - it is Petite, which has no compile-program and so cannot run the AOT lane;
#   - it is too old for the include and bytevector surface the project uses.
#
# WHY THREADING IS NOT CHECKED
#
# The sibling protium project requires threaded Chez because libuv gives it a
# loop-owner thread model. byte-machine has no threads anywhere in its design,
# so requiring a threaded build here would be a copied requirement rather than a
# real one, and would reject a perfectly good runtime. The probe still reports
# the flag and discovery still records it, because portability evidence names
# the exact runtime that produced it -- but it is evidence, not a gate.

cmake_minimum_required(VERSION 3.26)

include("${CMAKE_CURRENT_LIST_DIR}/../../../cmake/ByteMachineChez.cmake")

include("${CMAKE_CURRENT_LIST_DIR}/SpecSupport.cmake")

set(SPEC_SELF "${CMAKE_CURRENT_LIST_FILE}")

set(good_output "full-version=Chez Scheme Version 10.4.1
machine-type=tarm64osx
threaded=yes")

if(DEFINED BYTE_MACHINE_SPEC_CASE)
  set(c "${BYTE_MACHINE_SPEC_CASE}")

  if(c STREQUAL "not-chez")
    byte_machine_chez_identity(
      "full-version=guile (GNU Guile) 3.0.10\nmachine-type=unknown\nthreaded=yes"
      "/usr/bin/scheme" fv v mt th)
  elseif(c STREQUAL "petite")
    byte_machine_chez_identity(
      "full-version=Petite Chez Scheme Version 10.4.1\nmachine-type=tarm64osx\nthreaded=yes"
      "/opt/homebrew/bin/petite" fv v mt th)
  elseif(c STREQUAL "too-old")
    byte_machine_chez_identity(
      "full-version=Chez Scheme Version 9.5.8\nmachine-type=ta6osx\nthreaded=yes"
      "/usr/bin/scheme" fv v mt th)
  elseif(c STREQUAL "unreadable-version")
    byte_machine_chez_identity(
      "full-version=Chez Scheme Version experimental\nmachine-type=ta6osx\nthreaded=yes"
      "/usr/bin/scheme" fv v mt th)
  elseif(c STREQUAL "ghostscript")
    byte_machine_chez_identity(
      "GPL Ghostscript 10.07.1 (2026-05-19)" "/opt/homebrew/bin/gsc" fv v mt th)
  else()
    message(FATAL_ERROR "byte-machine-spec: unknown case '${c}'")
  endif()

  message(FATAL_ERROR "byte-machine-spec: case '${c}' was accepted but must be rejected")
endif()

# --- Driver ----------------------------------------------------------------

# Positive: the local development runtime is accepted and every field returned.
byte_machine_chez_identity("${good_output}" "/opt/homebrew/bin/chez" fv v mt th)
spec_check_equal("${fv}" "Chez Scheme Version 10.4.1" "full version")
spec_check_equal("${v}" "10.4.1" "bare version")
spec_check_equal("${mt}" "tarm64osx" "machine type")
spec_check_equal("${th}" "yes" "threaded flag is reported")

# A newer release is accepted: the pin is a floor, not an equality. The parent
# plan's Tier 2 matrix explicitly includes additional implementation versions,
# so exact-matching here would contradict it.
byte_machine_chez_identity(
  "full-version=Chez Scheme Version 11.0.0\nmachine-type=tarm64osx\nthreaded=yes"
  "/usr/bin/scheme" fv v mt th)
spec_check_equal("${v}" "11.0.0" "a newer release is accepted")

# A nonthreaded build is accepted, and reports itself as such. See the header:
# byte-machine has no threads, so this must not be a gate.
byte_machine_chez_identity(
  "full-version=Chez Scheme Version 10.4.1\nmachine-type=a6osx\nthreaded=no"
  "/usr/bin/scheme" fv v mt th)
spec_check_equal("${th}" "no" "a nonthreaded build is accepted and reported")
spec_check_equal("${v}" "10.4.1" "a nonthreaded build still yields its version")

# --- The classifier is non-fatal -------------------------------------------
#
# Discovery tries candidate names in turn, so a rejection has to be a returned
# verdict rather than a raised error. If any of these fataled, the spec would
# abort here rather than fail an assertion -- so their running to completion at
# all is part of what is being checked.
#
# These also pin the status symbols, which is what the search branches on.
# Asserting only the message would let a status typo route a rejected candidate
# into the accepted path.

byte_machine_chez_classify("${good_output}" "/opt/homebrew/bin/chez"
  st msg fv v mt th)
spec_check_equal("${st}" "ok" "a usable runtime classifies ok")
spec_check_equal("${msg}" "" "an accepted runtime carries no rejection message")
spec_check_equal("${v}" "10.4.1" "an accepted runtime still yields its version")

byte_machine_chez_classify(
  "full-version=guile (GNU Guile) 3.0.10\nmachine-type=unknown\nthreaded=yes"
  "/usr/bin/scheme" st msg fv v mt th)
spec_check_equal("${st}" "not-chez" "an unrelated implementation classifies not-chez")

byte_machine_chez_classify(
  "full-version=Petite Chez Scheme Version 10.4.1\nmachine-type=tarm64osx\nthreaded=yes"
  "/opt/homebrew/bin/petite" st msg fv v mt th)
spec_check_equal("${st}" "petite" "Petite classifies petite")

byte_machine_chez_classify(
  "full-version=Chez Scheme Version 9.5.8\nmachine-type=ta6osx\nthreaded=yes"
  "/usr/bin/scheme" st msg fv v mt th)
spec_check_equal("${st}" "too-old" "an old release classifies too-old")

byte_machine_chez_classify("GPL Ghostscript 10.07.1" "/opt/homebrew/bin/gsc"
  st msg fv v mt th)
spec_check_equal("${st}" "missing-field" "output with no fields classifies missing-field")

# A runtime that answers the banner but not the rest is not usable, and must not
# be reported as ok with empty fields.
byte_machine_chez_classify(
  "full-version=Chez Scheme Version 10.4.1\nmachine-type=tarm64osx"
  "/usr/bin/scheme" st msg fv v mt th)
spec_check_equal("${st}" "missing-field" "a truncated probe answer classifies missing-field")

# Outputs are cleared on rejection, so a caller looping over candidates cannot
# read the previous candidate's version as if it belonged to this one.
byte_machine_chez_classify("${good_output}" "/opt/homebrew/bin/chez" st msg fv v mt th)
byte_machine_chez_classify("nothing useful" "/usr/bin/scheme" st msg fv v mt th)
spec_check_equal("${v}" "" "a rejected candidate does not retain the previous version")
spec_check_equal("${fv}" "" "a rejected candidate does not retain the previous banner")

# --- Negative cases --------------------------------------------------------

set(negative_cases
  "not-chez|byte-machine: '/usr/bin/scheme' is not Chez Scheme"
  "petite|byte-machine: Petite Chez is not a supported configuration"
  "too-old|byte-machine: Chez 9.5.8 is older than the verified floor"
  "unreadable-version|byte-machine: could not read a version number"
  "ghostscript|byte-machine: the chez probe of '/opt/homebrew/bin/gsc' produced no 'full-version' field")

spec_expect_all_rejected("${SPEC_SELF}" ${negative_cases})

message(STATUS "byte-machine-spec: ByteMachineChez verified")
