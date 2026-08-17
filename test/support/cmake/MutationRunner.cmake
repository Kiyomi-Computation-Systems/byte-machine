# Machinery for proving that the specifications are not vacuous.
#
# A specification that passes tells you nothing on its own: it might be checking
# the code, or it might be checking nothing at all. The only way to know is to
# break the code deliberately and confirm the specification notices. This file
# is that check, made reproducible and runnable in CI rather than performed once
# by hand and written up afterwards.
#
# WHY THE SOURCE TREE IS NEVER TOUCHED
#
# The obvious implementation edits a module in place, runs its specification,
# and edits it back. That leaves the repository corrupt if the run is
# interrupted -- by a timeout, a signal, or a failing assertion that aborts the
# script -- and the corruption is a subtly wrong module rather than an obvious
# one. Everything here operates on a staged copy inside the build tree instead.
# The source tree is only ever read.
#
# WHY THE BASELINE IS CHECKED FIRST
#
# "The specification failed after I broke the code" only means something if the
# specification passed before. If the staging is wrong -- a missed file, a
# broken relative include -- every specification fails for that reason and every
# mutation looks caught, which is the exact false confidence this file exists to
# eliminate. The baseline run is therefore a hard precondition, not a courtesy.

include_guard(GLOBAL)

set(_bm_mutation_count 0)

# Which trees are copied into the scratch tree. The default is what the
# CMake-layer suite needs; the Scheme suite adds the harness and the launchers,
# whose includes resolve against their relative layout and would break if the
# tree were flattened.
set(BYTE_MACHINE_MUTATION_STAGE_DIRS "cmake" "test/support/cmake")

# What decides whether a mutation was caught. Empty keeps the original
# behaviour: run the named specification under `cmake -P` inside the stage. The
# Scheme suite replaces it with a real execution lane, because a Scheme defect
# is only visible to something that runs Scheme.
set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND "")

# Where the verify command runs. Empty means the stage directory, which is what
# every pass wanted until slice 3. The working-directory matrix needs a pass per
# launch directory, because what it asserts is that the launch directory does
# not matter -- a claim no command run from one fixed place can make.
set(BYTE_MACHINE_MUTATION_VERIFY_WORKING_DIRECTORY "")

# byte_machine_mutation(FILE <repo-relative> SPEC <spec basename> LABEL <text>
#                       FIND <text> REPLACE <text> [SITES <n>]
#                       [EXPECT_SURVIVES <reason>])
#
# Declare one mutation. FIND and REPLACE are literal text, not regexes; pass
# them as bracket arguments so quotes, backslashes, and ${...} survive intact.
#
# SITES defaults to 1 and is asserted exactly: a pattern that stops matching
# because the module was refactored must be a loud failure, not a silently
# skipped mutation. That is the failure mode that would quietly hollow this
# suite out over time.
#
# EXPECT_SURVIVES inverts the expectation for a mutation the specifications
# knowingly cannot catch, and requires a reason. Such a mutation must still
# survive: if one starts being caught, the recorded limitation is stale and the
# suite says so rather than letting the documentation drift.
function(byte_machine_mutation)
  cmake_parse_arguments(PARSE_ARGV 0 arg "" "FILE;SPEC;LABEL;FIND;REPLACE;SITES;EXPECT_SURVIVES" "")

  if(arg_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR "byte-machine-mutation: unexpected arguments: ${arg_UNPARSED_ARGUMENTS}")
  endif()
  foreach(required FILE SPEC LABEL FIND REPLACE)
    if(NOT DEFINED arg_${required})
      message(FATAL_ERROR "byte-machine-mutation: ${required} is required (label '${arg_LABEL}').")
    endif()
  endforeach()
  if(NOT DEFINED arg_SITES)
    set(arg_SITES 1)
  endif()

  math(EXPR next "${_bm_mutation_count} + 1")
  set(_bm_mutation_count "${next}" PARENT_SCOPE)

  set_property(GLOBAL PROPERTY _bm_mut_${next}_file "${arg_FILE}")
  set_property(GLOBAL PROPERTY _bm_mut_${next}_spec "${arg_SPEC}")
  set_property(GLOBAL PROPERTY _bm_mut_${next}_label "${arg_LABEL}")
  set_property(GLOBAL PROPERTY _bm_mut_${next}_find "${arg_FIND}")
  set_property(GLOBAL PROPERTY _bm_mut_${next}_replace "${arg_REPLACE}")
  set_property(GLOBAL PROPERTY _bm_mut_${next}_sites "${arg_SITES}")
  set_property(GLOBAL PROPERTY _bm_mut_${next}_survives "${arg_EXPECT_SURVIVES}")
