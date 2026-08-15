# Locate and validate the Chez Scheme runtime used by the test lanes.
#
# Binary naming is not portable. Upstream installs the full system as `scheme`;
# Homebrew installs it as `chez` and reserves `petite` for the interpreter-only
# build; some distributions use `chezscheme`. A `scheme` on PATH is not
# necessarily Chez at all, so every candidate is interrogated before use.
#
# WHY PETITE IS REJECTED
#
# Petite has no `compile-program`, so the ahead-of-time lane cannot run there.
# A Petite that passed discovery would produce a suite that silently covers one
# fewer execution mode than it claims.
#
# WHY THREADING IS NOT CHECKED
#
# The sibling protium project requires threaded Chez because libuv gives it a
# loop-owner thread model. byte-machine has no threads anywhere in its design,
# so gating on a threaded build here would be a copied requirement rather than a
# real one. The flag is recorded as portability evidence, not enforced.
#
# This module defines functions and does not run discovery on include, so its
# functional core is specifiable under `cmake -P` without a Chez present. Call
# byte_machine_chez_discover() to run the imperative half.

include_guard(GLOBAL)

# By explicit path, not module path: this module is included directly by its
# specification under `cmake -P`, where CMAKE_MODULE_PATH is not set.
include("${CMAKE_CURRENT_LIST_DIR}/ByteMachineProbe.cmake")

# The floor is what this project has actually verified, not what it guesses it
# could tolerate. Milestone 0 question 1 (parent plan section 30) is answered by
# CI, and lowering this pin is that answer's job; raising it needs a reason
# recorded in docs/decisions.
set(BYTE_MACHINE_CHEZ_MINIMUM_VERSION "10.4.1")
set(BYTE_MACHINE_CHEZ_PROBE "${CMAKE_CURRENT_LIST_DIR}/chez-probe.ss")
set(BYTE_MACHINE_CHEZ_PROBE_TIMEOUT 20)

# --- Functional core -------------------------------------------------------

# byte_machine_chez_identity(<probe_output> <path>
#                            <out_full_version> <out_version>
#                            <out_machine_type> <out_threaded>)
#
# Decide whether probe output came from a usable Chez, and extract the banner,
# the bare version, the machine type, and the threading flag. Fails fatally with
# a specific diagnostic for each way it can go wrong.
function(byte_machine_chez_identity output path
         out_full_version out_version out_machine_type out_threaded)
  byte_machine_probe_normalize("${output}" normalized)

  set(context "the chez probe of '${path}'")
  byte_machine_probe_field("${normalized}" "full-version" full_version "${context}")

  if(NOT full_version MATCHES "Chez Scheme")
    message(FATAL_ERROR
      "byte-machine: '${path}' is not Chez Scheme; it reports "
      "'${full_version}'. The name 'scheme' on PATH belongs to several "
      "unrelated implementations. Set BYTE_MACHINE_CHEZ_EXECUTABLE to an "
      "absolute path.")
  endif()

  # Checked after the Chez test, because Petite's banner also contains
  # 'Chez Scheme' and the more specific diagnostic is the more useful one.
  if(full_version MATCHES "Petite")
    message(FATAL_ERROR
      "byte-machine: Petite Chez is not a supported configuration "
      "('${full_version}'). The ahead-of-time lane needs compile-program, which "
      "Petite does not provide. Set BYTE_MACHINE_CHEZ_EXECUTABLE to the full "
      "system.")
  endif()

  # Read over the banner rather than a probe field, so it is checked in place.
  if(NOT full_version MATCHES "([0-9]+\\.[0-9]+\\.[0-9]+)")
    message(FATAL_ERROR
      "byte-machine: could not read a version number out of Chez's banner "
      "'${full_version}'. Portability evidence compares exact versions, so an "
      "unreadable one is a configuration failure rather than a blank field.")
  endif()
  set(version "${CMAKE_MATCH_1}")

  # A floor, not an equality: the parent plan's Tier 2 matrix explicitly
  # includes additional implementation versions, so exact-matching would
  # contradict it.
  if(version VERSION_LESS BYTE_MACHINE_CHEZ_MINIMUM_VERSION)
    message(FATAL_ERROR
      "byte-machine: Chez ${version} is older than the verified floor "
      "${BYTE_MACHINE_CHEZ_MINIMUM_VERSION}. The floor records what this "
      "project has actually run, not what it guesses it could tolerate; lower "
      "it only with CI evidence from the older release.")
  endif()

  byte_machine_probe_field("${normalized}" "machine-type" machine_type "${context}")
  byte_machine_probe_field("${normalized}" "threaded" threaded "${context}")

  set(${out_full_version} "${full_version}" PARENT_SCOPE)
  set(${out_version} "${version}" PARENT_SCOPE)
  set(${out_machine_type} "${machine_type}" PARENT_SCOPE)
  set(${out_threaded} "${threaded}" PARENT_SCOPE)
