# Specification for the functional core of cmake/ByteMachineGambit.cmake.
#
# THE NAMING TRAP
#
# Ghostscript installs a console binary called `gsc`. On this project's
# development host a bare `gsc` on PATH *is* Ghostscript, and Gambit's own keg is
# deliberately left unlinked because of the collision. So byte-machine never
# searches for `gsc`: it searches for `gsi`, which Ghostscript does not ship, and
# derives the compiler from the directory the interpreter was found in.
#
# Exit status cannot be part of telling them apart. Ghostscript's `gsc`, handed a
# Scheme file, prints its own banner and exits 0. Only the content of the probe
# output separates the two, which is why identity is decided on a required
# `gambit=yes` line rather than on a return code.
#
# The derivation is positional and carries no judgement: the derived path is
# interrogated exactly as the interpreter is, and the two must agree about what
# they are.

cmake_minimum_required(VERSION 3.26)

include("${CMAKE_CURRENT_LIST_DIR}/../../../cmake/ByteMachineGambit.cmake")

include("${CMAKE_CURRENT_LIST_DIR}/SpecSupport.cmake")

set(SPEC_SELF "${CMAKE_CURRENT_LIST_FILE}")

set(good_output "gambit=yes
version=v4.9.8
target=aarch64-apple-darwin25.6.0
stamp=20260809131432")

# What Ghostscript prints on this host when it is mistaken for Gambit.
set(ghostscript_output "GPL Ghostscript 10.07.1 (2026-05-19)
Copyright (C) 2026 Artifex Software, Inc.  All rights reserved.")

if(DEFINED BYTE_MACHINE_SPEC_CASE)
  set(c "${BYTE_MACHINE_SPEC_CASE}")

  if(c STREQUAL "ghostscript")
    byte_machine_gambit_identity("${ghostscript_output}" "/opt/homebrew/bin/gsc" v t s)
  elseif(c STREQUAL "too-old")
    byte_machine_gambit_identity(
      "gambit=yes\nversion=v4.9.4\ntarget=x86_64-pc-linux-gnu\nstamp=1" "/usr/bin/gsi" v t s)
  elseif(c STREQUAL "missing-stamp")
    byte_machine_gambit_identity(
      "gambit=yes\nversion=v4.9.8\ntarget=x86_64-pc-linux-gnu" "/usr/bin/gsi" v t s)
  elseif(c STREQUAL "beside-relative")
    byte_machine_gambit_compiler_beside("gsi" out)
  elseif(c STREQUAL "beside-wrong-name")
    byte_machine_gambit_compiler_beside("/opt/bin/scheme" out)
  elseif(c STREQUAL "disagree")
    byte_machine_gambit_require_agreement(
      "4.9.8" "aarch64-apple-darwin25.6.0" "20260809131432"
      "4.9.8" "aarch64-apple-darwin25.6.0" "19990101000000")
  else()
    message(FATAL_ERROR "byte-machine-spec: unknown case '${c}'")
  endif()

  message(FATAL_ERROR "byte-machine-spec: case '${c}' was accepted but must be rejected")
endif()

# --- Driver ----------------------------------------------------------------

# Positive: the local development runtime, with the 'v' marker stripped so
# evidence records compare bare numbers on both runtimes.
byte_machine_gambit_identity("${good_output}" "/opt/homebrew/opt/gambit-scheme/bin/gsi" v t s)
spec_check_equal("${v}" "4.9.8" "version with the 'v' marker stripped")
spec_check_equal("${t}" "aarch64-apple-darwin25.6.0" "target triple")
spec_check_equal("${s}" "20260809131432" "build stamp")

# A newer release is accepted; the pin is a floor.
byte_machine_gambit_identity(
  "gambit=yes\nversion=v4.9.9\ntarget=x86_64-pc-linux-gnu\nstamp=2" "/usr/bin/gsi" v t s)
spec_check_equal("${v}" "4.9.9" "a newer release is accepted")

# A version with no 'v' marker is taken as-is rather than mangled.
byte_machine_gambit_identity(
  "gambit=yes\nversion=4.9.8\ntarget=x86_64-pc-linux-gnu\nstamp=3" "/usr/bin/gsi" v t s)
spec_check_equal("${v}" "4.9.8" "version without the 'v' marker")

# Compiler derivation preserves whatever suffix the interpreter carries, so a
# Windows 'gsi.exe' yields 'gsc.exe' and a versioned 'gsi-4.9.8' yields its mate.
byte_machine_gambit_compiler_beside("/opt/homebrew/opt/gambit-scheme/bin/gsi" out)
spec_check_equal("${out}" "/opt/homebrew/opt/gambit-scheme/bin/gsc" "plain derivation")
byte_machine_gambit_compiler_beside("C:/gambit/bin/gsi.exe" out)
spec_check_equal("${out}" "C:/gambit/bin/gsc.exe" "windows suffix preserved")
byte_machine_gambit_compiler_beside("/usr/local/bin/gsi-4.9.8" out)
spec_check_equal("${out}" "/usr/local/bin/gsc-4.9.8" "version suffix preserved")

# Agreement holds when both probes describe one installation.
byte_machine_gambit_require_agreement(
  "4.9.8" "aarch64-apple-darwin25.6.0" "20260809131432"
  "4.9.8" "aarch64-apple-darwin25.6.0" "20260809131432")

# A hand-set compiler is never silently replaced by a derived one: the user has
# stated an intent, and an override that quietly stopped applying would be worse
# than a stale one.
byte_machine_gambit_compiler_for("/opt/a/bin/gsi" "/custom/gsc" "" path from)
spec_check_equal("${path}" "/custom/gsc" "a hand-set compiler is preserved")
spec_check_equal("${from}" "" "a hand-set compiler records no derivation")

# A cached derivation belonging to a *different* interpreter is discarded. This
# is how an interpreter and compiler come to belong to two installations: the
# interpreter is repointed on a later configure and the cached compiler is not.
byte_machine_gambit_compiler_for("/opt/b/bin/gsi" "/opt/a/bin/gsc" "/opt/a/bin/gsi" path from)
spec_check_equal("${path}" "/opt/b/bin/gsc" "a stale derivation is refreshed")
spec_check_equal("${from}" "/opt/b/bin/gsi" "the refreshed derivation records its source")

# A cached derivation from the same interpreter is reused unchanged.
byte_machine_gambit_compiler_for("/opt/a/bin/gsi" "/opt/a/bin/gsc" "/opt/a/bin/gsi" path from)
spec_check_equal("${path}" "/opt/a/bin/gsc" "a current derivation is reused")

# --- Negative cases --------------------------------------------------------

set(negative_cases
  "ghostscript|byte-machine: '/opt/homebrew/bin/gsc' is not Gambit"
  "too-old|byte-machine: Gambit 4.9.4 is older than the verified floor"
  "missing-stamp|byte-machine: the gambit probe of '/usr/bin/gsi' produced no 'stamp' field"
  "beside-relative|byte-machine: cannot derive the Gambit compiler from 'gsi'"
  "beside-wrong-name|byte-machine: cannot derive the Gambit compiler from '/opt/bin/scheme'"
  "disagree|byte-machine: the Gambit interpreter and compiler disagree")

spec_expect_all_rejected("${SPEC_SELF}" ${negative_cases})

message(STATUS "byte-machine-spec: ByteMachineGambit verified")