endfunction()

# byte_machine_mutation_stage(<source_root> <stage_dir>)
#
# Copy every declared tree into a scratch tree, preserving the relative layout
# the specifications' and the libraries' includes depend on.
function(byte_machine_mutation_stage source_root stage_dir)
  file(REMOVE_RECURSE "${stage_dir}")

  foreach(rel IN LISTS BYTE_MACHINE_MUTATION_STAGE_DIRS)
    file(MAKE_DIRECTORY "${stage_dir}/${rel}")
    file(GLOB entries "${source_root}/${rel}/*")
    if(NOT entries)
      message(FATAL_ERROR
        "byte-machine-mutation: staging found nothing under '${rel}' in "
        "'${source_root}'. Refusing to run: an empty stage would make every "
        "mutation look caught, which is the exact false confidence this file "
        "exists to eliminate.")
    endif()
    # Directories are copied whole, so a tree such as the harness keeps the
    # layout its relative includes resolve against.
    file(COPY ${entries} DESTINATION "${stage_dir}/${rel}")
  endforeach()
endfunction()

# byte_machine_mutation_run_spec(<stage_dir> <spec> <out_rc>)
#
# A non-numeric result -- a command that could not be launched at all -- would
# compare unequal to 0 and count as caught. That is safe only because the
# baseline run happens first: if the verify command cannot run, the baseline
# fails and nothing below is trusted.
function(byte_machine_mutation_run_spec stage_dir spec out_rc)
  if(BYTE_MACHINE_MUTATION_VERIFY_COMMAND)
    set(command ${BYTE_MACHINE_MUTATION_VERIFY_COMMAND})
  else()
    set(command "${CMAKE_COMMAND}" -P "${stage_dir}/test/support/cmake/${spec}")
  endif()

  set(verify_cwd "${stage_dir}")
  if(BYTE_MACHINE_MUTATION_VERIFY_WORKING_DIRECTORY)
    set(verify_cwd "${BYTE_MACHINE_MUTATION_VERIFY_WORKING_DIRECTORY}")
  endif()

  execute_process(
    COMMAND ${command}
    WORKING_DIRECTORY "${verify_cwd}"
    RESULT_VARIABLE rc
    OUTPUT_VARIABLE out
    ERROR_VARIABLE err)
  set(${out_rc} "${rc}" PARENT_SCOPE)
endfunction()

# byte_machine_mutation_reset()
#
# Discard the declared mutations so a second set can run under a different
# verify command in the same script. Used by the Scheme suite, which verifies
# the shared runner on one runtime but must verify each adapter's export list on
# its own runtime -- a Chez lane cannot notice a name missing from the Gambit
# library.
function(byte_machine_mutation_reset)
  set(_bm_mutation_count 0 PARENT_SCOPE)
endfunction()

