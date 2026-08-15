# Locate and validate the Gambit runtime used by the test lanes.
#
# THE NAMING TRAP
#
# Ghostscript installs a console binary called `gsc`. On this project's
# development host a bare `gsc` on PATH *is* Ghostscript, and Gambit's own
# Homebrew keg is deliberately left unlinked because of the collision. So
# byte-machine never searches for `gsc`. It searches for `gsi`, which Ghostscript
# does not ship, and derives the compiler from the directory the interpreter was
# found in. The derivation is positional and carries no judgement, so the derived
# path is interrogated exactly as the interpreter is.
#
# Exit status cannot be part of that interrogation. Ghostscript's `gsc`, handed a
# Scheme file, prints its banner and exits 0 when its standard input is closed,
# and waits for input when it is not. Only the content of the probe output
# separates the two, and only a timeout stops the second from wedging
# configuration.
#
# NOTE ON THE NATIVE TOOLCHAIN
#
# `gsc` shells out to a C compiler whose name is fixed when Gambit is built. The
# Homebrew build on this host hard-codes `gcc-16` in gambuild-C, so native lanes
# fail if that compiler is not on PATH -- a failure that has nothing to do with
# anything CMake configured. Discovery does not try to check this; the native
# lanes report it when they run.
#
# This module defines functions and does not run discovery on include, so its
# functional core is specifiable under `cmake -P` without a Gambit present. Call
# byte_machine_gambit_discover() to run the imperative half.

include_guard(GLOBAL)

# By explicit path, not module path: this module is included directly by its
# specification under `cmake -P`, where CMAKE_MODULE_PATH is not set.
include("${CMAKE_CURRENT_LIST_DIR}/ByteMachineProbe.cmake")

# The floor is what this project has actually verified. See the matching comment
# in ByteMachineChez.cmake.
set(BYTE_MACHINE_GAMBIT_MINIMUM_VERSION "4.9.8")
set(BYTE_MACHINE_GAMBIT_PROBE "${CMAKE_CURRENT_LIST_DIR}/gambit-probe.scm")

# How long a probe may take before it is treated as the wrong program. Gambit
# answers in milliseconds; anything that has not answered in this long is either
# not Gambit or is waiting for input that will never come.
set(BYTE_MACHINE_GAMBIT_PROBE_TIMEOUT 20)

# --- Functional core -------------------------------------------------------

# byte_machine_gambit_identity(<probe_output> <path>
#                              <out_version> <out_target> <out_stamp>)
#
# Decide whether probe output came from a usable Gambit, and extract the bare
# version, target triple, and build stamp.
#
# The stamp is what distinguishes two builds of one version: 4.9.8 configured
# --enable-single-host and stock 4.9.8 report the same version and the same
# target and are not the same runtime.
function(byte_machine_gambit_identity output path out_version out_target out_stamp)
  byte_machine_probe_normalize("${output}" normalized)

  if(NOT normalized MATCHES "(^|\n)gambit=yes(\n|$)")
    message(FATAL_ERROR
      "byte-machine: '${path}' is not Gambit. It did not answer the Gambit "
      "probe. On a host with Ghostscript installed, a binary named 'gsc' is "
      "very likely Ghostscript's PostScript interpreter rather than the Gambit "
      "compiler. Set BYTE_MACHINE_GAMBIT_EXECUTABLE to an absolute path to "
      "'gsi'.\n--- probe output ---\n${output}\n--- end ---")
  endif()

  set(context "the gambit probe of '${path}'")
  byte_machine_probe_field("${normalized}" "version" raw_version "${context}")

  # Gambit reports 'v4.9.8' where Chez reports '10.4.1'. Portability evidence
  # compares bare numbers, so the marker is stripped here rather than in every
  # consumer.
  if(raw_version MATCHES "^v(.*)$")
    set(version "${CMAKE_MATCH_1}")
  else()
    set(version "${raw_version}")
  endif()

  # See the matching guard in ByteMachineChez.cmake: an absent floor compares
  # FALSE and would accept every release.
  if(NOT BYTE_MACHINE_GAMBIT_MINIMUM_VERSION MATCHES "^[0-9]+\\.[0-9]+")
    message(FATAL_ERROR
      "byte-machine: BYTE_MACHINE_GAMBIT_MINIMUM_VERSION is "
      "'${BYTE_MACHINE_GAMBIT_MINIMUM_VERSION}', which is not a version. The "
      "floor cannot be enforced, and comparing against an empty value would "
      "accept every release.")
  endif()

  if(version VERSION_LESS BYTE_MACHINE_GAMBIT_MINIMUM_VERSION)
    message(FATAL_ERROR
      "byte-machine: Gambit ${version} is older than the verified floor "
      "${BYTE_MACHINE_GAMBIT_MINIMUM_VERSION}. The floor records what this "
      "project has actually run, not what it guesses it could tolerate; lower "
      "it only with CI evidence from the older release.")
  endif()

  byte_machine_probe_field("${normalized}" "target" target "${context}")
  byte_machine_probe_field("${normalized}" "stamp" stamp "${context}")

  set(${out_version} "${version}" PARENT_SCOPE)
  set(${out_target} "${target}" PARENT_SCOPE)
  set(${out_stamp} "${stamp}" PARENT_SCOPE)
