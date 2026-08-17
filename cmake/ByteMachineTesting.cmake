# byte-machine test registration.
#
# The helper decides which tests exist at all, so its defects are invisible in
# the worst way: a malformed or duplicated registration produces a suite that
# runs fewer tests than it appears to and still reports success. Every rule
# below is therefore enforced at configure time, where it is a build failure,
# rather than at run time, where it would be a test that quietly never ran.
#
# Split per AGENTS.md's functional core / imperative shell rule:
#
#   functional core   byte_machine_test_name_parse, _validate_labels,
#                     _reserve_name, _require_timeout -- pure decisions with no
#                     add_test and no filesystem effects, so they are directly
#                     specifiable under `cmake -P`.
#   imperative shell  byte_machine_add_test -- registration and directory
#                     creation.
#
# Diagnostics use a stable "byte-machine: <reason>" prefix so the specification
# can assert on the exact wording, not merely on a nonzero exit.

include_guard(GLOBAL)

# --- Vocabulary ------------------------------------------------------------
#
# Layers follow the parent plan's testing strategy (section 22) rather than a
# generic unit/integration split, so a preset can select exactly the evidence a
# given CI stage needs.

set(BYTE_MACHINE_TEST_LAYERS
  harness       # the test harness proving things about itself
  unit          # constructors, accessors, single-behaviour semantics
  verify        # verifier diagnostics, positive and negative
  differential  # reference interpreter against generated code
  property      # generated machines and inputs
  determinism   # byte-identical emission across runs and runtimes
  fixture       # the private HTTP request fixture
  portability   # values crossing library boundaries; runtime identity
  example       # the documented end-to-end examples
  expected-red) # tests that must fail, proving the harness can fail

set(BYTE_MACHINE_TEST_BACKENDS chez gambit cmake)

set(BYTE_MACHINE_TEST_MODES source aot o1 direct)

# A backend may only be registered in a mode it can actually execute. Chez has
# source and ahead-of-time lanes; Gambit has a developer .o1 lane and a
# production `-exe -nopreload` lane; the CMake-layer specifications run directly
# under `cmake -P` and have no Scheme runtime at all.
set(BYTE_MACHINE_TEST_MODES_chez source aot)
# Gambit's `source` lane is `gsi` interpreting the .sld directly. protium has no
# equivalent because its lanes must link a native shim; byte-machine has no
# native code of its own, and both of Gambit's compiled modes shell out to a C
# compiler whose name was fixed when Gambit was built. Without this mode the
# first slice that runs Scheme could not run on Gambit at all without that
# toolchain, while Chez source needs nothing -- and parent plan section 24.2
# asks for a source suite that stays runnable without native compilation.
set(BYTE_MACHINE_TEST_MODES_gambit source o1 aot)
set(BYTE_MACHINE_TEST_MODES_cmake direct)

# --- Functional core -------------------------------------------------------

