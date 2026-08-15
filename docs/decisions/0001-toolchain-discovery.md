# 0001: Toolchain discovery interrogates candidates instead of trusting names

Date: 2026-08-15
Status: accepted
Milestone: 0, slice 1

## Context

byte-machine has to find a Chez and a Gambit on hosts it does not control.
Neither runtime has a portable binary name, and on this project's own
development host one of the names is actively wrong:

- Chez is installed by Homebrew as `chez`, by upstream as `scheme`, and by some
  distributions as `chezscheme`. A `scheme` on `PATH` may be an entirely
  unrelated implementation.
- Ghostscript installs a console binary called `gsc` — the same name as Gambit's
  compiler. On this host, `gsc` on `PATH` **is** Ghostscript, and Gambit's
  Homebrew keg is deliberately left unlinked because of the collision, so `gsi`
  is not on `PATH` at all.
- Gambit's `gsc` shells out to a C compiler whose name is fixed when Gambit is
  built. The Homebrew build here hard-codes `gcc-16` in `gambuild-C`.

Exit status cannot resolve the Ghostscript case. Handed a Scheme file,
Ghostscript's `gsc` either prints its banner and exits 0, or waits for input on
standard input and never returns.

## Decision

Discovery never trusts a filename. Every candidate is interrogated by running a
probe script that prints `key=value` lines, and identity is decided on the
*content* of that output.

1. **Chez** is searched for as `scheme`, `chez`, `chezscheme`, then probed. It is
   rejected unless the banner contains `Chez Scheme`, and rejected again if it
   contains `Petite` — Petite has no `compile-program` and cannot run the
   ahead-of-time lane, so a Petite that passed discovery would produce a suite
   covering one fewer execution mode than it claims.
2. **Gambit** is searched for as `gsi` only, never `gsc`, and the compiler is
   derived positionally from the interpreter's own directory. The derived path
   is then interrogated exactly as the interpreter was, and the two must agree on
   version, target triple, **and** build stamp.
3. Both probes carry a 20-second timeout, because a binary that waits for input
   is one of the failure modes.
4. Version pins are **floors**, not equalities, since the parent plan's Tier 2
   matrix explicitly includes additional implementation versions.

## What this rules out

- Requiring **threaded** Chez. The sibling protium project does require it,
  because libuv gives it a loop-owner thread model. byte-machine has no threads
  anywhere in its design, so gating on it here would be a copied requirement
  rather than a real one, and would reject a working runtime. The flag is
  probed and recorded as portability evidence; it is not a gate.
- Deriving anything from `gsc` found on `PATH`.
- Treating a zero exit status as proof of identity.

## Evidence

Measured on Darwin 25.5.0 arm64, 2026-08-15:

- Chez 10.4.1 at `/opt/homebrew/bin/chez`; Gambit 4.9.8 at
  `/opt/homebrew/opt/gambit-scheme/bin/{gsi,gsc}`, keg unlinked.
- Discovery configured cleanly against the real installation, deriving `gsc`
  from `gsi`'s directory.
- Discovery was pointed at a directory whose `gsi` and `gsc` were both symlinks
  to Ghostscript's binary — the state a host would be in if Gambit's keg *were*
  linked — and refused with a nonzero exit and the Ghostscript-specific
  diagnostic.
- Discovery was run with a non-Chez `scheme` earlier on PATH than a working
  `chez`, and selected the `chez`. With all three candidate names unusable — a
  non-Chez `scheme`, a `chez` that exits nonzero, and a `chezscheme` that aborts
  — it failed once, naming each candidate and its own reason.
- The functional core of each module is specified under `cmake -P` with no
  runtime present, and `test/support/cmake/MutationSuite.cmake` breaks each
  decision in turn on a staged copy and requires the owning specification to
  notice. It runs in CI as
  `byte-machine.harness.cmake-mutation.cmake.direct`.

## Consequences

- Version floors are set to what has actually been verified (Chez 10.4.1,
  Gambit 4.9.8) rather than to a guess. Parent plan section 30 question 1 asks
  what the real floors are; lowering these pins is that question's answer and
  needs CI evidence from the older release.
- One mutation is knowingly uncaught, and is declared as such in the suite with
  `EXPECT_SURVIVES`. CMake 4.3.3 clears `CMAKE_MATCH_<n>` when a match fails, so
  on this version the stale-capture hazard the probe accessor guards against
  cannot be provoked. The guard stays because the declared CMake floor is 3.26,
  where older behaviour is in range. Declaring it rather than omitting it means
  the suite fails if it ever *starts* being caught, which is the signal that this
  paragraph has gone stale.
- **The 3.26 floor is declared, not exercised.** Only CMake 4.3.3 has ever run
  this build, and the paragraph above depends on 3.26-era behaviour differing.
  Until CI runs the declared floor, that is an argument, not evidence. Raising
  the floor to a version known to clear match variables would let the guard and
  its mutation be deleted outright.
- The mutation suite is the reason this record can be trusted at all. An earlier
  revision of this file cited a hand-run mutation check as evidence; that check
  lived only in a terminal, could not be rerun, and could not fail when the code
  changed. It had also missed its most important case, because it mutated only
  the modules and never the assertion helper every specification depends on --
  breaking that helper left all four specifications green.
- A `no-scheme` preset configures and runs the CMake-layer specifications with
  neither runtime installed, so build-layer logic stays testable in environments
  that have no Scheme at all.