endfunction()

# byte_machine_gambit_compiler_beside(<gsi_path> <out_var>)
#
# Derive the compiler path from the interpreter's own directory, preserving any
# suffix on the name so `gsi.exe` yields `gsc.exe` and `gsi-4.9.8` yields
# `gsc-4.9.8`. This is a positional derivation, not a judgement that the result
# is Gambit; the caller interrogates it.
function(byte_machine_gambit_compiler_beside gsi_path out_var)
  get_filename_component(dir "${gsi_path}" DIRECTORY)
  get_filename_component(name "${gsi_path}" NAME)

  # A relative path has no directory component, so the derivation would yield
  # '/gsc' -- an absolute path at the filesystem root -- and then complain about
  # a path the caller never supplied. CMake's EXISTS does not reject a relative
  # path either, so this is where it has to be caught.
  if(dir STREQUAL "")
    message(FATAL_ERROR
      "byte-machine: cannot derive the Gambit compiler from '${gsi_path}': it "
      "has no directory component. BYTE_MACHINE_GAMBIT_EXECUTABLE must be an "
      "absolute path to 'gsi'.")
  endif()

  if(NOT name MATCHES "^gsi(.*)$")
    message(FATAL_ERROR
      "byte-machine: cannot derive the Gambit compiler from '${gsi_path}': its "
      "filename does not begin with 'gsi'. Set BYTE_MACHINE_GAMBIT_COMPILER to "
      "an absolute path to the matching 'gsc'.")
  endif()

  set(${out_var} "${dir}/gsc${CMAKE_MATCH_1}" PARENT_SCOPE)
endfunction()

# byte_machine_gambit_compiler_for(<interpreter> <cached> <derived_from>
#                                  <out_path> <out_derived_from>)
#
# Choose the compiler to use, given whatever a previous configure left behind.
#
# Remembering a derived path without remembering what it was derived from is how
# an interpreter and a compiler come to belong to different installations: the
# interpreter is repointed on a later configure, the cached compiler is not, and
# byte_machine_gambit_require_agreement is then handed two probes of one runtime
# and one probe of another. That is the exact condition the agreement check
# exists to catch, so it must not be the thing that hides it.
#
# A value with no recorded derivation was set by hand and is left alone. An
# override that quietly stopped applying would be a worse failure than a stale
# one, because the user has stated an intent.
function(byte_machine_gambit_compiler_for interpreter cached derived_from
         out_path out_derived_from)
  if(NOT cached)
    byte_machine_gambit_compiler_beside("${interpreter}" fresh)
    set(${out_path} "${fresh}" PARENT_SCOPE)
    set(${out_derived_from} "${interpreter}" PARENT_SCOPE)
    return()
  endif()

  if(derived_from STREQUAL "")
    set(${out_path} "${cached}" PARENT_SCOPE)
    set(${out_derived_from} "" PARENT_SCOPE)
    return()
  endif()

  # The cache says this value was derived from some interpreter. Whether that is
  # still true decides everything, and comparing the recorded interpreter to the
  # current one is not the same question.
  #
  # Matching on interpreter identity alone -- the previous implementation -- got
  # this wrong whenever both changed in one configure: a user passing
  # -DBYTE_MACHINE_GAMBIT_COMPILER while also repointing the interpreter had
  # their value silently overwritten by a derivation, which is exactly the
  # "override that quietly stopped applying" this function's comment calls the
  # worse failure. Recomputing the recorded derivation and comparing it to what
  # is actually cached separates "still derived" from "since overridden",
  # regardless of which interpreter is current.
  byte_machine_gambit_compiler_beside("${derived_from}" recorded_derivation)
  if(NOT cached STREQUAL recorded_derivation)
    set(${out_path} "${cached}" PARENT_SCOPE)
    set(${out_derived_from} "" PARENT_SCOPE)
    return()
  endif()

  # Genuinely derived, so it follows the interpreter. When the interpreter has
  # not changed this reproduces the cached value, which is why there is no
  # separate reuse branch.
  byte_machine_gambit_compiler_beside("${interpreter}" fresh)
  set(${out_path} "${fresh}" PARENT_SCOPE)
  set(${out_derived_from} "${interpreter}" PARENT_SCOPE)
