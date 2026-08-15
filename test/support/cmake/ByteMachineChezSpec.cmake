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

# --- Negative cases --------------------------------------------------------

set(negative_cases
  "not-chez|byte-machine: '/usr/bin/scheme' is not Chez Scheme"
  "petite|byte-machine: Petite Chez is not a supported configuration"
  "too-old|byte-machine: Chez 9.5.8 is older than the verified floor"
  "unreadable-version|byte-machine: could not read a version number"
  "ghostscript|byte-machine: the chez probe of '/opt/homebrew/bin/gsc' produced no 'full-version' field")

spec_expect_all_rejected("${SPEC_SELF}" ${negative_cases})

message(STATUS "byte-machine-spec: ByteMachineChez verified")
