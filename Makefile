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

# The docs site is rendered with chez-cmark-gfm, which is not a dependency of
# the library: name a checkout with CMARK_GFM_ROOT. These targets run Chez
# directly rather than through CMake, so the site builds on a distribution's
# Chez as well as on the version the library's own build requires. SITE_REF
# is the git ref that ../ links in docs/ are pinned to on GitHub.
CHEZ ?= chez
AKKU ?= akku
SITE_REF ?= main
SITE_LIBDIRS = .:test/site:test/support/harness:$(CMARK_GFM_ROOT)/src
REFERENCE_LIBDIRS = .:test/site:test/support/harness

# Bare 'make' prints the target list rather than building; 'make all' still builds.
.DEFAULT_GOAL := help

.PHONY: all help doctor configure build dev test test-all test-mutation check-test-partition prod clean site check-site check-reference cmark-gfm-root check-akku

all: build   ## build the development preset

# 'help' prints every target that carries a '## ' description by scanning this
# Makefile itself, so the descriptions live beside the targets they document
# and cannot drift out of sync with them: add a target with a '## ' note and
# it appears here automatically.
help:   ## list these targets (shown when you run a bare 'make')
	@echo "byte-machine make targets:"
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z][a-zA-Z_-]*:.*## / {printf "  %-16s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
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

# The Scheme mutation suite is one ctest entry that runs ~5 min, and ctest
# buffers a single test's output to the end -- under 'test-all' it sits silent,
# which is hard to tell apart from a hang. This target runs the `mutation`
# preset with -V, which streams its per-pass progress live (each
# 'pass N: K mutations against ...' and '[i/K] caught ...' line as it happens).
test-mutation: build   ## build, then run only the mutation suites, streaming live progress (~5 min)
	$(CTEST) --preset mutation -V $(CTEST_FLAGS)

# CI runs `pr` and then `mutation` in place of `release`; this checks that the
# two together select exactly what `release` does.
check-test-partition: configure   ## check the pr and mutation presets together select exactly release
	@CTEST="$(CTEST)" scripts/check-test-partition

prod:   ## configure and build the release preset
	$(CMAKE) --preset prod
	$(CMAKE) --build --preset prod

clean:   ## remove all build trees, the docs site included
	$(CMAKE) -E rm -rf build

# Each site target first checks CMARK_GFM_ROOT names a chez-cmark-gfm checkout,
# so a missing path fails with a sentence rather than a library-not-found.
cmark-gfm-root:
	@test -n "$(CMARK_GFM_ROOT)" || { echo "set CMARK_GFM_ROOT=/path/to/chez-cmark-gfm" >&2; exit 2; }
	@test -f "$(CMARK_GFM_ROOT)/src/cmark/gfm.sls" || { echo "$(CMARK_GFM_ROOT) is not a chez-cmark-gfm checkout" >&2; exit 2; }

# docs/*.md rendered to build/site/ through chez-cmark-gfm; docs/README.md
# becomes the home page, index.html.
site: cmark-gfm-root   ## render docs/ into build/site/ (needs CMARK_GFM_ROOT)
	@mkdir -p build/site
	@CHEZSCHEMELIBDIRS=$(SITE_LIBDIRS) SITE_REF="$(SITE_REF)" \
	  $(CHEZ) --program build-site.sps
	@cp site/style.css build/site/style.css
	@echo "site: build/site ready (open build/site/index.html)"

# The reference checker's own suite, then docs/reference.md against the export
# clause of every library in src/byte-machine/. Pure: needs no chez-cmark-gfm.
check-reference:   ## check docs/reference.md documents exactly the public exports
	@CHEZSCHEMELIBDIRS=$(REFERENCE_LIBDIRS) $(CHEZ) --program test/site/test-reference.sps
	@CHEZSCHEMELIBDIRS=$(REFERENCE_LIBDIRS) $(CHEZ) --program test/site/reference-check.sps

# The generator's own suites first, then the real site checked in memory: the
# nav lists exactly docs/*.md, every link and anchor resolves, no .md link
# leaks into the HTML, and preformatted code is never reflowed.
check-site: cmark-gfm-root check-reference   ## test the site generator, then check docs/ with it
	@CHEZSCHEMELIBDIRS=$(SITE_LIBDIRS) $(CHEZ) --program test/site/test-site.sps
	@CHEZSCHEMELIBDIRS=$(SITE_LIBDIRS) $(CHEZ) --program test/site/test-site-render.sps
	@CHEZSCHEMELIBDIRS=$(SITE_LIBDIRS) SITE_REF="$(SITE_REF)" \
	  $(CHEZ) --program test/site/site-check.sps

# What Akku installs into a consumer's .akku/lib: install this package as a
# dependency of a throwaway project and require exactly src/'s libraries.
# .akkuignore keeps site/ (the docs generator) and examples/ out. Needs akku.
check-akku:   ## install as an Akku dependency and check exactly src/'s libraries land
	@AKKU="$(AKKU)" CHEZ="$(CHEZ)" scripts/check-akku