endfunction()

# byte_machine_gambit_require_agreement(<iv> <it> <is> <cv> <ct> <cs>)
#
# The interpreter and the compiler must come from one installation. They are
# found by two different routes -- one searched for, one derived -- so a mismatch
# means the derivation landed in a directory belonging to something else, and
# the `.o1` and AOT lanes would then be qualifying different runtimes.
function(byte_machine_gambit_require_agreement
         interp_version interp_target interp_stamp
         compiler_version compiler_target compiler_stamp)
  if(NOT interp_version STREQUAL compiler_version
     OR NOT interp_target STREQUAL compiler_target
     OR NOT interp_stamp STREQUAL compiler_stamp)
    message(FATAL_ERROR
      "byte-machine: the Gambit interpreter and compiler disagree about what "
      "they are. gsi reports ${interp_version} ${interp_target} "
      "${interp_stamp}; gsc reports ${compiler_version} ${compiler_target} "
      "${compiler_stamp}. They must come from one installation, or the .o1 and "
      "AOT lanes qualify different runtimes. The build stamp is part of this "
      "comparison because two builds of one version, for one target, are still "
      "two runtimes.")
  endif()
endfunction()

# --- Imperative shell ------------------------------------------------------

# byte_machine_gambit_probe(<binary> <extra-args> <out_output>)
function(byte_machine_gambit_probe binary extra_args out_output)
  execute_process(
    COMMAND "${binary}" -f ${extra_args} "${BYTE_MACHINE_GAMBIT_PROBE}"
    TIMEOUT "${BYTE_MACHINE_GAMBIT_PROBE_TIMEOUT}"
    RESULT_VARIABLE result
    OUTPUT_VARIABLE output
    ERROR_VARIABLE error
    OUTPUT_STRIP_TRAILING_WHITESPACE)

  if(NOT result MATCHES "^[0-9]+$")
    message(FATAL_ERROR
      "byte-machine: '${binary}' did not answer the Gambit probe (${result}). "
      "It either aborted, or waited for input instead of reading the file and "
      "hit the ${BYTE_MACHINE_GAMBIT_PROBE_TIMEOUT}s timeout -- execute_process "
      "reports both the same way. Ghostscript's 'gsc' does the latter. Set "
      "BYTE_MACHINE_GAMBIT_EXECUTABLE to an absolute path to Gambit's 'gsi'.")
  endif()

  # Deliberately not gated on the exit status: Ghostscript exits 0 here. The
  # content check in byte_machine_gambit_identity is the real gate, and a
  # nonzero status is only extra context for its message.
  set(${out_output} "${output}\n${error}" PARENT_SCOPE)
endfunction()

