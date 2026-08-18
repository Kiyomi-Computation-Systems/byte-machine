# Register one execution lane: a program, run by one runtime, in one mode.
#
# WHY THE COMMAND LINE IS BUILT IN ONE PLACE
#
# Ten registrations that each spell out their own invocation drift. The two
# details most worth not drifting are invisible when they are wrong: Chez's
# object-guard pair, without which a stale compiled object is silently preferred
# over the source a "source" lane claims to run, and Gambit's -f, without which
# a developer's .gambini file participates in every test result.
#
# Slice 2 registers only source lanes. The compiled lanes arrive in slice 5 and
# extend this module rather than replacing it.

include_guard(GLOBAL)

include("${CMAKE_CURRENT_LIST_DIR}/ByteMachineExpectExit.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/ByteMachineTesting.cmake")

# --- Functional core -------------------------------------------------------

# byte_machine_scheme_lane_gambit_search(<out_option> <out_status> <out_message>
#                                        <dir>...)
#
# Build Gambit's `-:` runtime-option argument putting every <dir> on the module
# search path. Status is `ok`, `comma-in-path`, or `relative-path`.
#
# The comma check is not defensive programming. Gambit's -: option list is
# comma-separated, so a root containing one is not a wrong path but a malformed
# option list: gsi prints its usage banner and runs nothing, on every Gambit
# lane at once, mentioning nothing this project owns. A checkout under
# ~/my,projects/ is enough. Refusing at configure time turns that into a
# sentence naming the directory.
function(byte_machine_scheme_lane_gambit_search out_option out_status out_message)
  set(${out_option} "" PARENT_SCOPE)
  set(${out_message} "" PARENT_SCOPE)

  set(parts "")
  foreach(dir IN LISTS ARGN)
    if(dir MATCHES ",")
      set(${out_status} "comma-in-path" PARENT_SCOPE)
      set(${out_message}
        "a Gambit search root must not contain a comma, but '${dir}' does. Gambit's -: options are comma-separated, so gsi would print its usage banner and run no Scheme at all."
        PARENT_SCOPE)
      return()
    endif()
    if(NOT IS_ABSOLUTE "${dir}")
      set(${out_status} "relative-path" PARENT_SCOPE)
      set(${out_message}
        "a Gambit search root must be absolute, but '${dir}' is not. Gambit resolves a relative root against its own working directory, so the lane would find its libraries or not depending on where it was launched."
        PARENT_SCOPE)
      return()
    endif()
    list(APPEND parts "search=${dir}")
  endforeach()

  list(JOIN parts "," joined)
  set(${out_option} "-:${joined}" PARENT_SCOPE)
  set(${out_status} "ok" PARENT_SCOPE)
endfunction()

# byte_machine_lane_measured_copies(<dir> <out_var> <declared-body>...)
#
# Map each declared body to the copy a compiled lane's build step wrote into
# <dir>. Flat and keyed by basename, which is unambiguous because
# byte_machine_guard_duplicate_basenames forbids two shared bodies sharing one
# repository-wide. One rule for every compiled lane: protium needs per-lane
# path logic here precisely because it has no equivalent guard.
function(byte_machine_lane_measured_copies dir out_var)
  set(copies "")
  foreach(body IN LISTS ARGN)
    get_filename_component(name "${body}" NAME)
    list(APPEND copies "${dir}/${name}")
  endforeach()
  set(${out_var} "${copies}" PARENT_SCOPE)
endfunction()

