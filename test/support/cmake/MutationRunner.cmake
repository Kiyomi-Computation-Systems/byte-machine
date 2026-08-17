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
#                       [EXPECT_SURVIVES <reason>]
#                       [EXPECT_STATUS <code>] [EXPECT_OUTPUT_MATCHES <regex>])
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
#
# A nonzero result from the verify command means only that it noticed
# *something*; by itself that is not evidence it noticed the decision this
# mutation names, and a mutation can be "caught" by an unrelated crash just as
# easily as by the refusal it is meant to prove. EXPECT_STATUS and
# EXPECT_OUTPUT_MATCHES narrow "caught" to "caught for this reason": when
# either is given, a nonzero result whose exit code or combined stdout+stderr
# does not also satisfy the declared expectation is reported separately, as
# caught for the wrong reason, and counted the same as UNCAUGHT. Neither is
# consulted when the verify command exits 0 -- that is simply not caught, the
# ordinary way. Apply them only where the wrong-reason risk is real; most
# mutations need neither.
function(byte_machine_mutation)
  cmake_parse_arguments(PARSE_ARGV 0 arg "" "FILE;SPEC;LABEL;FIND;REPLACE;SITES;EXPECT_SURVIVES;EXPECT_STATUS;EXPECT_OUTPUT_MATCHES" "")

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
  set_property(GLOBAL PROPERTY _bm_mut_${next}_expect_status "${arg_EXPECT_STATUS}")
  set_property(GLOBAL PROPERTY _bm_mut_${next}_expect_output_matches "${arg_EXPECT_OUTPUT_MATCHES}")
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

# byte_machine_mutation_run_spec(<stage_dir> <spec> <out_rc> <out_output>)
#
# A non-numeric result -- a command that could not be launched at all -- would
# compare unequal to 0 and count as caught. That is safe only because the
# baseline run happens first: if the verify command cannot run, the baseline
# fails and nothing below is trusted.
#
# out_output is stdout and stderr concatenated, in that order, with nothing
# else interleaved -- execute_process captures each as a whole, not as an
# interleaved stream, so this is an approximation of what a terminal would have
# shown, not a byte-accurate transcript. Good enough for EXPECT_OUTPUT_MATCHES,
# which looks for a fixed marker rather than reconstructing ordering.
function(byte_machine_mutation_run_spec stage_dir spec out_rc out_output)
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
  set(${out_output} "${out}${err}" PARENT_SCOPE)
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

  # Accumulated in a GLOBAL property, not a variable, because a suite that
  # verifies several decisions through several lanes calls this function once
  # per pass rather than once overall (SchemeMutationSuite.cmake, for one).
  # Both this counter and _bm_mutation_count are written with PARENT_SCOPE,
  # which reaches only the immediate caller -- and different passes call from
  # different scopes: bare script scope for a simple pass, a helper function's
  # own scope for a repeated one (byte_machine_slice3_launcher_pass and
  # byte_machine_slice3_body_pass, for instance). A plain variable would not
  # survive that; a global property has no scope to lose. The caller reads the
  # total back with byte_machine_mutation_totals once every pass has run.
  get_property(_bm_total_passes GLOBAL PROPERTY BYTE_MACHINE_MUTATION_TOTAL_PASSES)
  if(NOT _bm_total_passes)
    set(_bm_total_passes 0)
  endif()
  math(EXPR _bm_total_passes "${_bm_total_passes} + 1")
  set_property(GLOBAL PROPERTY BYTE_MACHINE_MUTATION_TOTAL_PASSES "${_bm_total_passes}")

  get_property(_bm_total_mutations GLOBAL PROPERTY BYTE_MACHINE_MUTATION_TOTAL_MUTATIONS)
  if(NOT _bm_total_mutations)
    set(_bm_total_mutations 0)
  endif()
  math(EXPR _bm_total_mutations "${_bm_total_mutations} + ${_bm_mutation_count}")
  set_property(GLOBAL PROPERTY BYTE_MACHINE_MUTATION_TOTAL_MUTATIONS "${_bm_total_mutations}")

  # --- Baseline: every specification a mutation targets must pass unmutated ---
  set(specs_used "")
  foreach(i RANGE 1 ${_bm_mutation_count})
    get_property(spec GLOBAL PROPERTY _bm_mut_${i}_spec)
    list(APPEND specs_used "${spec}")
  endforeach()
  list(REMOVE_DUPLICATES specs_used)

  foreach(spec IN LISTS specs_used)
    byte_machine_mutation_run_spec("${stage_dir}" "${spec}" rc baseline_output)
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
    get_property(expect_status GLOBAL PROPERTY _bm_mut_${i}_expect_status)
    get_property(expect_output_matches GLOBAL PROPERTY _bm_mut_${i}_expect_output_matches)

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
    byte_machine_mutation_run_spec("${stage_dir}" "${spec}" rc output)
    file(WRITE "${staged_path}" "${pristine}")

    # A nonzero result only means the verify command noticed *something*. When
    # the mutation says what the catch has to look like, check that before
    # trusting the exit code -- a status or an output fragment that does not
    # match is caught by coincidence, not by the decision this mutation names.
    set(reason_wrong "")
    if(NOT rc EQUAL 0)
      if(NOT expect_status STREQUAL "" AND NOT rc EQUAL expect_status)
        set(reason_wrong "expected the verify command to exit ${expect_status}, got ${rc}")
      elseif(expect_output_matches AND NOT output MATCHES "${expect_output_matches}")
        set(reason_wrong "expected the verify command's output to match '${expect_output_matches}', but it did not")
      endif()
    endif()

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
    elseif(reason_wrong)
      message(SEND_ERROR
        "byte-machine-mutation: '${label}' exited nonzero (${rc}) but for the "
        "wrong reason -- ${reason_wrong}. That is caught by coincidence, not by "
        "the decision this mutation names, and proves nothing about it.")
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

# byte_machine_mutation_totals(<out_passes> <out_mutations>)
#
# The running total across every byte_machine_mutation_run call made so far in
# this process. A suite calls this once, after its last pass, and compares the
# result against the count its own header comment declares -- the only thing
# that would otherwise notice a whole pass, or a single mutation within one,
# being quietly deleted: byte_machine_mutation_run's own uncaught-count check
# is per pass and cannot see a pass that never ran at all.
function(byte_machine_mutation_totals out_passes out_mutations)
  get_property(passes GLOBAL PROPERTY BYTE_MACHINE_MUTATION_TOTAL_PASSES)
  get_property(mutations GLOBAL PROPERTY BYTE_MACHINE_MUTATION_TOTAL_MUTATIONS)
  if(NOT passes)
    set(passes 0)
  endif()
  if(NOT mutations)
    set(mutations 0)
  endif()
  set(${out_passes} "${passes}" PARENT_SCOPE)
  set(${out_mutations} "${mutations}" PARENT_SCOPE)
endfunction()