macro(byte_machine_gambit_discover)
  # Hints are searched before PATH, so each one is a claim that a path is more
  # authoritative than the user's own environment. An unset GAMBIT_HOME would
  # otherwise contribute the literal hint "/bin", quietly outranking PATH for
  # anything named gsi that happens to live there.
  set(_byte_machine_gambit_hints
    /opt/homebrew/opt/gambit-scheme/bin
    /usr/local/opt/gambit-scheme/bin
    /opt/gambit/bin
    /usr/local/Gambit/bin)
  if(DEFINED ENV{GAMBIT_HOME} AND NOT "$ENV{GAMBIT_HOME}" STREQUAL "")
    list(INSERT _byte_machine_gambit_hints 0 "$ENV{GAMBIT_HOME}/bin")
  endif()

  if(BYTE_MACHINE_GAMBIT_EXECUTABLE)
    set(_byte_machine_gsi "${BYTE_MACHINE_GAMBIT_EXECUTABLE}")
    set(_byte_machine_gsi_searched FALSE)
  else()
    # NO_CACHE, and the cache entry is written only after the candidate passes.
    # find_program caches on sight, and CMake writes CMakeCache.txt even for a
    # configure that failed -- so caching first means a rejected path outlives
    # the failure, the search is skipped on the next run, and a user who has
    # since fixed their environment still sees a stale error about a binary they
    # no longer have. ByteMachineChez.cmake had the same defect and this mirrors
    # its fix.
    unset(_byte_machine_gsi)
    find_program(_byte_machine_gsi NAMES gsi HINTS ${_byte_machine_gambit_hints} NO_CACHE)
    set(_byte_machine_gsi_searched TRUE)
  endif()

  if(NOT _byte_machine_gsi)
    message(FATAL_ERROR
      "byte-machine: no Gambit interpreter found. Looked for 'gsi' on PATH and "
      "in the usual package prefixes. Install Gambit "
      "${BYTE_MACHINE_GAMBIT_MINIMUM_VERSION} or newer, or set "
      "-DBYTE_MACHINE_GAMBIT_EXECUTABLE=/absolute/path/to/gsi.\n"
      "byte-machine deliberately does not search for 'gsc': on a host with "
      "Ghostscript installed that name resolves to a PostScript interpreter.")
  endif()

  if(NOT EXISTS "${_byte_machine_gsi}")
    message(FATAL_ERROR
      "byte-machine: the Gambit interpreter '${_byte_machine_gsi}' "
      "does not exist. BYTE_MACHINE_GAMBIT_EXECUTABLE must be an absolute path "
      "to 'gsi'.")
  endif()

  # The interpreter is interrogated before anything is derived from it, and
  # before it is cached. Deriving first meant a Ghostscript 'gsi' produced "the
  # Gambit compiler ... does not exist", sending the reader after a path that was
  # never the problem; decision record 0001 says identity is decided on probe
  # content, so that has to happen before the derivation it justifies.
  byte_machine_gambit_probe("${_byte_machine_gsi}" "" _byte_machine_gsi_output)
  byte_machine_gambit_identity(
    "${_byte_machine_gsi_output}" "${_byte_machine_gsi}"
    BYTE_MACHINE_GAMBIT_VERSION BYTE_MACHINE_GAMBIT_TARGET BYTE_MACHINE_GAMBIT_STAMP)

  if(_byte_machine_gsi_searched)
    set(BYTE_MACHINE_GAMBIT_EXECUTABLE "${_byte_machine_gsi}" CACHE FILEPATH
      "Gambit Scheme interpreter (gsi). Must be ${BYTE_MACHINE_GAMBIT_MINIMUM_VERSION} or newer.")
  endif()

  byte_machine_gambit_compiler_for(
    "${BYTE_MACHINE_GAMBIT_EXECUTABLE}"
    "${BYTE_MACHINE_GAMBIT_COMPILER}"
    "${BYTE_MACHINE_GAMBIT_COMPILER_DERIVED_FROM}"
    _byte_machine_gsc _byte_machine_gsc_source)
  set(BYTE_MACHINE_GAMBIT_COMPILER "${_byte_machine_gsc}" CACHE FILEPATH
    "Gambit Scheme compiler (gsc). Derived from the interpreter's directory unless set explicitly." FORCE)
  set(BYTE_MACHINE_GAMBIT_COMPILER_DERIVED_FROM "${_byte_machine_gsc_source}" CACHE INTERNAL
    "The interpreter BYTE_MACHINE_GAMBIT_COMPILER was derived from; empty when it was set by hand.")

  if(NOT EXISTS "${BYTE_MACHINE_GAMBIT_COMPILER}")
    if(_byte_machine_gsc_source)
      set(_byte_machine_gsc_origin
        "It was derived from the interpreter at '${_byte_machine_gsc_source}'. Set BYTE_MACHINE_GAMBIT_COMPILER explicitly if the two live in different directories.")
    else()
      set(_byte_machine_gsc_origin
        "It was set explicitly rather than derived, so this is the path that was supplied.")
    endif()
    message(FATAL_ERROR
      "byte-machine: the Gambit compiler '${BYTE_MACHINE_GAMBIT_COMPILER}' does "
      "not exist. ${_byte_machine_gsc_origin}")
  endif()

  # `-i` makes the compiler process the rest of its command line the way the
  # interpreter does, which is the only way to ask it what it is.
  byte_machine_gambit_probe("${BYTE_MACHINE_GAMBIT_COMPILER}" "-i" _byte_machine_gsc_output)
  byte_machine_gambit_identity(
    "${_byte_machine_gsc_output}" "${BYTE_MACHINE_GAMBIT_COMPILER}"
    _byte_machine_gsc_version _byte_machine_gsc_target _byte_machine_gsc_stamp)

  byte_machine_gambit_require_agreement(
    "${BYTE_MACHINE_GAMBIT_VERSION}" "${BYTE_MACHINE_GAMBIT_TARGET}" "${BYTE_MACHINE_GAMBIT_STAMP}"
    "${_byte_machine_gsc_version}" "${_byte_machine_gsc_target}" "${_byte_machine_gsc_stamp}")

  message(STATUS
    "byte-machine Gambit: ${BYTE_MACHINE_GAMBIT_EXECUTABLE} and "
    "${BYTE_MACHINE_GAMBIT_COMPILER} (${BYTE_MACHINE_GAMBIT_VERSION}, target "
    "${BYTE_MACHINE_GAMBIT_TARGET}, build ${BYTE_MACHINE_GAMBIT_STAMP})")
endmacro()