# byte_machine_test_name_parse(<name> <layer_var> <feature_var>
#                              <backend_var> <mode_var>)
#
# Validates byte-machine.<layer>.<feature>.<backend>.<mode> and returns its
# components. Fails fatally on any violation.
function(byte_machine_test_name_parse name out_layer out_feature out_backend out_mode)
  if(NOT name MATCHES "^byte-machine\\.([a-z0-9-]+)\\.([a-z0-9-]+)\\.([a-z0-9-]+)\\.([a-z0-9-]+)$")
    message(FATAL_ERROR
      "byte-machine: malformed test name '${name}'. Expected exactly five "
      "lowercase dot-separated segments: "
      "byte-machine.<layer>.<feature>.<backend>.<mode>")
  endif()

  # CMAKE_MATCH_* is clobbered by the next regex, so capture immediately.
  set(layer "${CMAKE_MATCH_1}")
  set(feature "${CMAKE_MATCH_2}")
  set(backend "${CMAKE_MATCH_3}")
  set(mode "${CMAKE_MATCH_4}")

  if(feature MATCHES "^-|-$")
    message(FATAL_ERROR
      "byte-machine: malformed test name '${name}'. Feature segment "
      "'${feature}' must not begin or end with a hyphen.")
  endif()

  if(NOT layer IN_LIST BYTE_MACHINE_TEST_LAYERS)
    message(FATAL_ERROR
      "byte-machine: unknown test layer '${layer}' in '${name}'. "
      "Known layers: ${BYTE_MACHINE_TEST_LAYERS}")
  endif()

  if(NOT backend IN_LIST BYTE_MACHINE_TEST_BACKENDS)
    message(FATAL_ERROR
      "byte-machine: unknown test backend '${backend}' in '${name}'. "
      "Known backends: ${BYTE_MACHINE_TEST_BACKENDS}")
  endif()

  if(NOT mode IN_LIST BYTE_MACHINE_TEST_MODES)
    message(FATAL_ERROR
      "byte-machine: unknown test mode '${mode}' in '${name}'. "
      "Known modes: ${BYTE_MACHINE_TEST_MODES}")
  endif()

  if(NOT mode IN_LIST BYTE_MACHINE_TEST_MODES_${backend})
    message(FATAL_ERROR
      "byte-machine: incompatible backend/mode in '${name}'. Backend "
      "'${backend}' supports only: ${BYTE_MACHINE_TEST_MODES_${backend}}")
  endif()

  set(${out_layer} "${layer}" PARENT_SCOPE)
  set(${out_feature} "${feature}" PARENT_SCOPE)
  set(${out_backend} "${backend}" PARENT_SCOPE)
  set(${out_mode} "${mode}" PARENT_SCOPE)
endfunction()

# byte_machine_test_validate_labels(<label>...)
#
# Every label must come from the checked-in vocabulary. An unrecognized label
# silently excludes a test from the preset that was meant to select it, so this
# is fatal rather than a warning.
function(byte_machine_test_validate_labels)
  set(known
    ${BYTE_MACHINE_TEST_LAYERS} ${BYTE_MACHINE_TEST_BACKENDS}
    ${BYTE_MACHINE_TEST_MODES})
  foreach(label IN LISTS ARGN)
    if(NOT label IN_LIST known)
      message(FATAL_ERROR
        "byte-machine: unknown test label '${label}'. Known labels: ${known}")
    endif()
  endforeach()
endfunction()

# byte_machine_test_reserve_name(<name>)
#
# CTest tolerates duplicate test names; byte-machine does not. A duplicate
# silently makes one registration unreachable, which is coverage lost with no
# signal at all.
function(byte_machine_test_reserve_name name)
  get_property(taken GLOBAL PROPERTY BYTE_MACHINE_RESERVED_TEST_NAMES)
  if(name IN_LIST taken)
    message(FATAL_ERROR "byte-machine: duplicate test name '${name}'.")
  endif()
  set_property(GLOBAL APPEND PROPERTY BYTE_MACHINE_RESERVED_TEST_NAMES "${name}")
endfunction()

# byte_machine_test_require_timeout(<value> <name>)
#
# Every registration carries an explicit outer bound. A test with no timeout
# cannot fail by hanging; it just stops the suite.
function(byte_machine_test_require_timeout value name)
  if(value STREQUAL "")
    message(FATAL_ERROR
      "byte-machine: TIMEOUT is required for '${name}'. Every registration "
      "carries an explicit outer timeout.")
  endif()
  if(NOT value MATCHES "^[0-9]+$" OR value EQUAL 0)
    message(FATAL_ERROR
      "byte-machine: TIMEOUT for '${name}' must be a positive whole number of "
      "seconds, got '${value}'.")
  endif()
endfunction()

# byte_machine_test_run_directory(<name> <override> <out_dir>)
#
# Where a lane launches from. Empty override means the derived private
# directory, which is the default precisely because Chez once resolved includes
# against the process working directory: a test allowed to run from the
# repository could load a body the build never staged, and would keep passing
# after that body stopped being staged correctly.
#
# A lane that overrides this is making a claim about where resolution happens,
# which is what the working-directory matrix in test/CMakeLists.txt exists to
# check. Pure, so that the choice can be specified without registering a test or
# creating a directory.
function(byte_machine_test_run_directory name override out_dir)
  if(override)
    set(${out_dir} "${override}" PARENT_SCOPE)
    return()
  endif()
  set(${out_dir} "${CMAKE_BINARY_DIR}/test-run/${name}" PARENT_SCOPE)
