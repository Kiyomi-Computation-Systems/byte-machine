# Guard the two rules that keep shared bodies shared.
#
# WHY THESE TWO FAILURES NEED A GUARD RATHER THAN A TEST
#
# Both are silent. A body with only one wrapper is proven on one runtime while
# the tree suggests two: nothing fails, there is simply one fewer lane than
# there appears to be. Two bodies with the same basename collapse into one file,
# because Chez resolves includes through source-directories -- one flat,
# process-global namespace, shared with src/common once Milestone 1 lands -- and
# the build stays green with one body never executed again.
#
# Neither can be caught by a test that runs, because in both cases the thing
# that should have run is exactly the thing that does not. So they are configure
# failures: a violation stops the build.
#
# The glob is CONFIGURE_DEPENDS wherever there is a build system to honour the
# keyword -- script mode is the sole exception, explained at the glob itself --
# and its result is asserted non-empty. A guard that silently skips new files,
# or that finds nothing and reports every source portable, is worse than no
# guard at all.

include_guard(GLOBAL)

# --- Functional core -------------------------------------------------------

# byte_machine_guard_shared_bodies(<out_bodies> <path>...)
#
# Drop wrapper files from a glob result. A wrapper declares its runtime in its
# own name -- harness-failing.chez.sps, harness-failing.gambit.scm -- and exists
# precisely to hold the import forms a shared body may not have.
function(byte_machine_guard_shared_bodies out_bodies)
  set(bodies ${ARGN})
  list(FILTER bodies EXCLUDE REGEX "\\.(chez|gambit)\\.(sps|scm)$")
  set(${out_bodies} "${bodies}" PARENT_SCOPE)
endfunction()

# byte_machine_guard_duplicate_basenames(<out_duplicates> <path>...)
#
# Basenames appearing more than once, each reported once however often it
# repeats. Compared with the extension, because the extension is part of what
# an include names.
function(byte_machine_guard_duplicate_basenames out_duplicates)
  set(seen "")
  set(duplicates "")
  foreach(path IN LISTS ARGN)
    get_filename_component(base "${path}" NAME)
    if(base IN_LIST seen)
      list(APPEND duplicates "${base}")
    endif()
    list(APPEND seen "${base}")
  endforeach()
  if(duplicates)
    list(REMOVE_DUPLICATES duplicates)
  endif()
  set(${out_duplicates} "${duplicates}" PARENT_SCOPE)
endfunction()

# byte_machine_guard_missing_wrappers(<out_missing> <body>...)
#
# Bodies lacking a wrapper, reported as `<body>|<missing wrapper>` so the
# diagnostic can name the file that should exist rather than only the one that
# does.
function(byte_machine_guard_missing_wrappers out_missing)
  set(missing "")
  foreach(body IN LISTS ARGN)
    get_filename_component(dir "${body}" DIRECTORY)
    # NAME_WE strips from the first dot, so `x.gambit.scm` and `x.scm` both
    # yield `x`. That is what makes the sibling names below correct.
    get_filename_component(base "${body}" NAME_WE)
    foreach(wrapper "${dir}/${base}.chez.sps" "${dir}/${base}.gambit.scm")
      if(NOT EXISTS "${wrapper}")
        list(APPEND missing "${body}|${wrapper}")
      endif()
    endforeach()
  endforeach()
  set(${out_missing} "${missing}" PARENT_SCOPE)
endfunction()

# --- Imperative shell ------------------------------------------------------

