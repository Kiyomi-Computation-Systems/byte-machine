# byte-machine canonical entry points.
#
# Development and CI both use these targets and the checked-in CMake presets.
# Windows has no make in the base install, so these are a convenience over the
# presets, never the only way in: `cmake --preset dev` and `ctest --preset pr`
# work identically everywhere.
#
# An empty selection is a failure, never a silent pass. That rule lives in the
# test presets themselves (execution.noTestsAction), not only here, or the
# preset path documented above would quietly accept what this path rejects --
# and the whole point of the paragraph above is that the two are equivalent.
# CTEST_FLAGS keeps --no-tests=error as well so an older CTest still refuses.

CMAKE ?= cmake
CTEST ?= ctest
CTEST_FLAGS ?= --output-on-failure --no-tests=error

# Bare 'make' prints the target list rather than building; 'make all' still builds.
.DEFAULT_GOAL := help

.PHONY: all help doctor configure build dev test test-all test-mutation prod clean

all: build   ## build the development preset

# 'help' prints every target that carries a '## ' description by scanning this
# Makefile itself, so the descriptions live beside the targets they document
# and cannot drift out of sync with them: add a target with a '## ' note and
# it appears here automatically.
help:   ## list these targets (shown when you run a bare 'make')
	@echo "byte-machine make targets:"
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z][a-zA-Z_-]*:.*## / {printf "  %-10s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "If discovery cannot find a runtime, point it at one explicitly:"
	@echo "  cmake --preset dev -DBYTE_MACHINE_CHEZ_EXECUTABLE=/absolute/path/to/scheme"

# Configure is where discovery runs and where every toolchain diagnostic is
# emitted, so 'doctor' is just a configure whose output is the point.
doctor:   ## report the discovered Chez toolchain, then stop
	$(CMAKE) --preset dev

configure:   ## configure the development preset without building
	$(CMAKE) --preset dev

build: configure   ## configure and build the development preset
	$(CMAKE) --build --preset dev

dev: build   ## build, then run the harness and build-layer self-tests
	$(CTEST) --preset harness $(CTEST_FLAGS)

test: build   ## build, then run the pull-request selection
	$(CTEST) --preset pr $(CTEST_FLAGS)

test-all: build   ## build, then run the complete selection
	$(CTEST) --preset release $(CTEST_FLAGS)

# The mutation lane is one ctest entry that runs ~5 min, and ctest buffers a
# single test's output to the end -- under 'test-all' it sits silent, which is
# hard to tell apart from a hang. This target runs just that lane with -V, which
# streams its per-pass progress live (each 'pass N: K mutations against ...' and
# '[i/K] caught ...' line as it happens).
test-mutation: build   ## build, then run only the mutation lane, streaming live progress (~5 min)
	$(CTEST) --preset release -V -R scheme-mutation --no-tests=error

prod:   ## configure and build the release preset
	$(CMAKE) --preset prod
	$(CMAKE) --build --preset prod

clean:   ## remove all build trees
	$(CMAKE) -E rm -rf build
