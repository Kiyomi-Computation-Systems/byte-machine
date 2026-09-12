# Milestone 9 Slice ④ — examples and the documentation set

**Status: implemented 2026-09-12. Green in both Chez modes (release suite 144/144).**

Slice ④ of Milestone 9 (design §9). No `src/` change (all work under `docs/`,
`examples/`, `test/`, `README.org`, `.gitignore`).

## What shipped

1. **The example** — `examples/generate-simple-machine/` (`generate.sps` +
   `README.md`). A standalone program that constructs a one-byte parser through
   **only** the public `(byte-machine graph)` API (§27:1703), compiles it
   (verification mandatory and unbypassable), emits the generated library, loads
   it, and feeds it bytes — printing each step. Run and verified locally:

   ```
   chez --libdirs src --program examples/generate-simple-machine/generate.sps
   ```

   It emits `example-simple.generated.sls` (now git-ignored, `*.generated.sls`).
   The **clean-checkout run** (a fresh clone, §25:1663) is Slice ⑤'s step, which a
   test lane cannot witness (§3.2 item 1) — so `§26:1682` stays `open` with Slice
   ⑤ as receiver.

2. **`§27`'s nine missing references** — now all eleven `§27` deliverables exist:
   - `source-ir-and-builder.md` (§27:1692) — every `(byte-machine graph)`
     constructor and node kind.
   - `transition-and-cursor-semantics.md` (§27:1693) — edge modes, cursor,
     offsets, statuses, position kinds.
   - `field-and-overflow.md` (§27:1695) — the seven field operations, seven
     predicates, accumulation, counted consumption, overflow edges.
   - `verifier-diagnostic-catalog.md` (§27:1696) — the thirty codes, **derived**:
     `diagnostic-census-tests.sps` now asserts the catalog's code set equals the
     census computed from `verify.sls`, so the catalog cannot become a
     thirty-first place for the code set to drift (design §9 oracle).
   - `generated-code-integration-chez.md` (§27:1697, §26:1681) — the generation
     flow and the dependency-boundary rule (generated parsers import only
     `(byte-machine runtime)`).
   - `grammar-author-testing-guide.md` (§27:1698) — the harness API and lane
     registration.
   - `benchmark-methodology-and-baseline.md` (§27:1699) — Slice ③'s runner and
     recorded baseline, written up.
   - `portability-matrix.md` (§27:1700) — the Tier 1 matrix as amended for v0.1
     (macOS arm64 local; the rest deferred, decision 0041), the machine-type
     mappings, the pinned Chez 10.4.1.
   - The **README quick start** (§27:1691) — a `Quick start` section that builds a
     *machine*, not the repository (§3.2's gap).

3. **Ledger updates.** `§26:1671`, `:1681`, `:1683` → `met` (references and quick
   start landed); `§26:1682` witness updated (example ships, clean-checkout run is
   Slice ⑤). Every `§27` row now `exists? #t`. The `release-ledger` lane asserts
   each reference file exists and the README carries a quick start; the partition
   is now **11 met, 0 partly, 4 open**.

## Exit (design §9)

- `§26:1671`, `:1681`, `:1683` `met`; `§27` complete (11 of 11) — confirmed by the
  ledger lane.
- The verifier catalog is derived and checked against the census, not
  hand-transcribed — confirmed (the census lane fails if they disagree).
- **`src/` diff empty** — confirmed.

## Notes

- **Six of the eight reference documents were drafted by parallel subagents**,
  each pointed at specific source files and required to ground every claim; I
  reviewed each, and the field/overflow draft **corrected** an error in my own
  builder-reference draft (the field operation set is seven, not four — the four I
  had listed are the *infallible* subset). No document carries a `src/` line-number
  citation (they cite by library and identifier name, per design §9's hazard rule);
  the plan `§section:line` citations were spot-checked against the plan.
- **The example is not a ctest lane.** It is a documented standalone program; its
  clean-checkout execution is Slice ⑤'s performed step (design §9, §10).