# byte_machine_chez_aot_paths(<name> <program> <out_object_dir> <out_compiled>)
#
# Where one AOT lane's artifacts live. Keyed by Chez version and machine type
# (BYTE_MACHINE_CHEZ_OBJECT_ROOT) so a parallel build cannot race and no
# object outlives the runtime that produced it, and by LANE NAME -- not
# program -- so two lanes that build the same program from different text
# share nothing. That is not hypothetical: this slice registers
# byte-machine.harness.self.chez.aot and
# byte-machine.harness.stale-artifact.chez.aot over the same PROGRAM,
# harness-self-tests.chez.sps, and the second exists to compile it from
# deliberately divergent text. Keyed by program stem instead, both would
# resolve to one object directory, one compiled .so, and one flat
# fingerprint/ directory, so the stale lane's copies would silently overwrite
# the real lane's.
function(byte_machine_chez_aot_paths name program out_object_dir out_compiled)
  string(REPLACE "." "_" name_key "${name}")
  set(dir "${BYTE_MACHINE_CHEZ_OBJECT_ROOT}/${name_key}")
  set(${out_object_dir} "${dir}" PARENT_SCOPE)
  # NAME_WLE, not NAME_WE: NAME_WE strips the longest extension, so
  # harness-self-tests.chez.sps and harness-self-tests.gambit.scm would both
  # yield the stem harness-self-tests -- harmless now that the directory
  # above is keyed per lane rather than per program, but NAME_WLE keeps the
  # .chez segment in the artifact's filename, one less thing a reader of the
  # object tree has to reconstruct from the directory name alone.
  get_filename_component(stem "${program}" NAME_WLE)
  set(${out_compiled} "${dir}/${stem}.so" PARENT_SCOPE)
endfunction()