endfunction()

# --- Imperative shell ------------------------------------------------------

# byte_machine_add_test(NAME <name> COMMAND <cmd>... TIMEOUT <seconds>
#                       [WORKING_DIRECTORY <dir>] [LABELS <label>...]
#                       [ENVIRONMENT <K=V>...])
#
# Registers one CTest test with the layer, backend, and mode labels derived from
# its name, plus a private working and temporary directory.
#
# The working directory is inside the build tree, never the repository, unless
# WORKING_DIRECTORY names an existing directory of the caller's choosing. That is
# not tidiness: Chez resolves `include` against the process working directory
# (see docs/plans/milestone-0-portability-spike.md section 2), so a test allowed
# to run from the repository root could load a shared body the build never
# staged, and would keep passing after that body stopped being staged correctly.
function(byte_machine_add_test)
  cmake_parse_arguments(PARSE_ARGV 0 arg "" "NAME;TIMEOUT;WORKING_DIRECTORY" "COMMAND;LABELS;ENVIRONMENT")

  if(arg_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR
      "byte-machine: unexpected arguments to byte_machine_add_test: ${arg_UNPARSED_ARGUMENTS}")
  endif()
  if(NOT arg_NAME)
    message(FATAL_ERROR "byte-machine: NAME is required for byte_machine_add_test.")
  endif()
  if(NOT arg_COMMAND)
    message(FATAL_ERROR "byte-machine: COMMAND is required for '${arg_NAME}'.")
  endif()

  byte_machine_test_require_timeout("${arg_TIMEOUT}" "${arg_NAME}")
  byte_machine_test_name_parse("${arg_NAME}" layer feature backend mode)
  byte_machine_test_validate_labels(${arg_LABELS})
  byte_machine_test_reserve_name("${arg_NAME}")

  set(labels ${layer} ${backend} ${mode} ${arg_LABELS})
  list(REMOVE_DUPLICATES labels)

  # The temporary directory is always the derived one: a test that writes
  # scratch files must not be able to disturb a directory it was pointed at to
  # make a claim about resolution.
  set(tmp_dir "${CMAKE_BINARY_DIR}/test-run/${arg_NAME}/tmp")
  file(MAKE_DIRECTORY "${tmp_dir}")

  # The directory must exist. CTest reports a missing working directory as a
  # failure to launch, which the exact-status helper classifies as `did-not-run`
  # -- correct, but it points at the runtime rather than at the registration
  # that named a directory nobody created.
  if(arg_WORKING_DIRECTORY AND NOT IS_DIRECTORY "${arg_WORKING_DIRECTORY}")
    message(FATAL_ERROR
      "byte-machine: '${arg_NAME}' was given WORKING_DIRECTORY "
      "'${arg_WORKING_DIRECTORY}', which is not an existing directory. A lane "
      "that overrides its working directory is asserting something about where "
      "resolution happens, so the directory has to be one the build made on "
      "purpose.")
  endif()

  byte_machine_test_run_directory("${arg_NAME}" "${arg_WORKING_DIRECTORY}" run_dir)
  file(MAKE_DIRECTORY "${run_dir}")

  set(environment
    "BYTE_MACHINE_TEST_NAME=${arg_NAME}"
    "BYTE_MACHINE_TEST_TMPDIR=${tmp_dir}")
  if(arg_ENVIRONMENT)
    list(APPEND environment ${arg_ENVIRONMENT})
  endif()

  add_test(NAME "${arg_NAME}" COMMAND ${arg_COMMAND} WORKING_DIRECTORY "${run_dir}")
  set_tests_properties("${arg_NAME}" PROPERTIES
    TIMEOUT "${arg_TIMEOUT}"
    LABELS "${labels}"
    ENVIRONMENT "${environment}")
endfunction()