# byte_machine_mutation_run(<source_root> <stage_dir>)
function(byte_machine_mutation_run source_root stage_dir)
  byte_machine_mutation_stage("${source_root}" "${stage_dir}")

  if(_bm_mutation_count EQUAL 0)
    message(FATAL_ERROR
      "byte-machine-mutation: no mutations declared. An empty suite passes "
      "trivially and would report the specifications as verified.")
  endif()

  # --- Baseline: every specification a mutation targets must pass unmutated ---
  set(specs_used "")
  foreach(i RANGE 1 ${_bm_mutation_count})
    get_property(spec GLOBAL PROPERTY _bm_mut_${i}_spec)
    list(APPEND specs_used "${spec}")
  endforeach()
  list(REMOVE_DUPLICATES specs_used)

  foreach(spec IN LISTS specs_used)
    byte_machine_mutation_run_spec("${stage_dir}" "${spec}" rc)
    if(NOT rc EQUAL 0)
      message(FATAL_ERROR
        "byte-machine-mutation: baseline failure. '${spec}' does not pass on the "
        "staged, unmutated tree (exit ${rc}), so every mutation against it would "
        "look caught for the wrong reason. Fix the staging or the specification "
        "before trusting any result below.")
    endif()
  endforeach()
  message(STATUS "byte-machine-mutation: baseline green for ${specs_used}")

  # --- Mutations ---------------------------------------------------------
  set(uncaught 0)
  foreach(i RANGE 1 ${_bm_mutation_count})
    get_property(rel GLOBAL PROPERTY _bm_mut_${i}_file)
    get_property(spec GLOBAL PROPERTY _bm_mut_${i}_spec)
    get_property(label GLOBAL PROPERTY _bm_mut_${i}_label)
    get_property(find GLOBAL PROPERTY _bm_mut_${i}_find)
    get_property(replace GLOBAL PROPERTY _bm_mut_${i}_replace)
    get_property(sites GLOBAL PROPERTY _bm_mut_${i}_sites)
    get_property(survives GLOBAL PROPERTY _bm_mut_${i}_survives)

    set(pristine_path "${source_root}/${rel}")
    set(staged_path "${stage_dir}/${rel}")
    if(NOT EXISTS "${pristine_path}")
      message(SEND_ERROR "byte-machine-mutation: '${label}': no such file '${rel}'")
      math(EXPR uncaught "${uncaught} + 1")
      continue()
    endif()

    file(READ "${pristine_path}" pristine)

    # Count occurrences literally. string(FIND) does no regex interpretation, so
    # patterns full of quotes, backslashes, and ${...} need no escaping and no
    # sentinel character.
    string(LENGTH "${find}" find_length)
    set(found 0)
    set(remaining "${pristine}")
    string(FIND "${remaining}" "${find}" at)
    while(NOT at EQUAL -1)
      math(EXPR found "${found} + 1")
      math(EXPR cut "${at} + ${find_length}")
      string(SUBSTRING "${remaining}" ${cut} -1 remaining)
      string(FIND "${remaining}" "${find}" at)
    endwhile()

    if(NOT found EQUAL sites)
      message(SEND_ERROR
        "byte-machine-mutation: '${label}': pattern occurs ${found} times in "
        "${rel}, expected ${sites}. The module was probably refactored; update "
        "the mutation rather than deleting it, or this check silently stops "
        "covering that code.")
      math(EXPR uncaught "${uncaught} + 1")
      continue()
    endif()

    string(REPLACE "${find}" "${replace}" mutated "${pristine}")
    file(WRITE "${staged_path}" "${mutated}")
    byte_machine_mutation_run_spec("${stage_dir}" "${spec}" rc)
    file(WRITE "${staged_path}" "${pristine}")

    if(survives)
      if(rc EQUAL 0)
        message(STATUS "byte-machine-mutation: SURVIVES (expected) ${label} -- ${survives}")
      else()
        message(SEND_ERROR
          "byte-machine-mutation: '${label}' is recorded as knowingly uncaught "
          "(${survives}) but the specification caught it. The recorded "
          "limitation is stale: remove EXPECT_SURVIVES and update the decision "
          "record that cites it.")
        math(EXPR uncaught "${uncaught} + 1")
      endif()
    elseif(rc EQUAL 0)
      message(SEND_ERROR
        "byte-machine-mutation: UNCAUGHT ${label} -- ${spec} still passes with "
        "${rel} broken. That specification is not testing this behaviour.")
      math(EXPR uncaught "${uncaught} + 1")
    else()
      message(STATUS "byte-machine-mutation: caught ${label}")
    endif()
  endforeach()

  if(uncaught EQUAL 0)
    message(STATUS
      "byte-machine-mutation: ${_bm_mutation_count} mutations, all accounted for")
  endif()
endfunction()
