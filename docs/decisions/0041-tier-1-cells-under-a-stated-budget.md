# 0041: Tier 1 cells turn on one at a time under a stated budget — and this milestone's budget is zero

Date: 2026-09-12
Status: accepted
Milestone: 9, Gate 0 (milestone-9-design.md §4.4, §4.9 item 1)

## Context

Decided against `main` at `c8e5fb6`; `src/` byte-identical to `62671b2`.

`§7.3:203` is unusually firm (quoted from `docs/plans/byte-machine-implementation-plan.md:203`):
"Every Tier 1 cell is a real release gate. If an upstream toolchain or runner makes one infeasible,
the tier must be changed through an explicit update to this plan before release; it cannot be
silently waived in release notes."

Against that stands the budget (design §2): a **private** repository, billed minutes, macOS at ×10,
a month's minutes already exhausted once, and `#88`'s two-run cache verification unperformed since
2026-09-07. `§26:1678` wants eight cells.

**The owner set this milestone's budget on 2026-09-12: zero.** No CI runs — the billed minutes are
not available. Under this decision's own procedure, that makes *every* Tier 1 cell a cell that
cannot be afforded, and therefore a plan amendment, not a silent waiver.

## Decision

**1. The procedure — adopted for whenever cells can run.** Cells turn on in **ascending cost
order**: Linux amd64 (running, and the cell that discharges `#88`), Windows amd64 (×2, prebuilt
runtime, no source build), Linux arm64 (×1 where the runner label exists on this plan — verified
before it is relied on), macOS arm64 (×10, the platform every slice is already measured on locally).
Each cell's **first run is a single `workflow_dispatch`**, priced and recorded, before it joins the
`push`/`ci`-label paths. A matrix that fans out on every push is not a decision a scarce budget can
make one cell at a time.

**2. A cell that cannot run is an amendment to `§7.3:195`** — written as a dated disposition in the
parent plan, *before* the release, and reflected in the ledger's row. **Never a sentence in release
notes.** This is `§7.3:203` honoured, not evaded: the tier is changed by an explicit, dated plan
update, which is exactly what the clause demands. *Rejected, with the failure it would cause*:
letting an unrun cell pass as "verified" in the ledger, or noting the gap only in `CHANGELOG.md`,
is the silent waiver the clause names.

**3. This milestone's amendment (2026-09-12).** With the budget at zero, **no Tier 1 CI cell runs in
Milestone 9, and Slice ② (Tier 1 CI) is not executed.** The `§7.3:195` tier is amended for v0.1:

- **macOS arm64 — verified locally**, on the platform every slice is already measured on. This is
  the release's one covered cell.
- **Linux amd64, Windows amd64, Linux arm64 — deferred past v0.1** for lack of billed CI minutes.

Because Milestone 9 is the **final** milestone, this is not a carry-forward to a later milestone —
there is none. It is v0.1's **standing** platform disposition, recorded in the parent plan (Slice ⑤)
and the release ledger (Slice ⓪).

**4. `#88` is dispositioned, not waived.** Its two-run Chez-cache verification (cold build, then warm
restore) needs a runner this milestone will not pay for. The ledger's `§26:1678` row is
`open` → `amended`, naming this decision and the dated parent-plan disposition as its receiver; the
`§26:1677` cross-cell row (decision [0039]) records one-cell coverage for the same reason.

## Consequences

- **Slice ② is struck from Milestone 9.** Its scope had three parts, each given a receiver here so
  none is AGENTS.md's "deferral with no receiver" — the more acute because no later milestone can
  receive them:
  - the Tier 1 matrix → the `§7.3:195` amendment above, recorded in the ledger and parent plan;
  - `#88` → item 4, `amended` in the ledger;
  - `§30` questions 2 and 3 (per-platform commands, Windows search paths) → answered *on paper* by
    Slice ①'s dry Windows audit (which costs zero minutes) and recorded in `§27:1700`'s portability
    matrix by Slice ④, marked "from audit, not from a runner".
- **Handed to Slice ①**: the dry Windows audit ships unchanged — every question the Windows cell
  would answer, written down — so whoever funds CI after v0.1 turns cells on against a written
  baseline, not a blank slate.
- **Handed to Slice ⓪ / the ledger**: `§26:1677` = "mechanism complete; one cell (local)";
  `§26:1678` = `amended` (macOS arm64 local, three cells deferred past v0.1); both citing this
  decision and the parent-plan disposition, checked as `judgement`/`amended` rows.
- **Handed to Slice ⑤**: the parent-plan dated amendment to `§7.3:195`; `README.org` and
  `CHANGELOG.md` stating v0.1's platform coverage plainly (recorded, not waived); the five
  status-surface sweep.

[0039]: ./0039-cross-cell-equality-through-committed-goldens.md