# byte_machine_scheme_lane_command(<name> <backend> <mode> <program>
#                                  <out_command> <out_measured>
#                                  <out_status> <out_message>
#                                  <declared-body>...)
#
# Status is `ok`, `no-runtime`, `unknown-backend`, `unknown-mode` -- or, for
# gambit, one of byte_machine_scheme_lane_gambit_search's own statuses
# (`comma-in-path`, `relative-path`), forwarded unchanged. A missing runtime is
# not fatal: the CMake-layer specifications must stay runnable on a host with
# no Scheme installed, so a lane whose runtime was never discovered is skipped
# with a message rather than failing configuration. The runtime check runs
# first, ahead of the mode check that can produce `unknown-mode`, for the same
# reason: a lane naming a mode this module cannot build yet (Gambit's aot and
# o1, at present -- see the Gambit branch below) must still fail loudly on a
# host that has the runtime to attempt it, but must not turn `cmake --preset
# no-scheme` into a configure failure over a backend/mode combination the host
# was never going to exercise.
#
# <out_measured> is the list of paths the run will fingerprint, in the order
# the declared bodies were given. For a source lane it is the declared list:
# the repository sources are the only text there is. For a compiled lane it is
# the copies the build wrote beside the artifact, so a fingerprint describes
# what the artifact was built from rather than what is on disk now.
#
# Order is load-bearing. harness-fingerprint-combine is order-sensitive by
# design, so measured[i] must correspond to declared[i]; the mapping below
# walks the declared list rather than partitioning and rejoining it.
function(byte_machine_scheme_lane_command name backend mode program
         out_command out_measured out_status out_message)
  set(${out_command} "" PARENT_SCOPE)
  set(${out_measured} "" PARENT_SCOPE)
  set(${out_message} "" PARENT_SCOPE)

  if(backend STREQUAL "chez")
    if(NOT BYTE_MACHINE_CHEZ_EXECUTABLE)
      set(${out_status} "no-runtime" PARENT_SCOPE)
      set(${out_message}
        "no Chez was discovered, so the chez ${mode} lane for '${program}' is not registered."
        PARENT_SCOPE)
      return()
    endif()

    if(mode STREQUAL "source")
      # Flags, not positions: a lane names one library root per library family it
      # imports and one source directory per shared-body directory, and both
      # counts grow with each slice.
      set(${out_command}
        "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
        "--script" "${BYTE_MACHINE_HARNESS_CHEZ_LAUNCHER}"
        "--library-root" "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}"
        "--library-root" "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}"
        "--source-dir" "${BYTE_MACHINE_HARNESS_SHARED_DIR}"
        "--source-dir" "${BYTE_MACHINE_SRC_COMMON_DIR}"
        "--object-guard" "${BYTE_MACHINE_HARNESS_OBJECT_GUARD_DIR}"
        "--program" "${program}"
        PARENT_SCOPE)
      set(${out_measured} ${ARGN} PARENT_SCOPE)
      set(${out_status} "ok" PARENT_SCOPE)
      return()
    endif()

    if(mode STREQUAL "aot")
      byte_machine_chez_aot_paths("${name}" "${program}" object_dir compiled)
      # --source-guard pairs every --object-dir's SOURCE half with the same
      # always-empty directory the chez.source lane uses as its OBJECT guard
      # (BYTE_MACHINE_HARNESS_OBJECT_GUARD_DIR, set once in
      # test/CMakeLists.txt). A bare directory string handed to
      # library-directories becomes both halves of the pair, so without this
      # an object directory is also a source directory Chez can expand;
      # chez-aot.ss's own header records the measurement.
      set(${out_command}
        "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
        "--script" "${BYTE_MACHINE_HARNESS_CHEZ_AOT_LAUNCHER}"
        "--object-dir" "${object_dir}/harness"
        "--object-dir" "${object_dir}/src"
        "--source-guard" "${BYTE_MACHINE_HARNESS_OBJECT_GUARD_DIR}"
        "--program" "${compiled}"
        PARENT_SCOPE)
      byte_machine_lane_measured_copies("${object_dir}/fingerprint" measured ${ARGN})
      set(${out_measured} ${measured} PARENT_SCOPE)
      set(${out_status} "ok" PARENT_SCOPE)
      return()
    endif()

    set(${out_status} "unknown-mode" PARENT_SCOPE)
    set(${out_message}
      "'${mode}' is not an execution mode this lane module can build a command for. Known modes: source aot."
      PARENT_SCOPE)
    return()
  endif()

  if(backend STREQUAL "gambit")
    if(NOT BYTE_MACHINE_GAMBIT_EXECUTABLE)
      set(${out_status} "no-runtime" PARENT_SCOPE)
      set(${out_message}
        "no Gambit was discovered, so the gambit ${mode} lane for '${program}' is not registered."
        PARENT_SCOPE)
      return()
    endif()
    if(NOT mode STREQUAL "source")
      set(${out_status} "unknown-mode" PARENT_SCOPE)
      set(${out_message}
        "'${mode}' is not an execution mode the gambit backend of this lane module can build a command for yet. Known modes: source. Gambit's compiled modes (o1, aot) arrive in a later slice."
        PARENT_SCOPE)
      return()
    endif()

    # `-:` runtime options must be the first argument, and the option list is
    # comma-separated: `search=A,search=B` puts two module roots on the path.
    # Measured, with a control proving the second root is load-bearing
    # (docs/plans/milestone-0-slice-3-shared-body.md section 2).
    # `-f` skips .gambini so a developer's personal initialisation cannot change
    # what a test proves. No launcher is needed: Gambit's include inside
    # define-library is source-file-relative and needs no ambient state.
    byte_machine_scheme_lane_gambit_search(search_option search_status search_message
      "${BYTE_MACHINE_HARNESS_GAMBIT_LIBRARY_ROOT}"
      "${BYTE_MACHINE_SRC_GAMBIT_LIBRARY_ROOT}")
    if(NOT search_status STREQUAL "ok")
      set(${out_status} "${search_status}" PARENT_SCOPE)
      set(${out_message} "${search_message}" PARENT_SCOPE)
      return()
    endif()

    set(${out_command}
      "${BYTE_MACHINE_GAMBIT_EXECUTABLE}"
      "${search_option}"
      "-f"
      "${program}"
      PARENT_SCOPE)
    set(${out_measured} ${ARGN} PARENT_SCOPE)
    set(${out_status} "ok" PARENT_SCOPE)
    return()
  endif()

  set(${out_status} "unknown-backend" PARENT_SCOPE)
  set(${out_message}
    "'${backend}' is not a Scheme lane backend. Known backends: chez gambit."
    PARENT_SCOPE)
endfunction()

# --- Imperative shell ------------------------------------------------------