# byte_machine_portability_guard(SHARED_DIRS <dir>... WRAPPED_DIRS <dir>...)
#
# SHARED_DIRS hold bodies included by a library; they need no wrappers.
# WRAPPED_DIRS hold bodies included by a program; each needs both wrappers.
# Every body from either kind of directory shares one basename namespace.
function(byte_machine_portability_guard)
  cmake_parse_arguments(PARSE_ARGV 0 arg "" "" "SHARED_DIRS;WRAPPED_DIRS")

  # A guard that accepts a keyword it does not understand reports success for a
  # rule it never applied, which is the failure this whole module exists to
  # prevent. This check sees one half of that hazard and the directory check
  # below sees the other, because both keywords are multi-value: a stray token
  # is unparsed only until the first recognised keyword, and after one it is
  # absorbed into that keyword's value instead of arriving here. Neither check
  # subsumes the other -- a token before any keyword never reaches the
  # directory check, and a token after one never reaches this check -- so a
  # mistyped keyword is refused wherever in the call it was written.
  if(arg_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR
      "byte-machine: unexpected arguments to byte_machine_portability_guard: ${arg_UNPARSED_ARGUMENTS}")
  endif()

  # The other half. Both keywords name directories, and this guard only ever
  # learns of a body by globbing one, so an entry that is not a directory
  # contributes no match, no violation, and a success banner over a tree
  # nothing looked at -- the header's "worse than no guard at all". A keyword
  # absorbed into the preceding keyword's value arrives here as exactly that:
  # a directory named `WRAPPED_DIR` -- or, if the typo lands after WRAPPED_DIRS,
  # one named `SHARED_DIR`. Iterating the keywords rather than one of them is
  # what makes the second form reachable; both forms have a rejection case.
  foreach(keyword IN ITEMS SHARED_DIRS WRAPPED_DIRS)
    foreach(entry IN LISTS arg_${keyword})
      if(NOT IS_DIRECTORY "${entry}")
        message(FATAL_ERROR
          "byte-machine: ${keyword} was given '${entry}', which is not an "
          "existing directory. This guard learns of a body only by globbing a "
          "directory, so a path that is not there yields no body and no "
          "violation: the tree it stands for would be reported portable "
          "without ever being looked at. Read it as one of two mistakes -- a "
          "stale path, or a misspelt keyword absorbed into the preceding "
          "keyword's value, which is how a typo reaches this check instead of "
          "the unexpected-argument one above.")
      endif()
    endforeach()
  endforeach()

  # CONFIGURE_DEPENDS asks the build system to re-run the glob, and script mode
  # has no build system: `cmake -P` rejects the keyword outright rather than
  # ignoring it. Requesting it unconditionally would make this function
  # uncallable by its own specification, leaving a hand-run experiment as the
  # only evidence that it stops a build -- which is precisely what the mutation
  # suite exists to replace. Every mode that can honour the keyword still gets
  # it.
  set(glob_depends CONFIGURE_DEPENDS)
  if(CMAKE_SCRIPT_MODE_FILE)
    set(glob_depends "")
  endif()

  set(patterns "")
  foreach(dir IN LISTS arg_SHARED_DIRS arg_WRAPPED_DIRS)
    list(APPEND patterns "${dir}/*.scm")
  endforeach()

  file(GLOB globbed ${glob_depends} ${patterns})
  byte_machine_guard_shared_bodies(bodies ${globbed})

  if(NOT bodies)
    message(FATAL_ERROR
      "byte-machine: the portability guard found no shared bodies to check, "
      "which means its glob is wrong rather than that the sources are "
      "portable. Searched: ${patterns}")
  endif()

  # Deliberately not named `duplicates`: that is the callee's own accumulator
  # name, and CMake resolves an unset local through the *calling* scope, so an
  # out-variable sharing the accumulator's name is correct only for as long as
  # the callee keeps initializing it. The specification's ambient-`duplicates`
  # assertion documents the hazard; this name keeps the shell out of its way.
  byte_machine_guard_duplicate_basenames(repeated_basenames ${bodies})
  if(repeated_basenames)
    message(FATAL_ERROR
      "byte-machine: shared body basenames must be unique across every shared "
      "body directory, but these repeat: ${repeated_basenames}. Chez resolves "
      "includes through source-directories, which is one flat namespace, so "
      "two bodies with one basename collapse into a single file and the build "
      "stays green with one of them never executed again.")
  endif()

  set(wrapped "")
  foreach(dir IN LISTS arg_WRAPPED_DIRS)
    file(GLOB dir_globbed ${glob_depends} "${dir}/*.scm")
    byte_machine_guard_shared_bodies(dir_bodies ${dir_globbed})
    list(APPEND wrapped ${dir_bodies})
  endforeach()

  byte_machine_guard_missing_wrappers(missing ${wrapped})
  if(missing)
    message(FATAL_ERROR
      "byte-machine: every shared test body needs a wrapper for each runtime, "
      "or it is proven on one runtime while looking as though it is proven on "
      "two. Missing (body|wrapper): ${missing}")
  endif()

  list(LENGTH bodies body_count)
  message(STATUS
    "byte-machine portability guard: ${body_count} shared bodies, "
    "unique basenames, every wrapped body paired")
endfunction()
