# byte-machine canonical entry points.
#
# Development and CI both use these targets and the checked-in CMake presets.
# Windows has no make in the base install, so these are a convenience over the
# presets, never the only way in: `cmake --preset dev` and `ctest --preset pr`
# work identically everywhere (parent plan section 24.1).
#
# --no-tests=error is passed here rather than in the presets because CTest has
# no preset field for it. An empty selection is a failure, never a silent pass.

CMAKE ?= cmake
CTEST ?= ctest
CTEST_FLAGS ?= --output-on-failure --no-tests=error

.PHONY: all help doctor configure build dev test test-all prod clean

all: build

help:
	@echo "byte-machine make targets:"
	@echo "  doctor    report the discovered Chez and Gambit toolchains, then stop"
	@echo "  build     configure and build the development preset"
	@echo "  dev       build, then run the harness and build-layer self-tests"
	@echo "  test      build, then run the pull-request selection"
	@echo "  test-all  build, then run the complete selection"
	@echo "  prod      configure and build the release preset"
	@echo "  clean     remove all build trees"
	@echo ""
	@echo "If discovery cannot find a runtime, point it at one explicitly:"
	@echo "  cmake --preset dev -DBYTE_MACHINE_CHEZ_EXECUTABLE=/absolute/path/to/scheme"
	@echo "  cmake --preset dev -DBYTE_MACHINE_GAMBIT_EXECUTABLE=/absolute/path/to/gsi"

# Configure is where discovery runs and where every toolchain diagnostic is
# emitted, so 'doctor' is just a configure whose output is the point.
doctor:
	$(CMAKE) --preset dev

configure:
	$(CMAKE) --preset dev

build: configure
	$(CMAKE) --build --preset dev

dev: build
	$(CTEST) --preset harness $(CTEST_FLAGS)

test: build
	$(CTEST) --preset pr $(CTEST_FLAGS)

test-all: build
	$(CTEST) --preset release $(CTEST_FLAGS)

prod:
	$(CMAKE) --preset prod
	$(CMAKE) --build --preset prod

clean:
	$(CMAKE) -E rm -rf build