# byte_machine_add_scheme_lane(NAME <name> BACKEND <chez|gambit> PROGRAM <path>
#                              TIMEOUT <seconds> [EXPECT_EXIT <code>]
#                              [WORKING_DIRECTORY <dir>]
#                              [LABELS ...] [ENVIRONMENT ...])
#
# With EXPECT_EXIT the lane is registered through the exact-status helper;
# without it, a nonzero exit fails the test in the ordinary way.
function(byte_machine_add_scheme_lane)
  cmake_parse_arguments(PARSE_ARGV 0 arg "WRONG_FINGERPRINT"
    "NAME;BACKEND;PROGRAM;TIMEOUT;EXPECT_EXIT;WORKING_DIRECTORY"
    "LABELS;ENVIRONMENT;SHARED_BODIES")

  if(arg_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR
      "byte-machine: unexpected arguments to byte_machine_add_scheme_lane: ${arg_UNPARSED_ARGUMENTS}")
  endif()
  # SHARED_BODIES is required, not optional. The property worth having is not
  # "the lanes have provenance" but "a lane cannot be added without it" -- and
  # this configure-time check is the whole of that guarantee, because the
  # harness skips provenance rather than refusing when no manifest reaches it.
  # It matters little here, where every lane is a source lane, and a great deal
  # in slices 5b and 5c, where a lane registered without provenance is exactly
  # the lane that can silently fall back to source.
  foreach(required NAME BACKEND PROGRAM TIMEOUT SHARED_BODIES)
    if(NOT arg_${required})
      message(FATAL_ERROR
        "byte-machine: ${required} is required for byte_machine_add_scheme_lane ('${arg_NAME}').")
    endif()
  endforeach()
  if(NOT EXISTS "${arg_PROGRAM}")
    message(FATAL_ERROR
      "byte-machine: '${arg_NAME}' names a program that does not exist: "
      "${arg_PROGRAM}. A lane registered against a missing file would fail at "
      "run time with a runtime error rather than at configure time with this one.")
  endif()
  # A manifest entry that does not exist would be a provenance failure at run
  # time, reported by the harness as though the build tree were incomplete. It
  # is a registration mistake, and it is cheaper to say so here.
  foreach(body IN LISTS arg_SHARED_BODIES)
    if(NOT EXISTS "${body}")
      message(FATAL_ERROR
        "byte-machine: '${arg_NAME}' names a shared body that does not exist: "
        "${body}.")
    endif()
  endforeach()

  # Within this registrar the name is the single source of the mode, so a
  # registration here cannot claim one lane while running another. It is not the
  # only place the repository sets BYTE_MACHINE_EXECUTION_MODE: nine
  # registrations in test/CMakeLists.txt (search that name) bypass this function
  # and hand-set it directly instead, and nothing enforces those the way this
  # parse does. Eight name a .chez.source lane and hand-set "source", so they
  # agree literally. The ninth, byte-machine.harness.scheme-mutation.cmake.direct,
  # does not describe itself at all: its name's mode field is "direct", a
  # cmake-backend value disjoint from the source/aot/o1 vocabulary, and the
  # "source" it sets is for the lanes it stages and runs. There is nothing there
  # for agreement to mean, which is why this comment does not claim it.
  # byte_machine_add_test parses the same name again for its labels; the
  # function is pure, so parsing it twice is cheaper than passing a parsed field
  # through a registrar that does not need it.
  byte_machine_test_name_parse("${arg_NAME}" lane_layer lane_feature
                               lane_backend lane_mode)

  byte_machine_scheme_lane_command(
    "${arg_NAME}" "${arg_BACKEND}" "${lane_mode}" "${arg_PROGRAM}"
    command measured status message ${arg_SHARED_BODIES})

  if(status STREQUAL "unknown-backend"
     OR status STREQUAL "unknown-mode"
     OR status STREQUAL "comma-in-path"
     OR status STREQUAL "relative-path")
    message(FATAL_ERROR "byte-machine: ${message}")
  endif()
  if(status STREQUAL "no-runtime")
    message(STATUS "byte-machine: skipping ${arg_NAME} -- ${message}")
    return()
  endif()

  # The lane registration declares the execution mode; the launcher never
  # touches this variable. For the Chez lane, the launcher's object guard is
  # what makes the declaration unfalsifiable: it makes a compiled object
  # impossible to load.
  #
  # The fixture is immutable and lives in the source tree; a lane only ever
  # reads it. Set for every lane rather than only the self-tests, so a body that
  # starts needing it does not also need a registration change.
  #
  # arg_ENVIRONMENT is deliberately not spliced in here: CTest applies
  # ENVIRONMENT entries in list order, so for a repeated key the last one wins.
  # It is appended once, after every default this function computes for itself
  # (including the manifest block below), so a caller-supplied entry can always
  # override a default -- which is exactly how the provenance lanes in
  # test/CMakeLists.txt force a specific, named failure: by overriding
  # BYTE_MACHINE_FINGERPRINT_FILES or BYTE_MACHINE_EXPECT_FINGERPRINT_FILE after
  # this function has already computed the real ones.
  set(environment
    "BYTE_MACHINE_EXECUTION_MODE=${lane_mode}"
    "BYTE_MACHINE_FINGERPRINT_SAMPLE=${CMAKE_SOURCE_DIR}/test/fixtures/fingerprint-sample.bin")

  # The manifest, and the expectation it must agree with. The separator is `|`
  # rather than a path separator: `:` and `;` differ between platforms, and `|`
  # is illegal in a Windows path, so it cannot occur inside a member.
  #
  # Gated on a discovered Chez, because byte_machine_expected_fingerprint runs
  # the expectation launcher under Chez. A host with Gambit but no Chez reaches
  # this line on every Gambit lane -- that lane's own runtime was found, so it
  # did not take the no-runtime return above -- and would otherwise build a
  # custom command whose executable is the empty string. Neither variable is set
  # in that case, so the harness skips provenance exactly as it does for any
  # process a lane registration did not start. The lane still runs and still
  # proves what it proved before this slice; it just carries no fingerprint,
  # which is the honest outcome when the build cannot compute one.
  if(BYTE_MACHINE_CHEZ_EXECUTABLE)
    string(JOIN "|" fingerprint_files ${measured})
    if(arg_WRONG_FINGERPRINT)
      byte_machine_wrong_fingerprint("${arg_NAME}" expect_file)
    else()
      byte_machine_expected_fingerprint("${arg_NAME}" expect_file
                                        ${arg_SHARED_BODIES})
    endif()
    list(APPEND environment
      "BYTE_MACHINE_FINGERPRINT_FILES=${fingerprint_files}"
      "BYTE_MACHINE_EXPECT_FINGERPRINT_FILE=${expect_file}")
  endif()

  # See the comment above the initial set(environment ...): appended last so a
  # caller-supplied entry always wins over a default, including the two above.
  list(APPEND environment ${arg_ENVIRONMENT})

  # Same CMP0174 reasoning as byte_machine_add_exit_code_test in
  # ByteMachineExpectExit.cmake: forward WORKING_DIRECTORY only when there is
  # a value, rather than forwarding an empty one unconditionally.
  set(working_directory_args "")
  if(arg_WORKING_DIRECTORY)
    set(working_directory_args WORKING_DIRECTORY "${arg_WORKING_DIRECTORY}")
  endif()

  if(DEFINED arg_EXPECT_EXIT)
    byte_machine_add_exit_code_test(
      NAME "${arg_NAME}"
      COMMAND ${command}
      EXPECT_EXIT "${arg_EXPECT_EXIT}"
      TIMEOUT "${arg_TIMEOUT}"
      LABELS ${arg_LABELS}
      ${working_directory_args}
      ENVIRONMENT ${environment})
  else()
    byte_machine_add_test(
      NAME "${arg_NAME}"
      COMMAND ${command}
      TIMEOUT "${arg_TIMEOUT}"
      LABELS ${arg_LABELS}
      ${working_directory_args}
      ENVIRONMENT ${environment})
  endif()
endfunction()