endfunction()

# --- Imperative shell ------------------------------------------------------

# byte_machine_chez_probe(<binary> <out_output>)
function(byte_machine_chez_probe binary out_output)
  execute_process(
    COMMAND "${binary}" --script "${BYTE_MACHINE_CHEZ_PROBE}"
    TIMEOUT "${BYTE_MACHINE_CHEZ_PROBE_TIMEOUT}"
    RESULT_VARIABLE result
    OUTPUT_VARIABLE output
    ERROR_VARIABLE error
    OUTPUT_STRIP_TRAILING_WHITESPACE)

  if(NOT result MATCHES "^[0-9]+$")
    message(FATAL_ERROR
      "byte-machine: '${binary}' did not answer the Chez probe within "
      "${BYTE_MACHINE_CHEZ_PROBE_TIMEOUT}s (${result}). A binary that waits for "
      "input instead of reading the file looks exactly like this. Set "
      "BYTE_MACHINE_CHEZ_EXECUTABLE to an absolute path.")
  endif()

  # Deliberately not gated on exit status; the content check in
  # byte_machine_chez_identity is the real gate.
  set(${out_output} "${output}\n${error}" PARENT_SCOPE)
endfunction()

macro(byte_machine_chez_discover)
  if(NOT BYTE_MACHINE_CHEZ_EXECUTABLE)
    find_program(BYTE_MACHINE_CHEZ_EXECUTABLE
      NAMES scheme chez chezscheme
      DOC "Full Chez Scheme executable. Must not be Petite.")
  endif()

  if(NOT BYTE_MACHINE_CHEZ_EXECUTABLE)
    message(FATAL_ERROR
      "byte-machine: no Chez Scheme executable found. Looked for 'scheme', "
      "'chez', and 'chezscheme' on PATH. Install Chez "
      "${BYTE_MACHINE_CHEZ_MINIMUM_VERSION} or newer, or set "
      "-DBYTE_MACHINE_CHEZ_EXECUTABLE=/absolute/path/to/scheme.")
  endif()

  # find_program only runs when the cache entry is empty, so a value supplied on
  # the command line reaches here unchecked.
  if(NOT EXISTS "${BYTE_MACHINE_CHEZ_EXECUTABLE}")
    message(FATAL_ERROR
      "byte-machine: the Chez executable '${BYTE_MACHINE_CHEZ_EXECUTABLE}' does "
      "not exist. BYTE_MACHINE_CHEZ_EXECUTABLE must be an absolute path.")
  endif()

  byte_machine_chez_probe("${BYTE_MACHINE_CHEZ_EXECUTABLE}" _byte_machine_chez_output)
  byte_machine_chez_identity(
    "${_byte_machine_chez_output}" "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
    BYTE_MACHINE_CHEZ_FULL_VERSION BYTE_MACHINE_CHEZ_VERSION
    BYTE_MACHINE_CHEZ_MACHINE_TYPE BYTE_MACHINE_CHEZ_THREADED)

  message(STATUS
    "byte-machine Chez: ${BYTE_MACHINE_CHEZ_EXECUTABLE} "
    "(${BYTE_MACHINE_CHEZ_FULL_VERSION}, machine "
    "${BYTE_MACHINE_CHEZ_MACHINE_TYPE}, threaded ${BYTE_MACHINE_CHEZ_THREADED})")
endmacro()
