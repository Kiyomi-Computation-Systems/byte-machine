;;; The v0.1 release ledger: §26's fifteen release criteria and §27's eleven
;;; documentation deliverables, carried as DATA a lane reads, not prose a human
;;; audits (decision 0038). Milestone 9 Slice ⓪ ships it FIRST, before any
;;; criterion is worked, so the milestone establishes which are already true
;;; before spending effort on the rest — the shape decision 0034 gave Milestone
;;; 8's error table, applied to the release exit (`§25:1665`).
;;;
;;; A §26 row is (ref text state kind witness receiver):
;;;   ref      -- "§26:NNNN", a label. The row is KEYED ON `text`, never the line
;;;               number: line numbers move (Milestone 8 learned this at
;;;               §21.7:1209), the criterion's words do not.
;;;   text     -- the criterion, VERBATIM from `§26` (parent plan lines
;;;               1671-1685), minus the "- " bullet prefix and the trailing ";".
;;;               The totality lane re-reads `§26` from the plan and set-compares
;;;               against these strings, so a drift in either side fails by name.
;;;   state    -- `met`, `partly`, `open`, or `amended`. `amended` is a v0.1
;;;               disposition (decision 0041): a criterion the release ships NOT
;;;               fully met, with an explicit dated `§7.3:195` amendment and a
;;;               release-note entry — never a silent waiver. `§26:1680` is `open`
;;;               (at Slice ⓪) although the
;;;               property is TRUE at `62671b2` (measured 0.0 B/byte, design
;;;               §3.3 P2): the distinction between a property holding and a
;;;               suite KNOWING it holds is the whole reason the ledger exists,
;;;               and a row marked `met` on this document's say-so would be the
;;;               "sentinel computed from the test's own expectation" defect.
;;;   kind     -- `mechanical` (the lane executes the witness: a file exists, a
;;;               lane is registered, a `git ls-files` result is empty, a
;;;               directory holds only `.gitkeep`) or `judgement` (the witness is
;;;               a close-note paragraph the lane records but does not pretend to
;;;               check — a ledger that "checked" a judgement by recomputing the
;;;               expectation it was handed asserts nothing).
;;;   witness  -- what establishes the row: the check descriptor for a mechanical
;;;               row, the standing paragraph for a judgement row.
;;;   receiver -- the slices that move the row (symbols), or `()` for `met`.
;;;
;;; A §27 row is (ref text exists? receiver): a deliverable exists as a committed
;;; document, or it does not and a slice owns it. Two of eleven exist at Slice ⓪
;;; (`:1694` callback/span lifetime; `:1701` the changelog, pending its `0.1.0`
;;; entry).
;;;
;;; TWO TOTALITY ROWS, checked by the lane, self-ratcheting (no mutation entry,
;;; as Milestone 8 Slice ⓪'s table earned none): the criterion set against
;;; `§26`'s fifteen and the deliverable set against `§27`'s eleven. Adding or
;;; dropping a criterion in either the plan or this ledger fails BY NAME.
;;;
;;; The design's §3.1 PROSE summary ("Nine met, three partly, one
;;; true-but-unasserted, five open") sums to eighteen and its Slice ⓪ exit line
;;; ("open rows are the five plus three partly") disagrees again; its TABLE and
;;; Appendix are the consistent, authoritative disposition and are what this
;;; ledger encodes at Slice ⓪: 6 `met`, 3 `partly`, 6 `open`. (design Appendix,
;;; annotated 2026-09-12.) Slices ①–⑤ move rows as they land; the v0.1 CLOSE
;;; state is 13 `met`, 2 `amended` (§26:1677 and :1678, decision 0041), 0 `open`.
;;;
;;; This library lives with the fixture harness, no `src/` library imports it,
;;; and it carries no name into the `(byte-machine ...)` prefix a public importer
;;; would use — Slice ⑤'s leak sweep asserts both.
(library (byte-machine test release-ledger)
  (export release-criteria release-deliverables
          criterion-ref criterion-text criterion-state criterion-kind
          criterion-witness criterion-receiver
          deliverable-ref deliverable-text deliverable-exists? deliverable-receiver
          release-version release-version-surfaces release-version-export?)
  (import (rnrs))

  ;; §26 — the fifteen v0.1 release criteria (parent plan §26, lines 1671-1685).
  ;; `text` is verbatim minus "- " and the trailing ";".
  (define release-criteria
    '(("§26:1671"
       "every approved IR node has documented semantics"
       met mechanical
       ".reference/source-ir-and-builder.md documents every node kind and constructor; semantics in parent §10.6 (§27:1692)"
       ())
      ("§26:1672"
       "mandatory verification is complete and emission cannot bypass it through the public API"
       met judgement
       "render-machine on an unverified value raises invalid-shape / \"not a machine\"; Milestone 7 Slice ④'s catalogue"
       ())
      ("§26:1673"
       "interpreter/generated differential tests pass"
       met mechanical
       "the differential lanes are registered (byte-machine.differential.*)"
       ())
      ("§26:1674"
       "lifecycle, callbacks, spans, fields, offsets, errors, EOF, and counted consumption meet this plan"
       met judgement
       "Milestones 2-6 close notes"
       ())
      ("§26:1675"
       "the private HTTP fixture meets its required behavior"
       met judgement
       "Milestone 8 close; §25:1646 dispositioned in the Slice ⑤ note"
       ())
      ("§26:1676"
       "representative fixture inputs pass every split point"
       met judgement
       "Milestone 8 Slice ⑤; §4.9 item 3 (every split) declined by measurement, seeded subset stated as the fallback"
       ())
      ("§26:1677"
       "deterministic generation passes across supported platform cells"
       amended judgement
       "AMENDED for v0.1 (decision 0041, §7.3:195 dated disposition, release notes): the MECHANISM is complete — six committed determinism goldens compared on every run — but cross-CELL coverage is one cell (macOS arm64, local); the other cells are deferred past v0.1 for lack of CI. Recorded, not waived"
       ())
      ("§26:1678"
       "every Tier 1 matrix cell passes its required source, generation, AOT-compilation, and execution checks"
       amended judgement
       "AMENDED for v0.1 (decision 0041, §7.3:195 dated disposition, release notes): macOS arm64 verified locally; Linux amd64, Windows amd64, Linux arm64 deferred past v0.1 for lack of billed CI minutes; #88 dispositioned not waived. Recorded, not waived"
       ())
      ("§26:1679"
       "compiled benchmark baselines are recorded without speculative optimization"
       met mechanical
       "bench/runner/benchmark.sps produces the committed baseline bench/fixtures/baseline-tarm64osx.sls with the §23.1 fields (canonical bytes, seeds, harness version, exact command, raw samples, summary, required-vs-unavailable, twelve §23.2 workloads); recorded, no perf gate (§23.1). §23.3's admission rule is now MET rather than unmet: decision 0048 derives material improvement and significant regression from the observed dispersion, and decisions 0049, 0050, 0051 and 0052 are admitted against them, each with three or more admissible workloads improving and none regressing past the significance bar. Decision 0053 is the first that does NOT meet rule 2 on this instrument -- 22% on one admissible workload and flat on four -- and says so rather than adding workloads to reach three: the bench machine is 217 states with no keyword table, so every workload but the byte-at-a-time one crosses the feed entry once per message. The baseline is re-recorded at sixteen thousand iterations over nine rounds, because at the hundred it used to carry ten of the twelve medians sat inside the millisecond clock, and because at five rounds byte-at-a-time-fragmentation dispersed 25% around its median and reported a regression twice the size of the one nine rounds shows"
       ())
      ("§26:1680"
       "generated per-byte paths contain no deliberate list/vector/string/result construction, and fixnum-sized allocation measurements are recorded with callbacks disabled"
       met mechanical
       "byte-machine.unit.allocation-audit asserts the generated per-byte slope is zero (alloc(short)=alloc(long)) against a live nonzero control, both executors measured, callbacks disabled with the callback-bound figure recorded beside it (decision 0040). A SECOND slope, per header, with its own live control (decision 0052): the per-byte pair holds the header count fixed, so 128 B/header -- four consed callback outcomes -- sat in the per-message intercept that 0040 item 1 never divides by anything, and read as green here for six milestones. Both slopes are now zero and both are asserted in both wordings. A THIRD dimension, bytes matched per keyword (decision 0054, issue #139): the runtime keyword walk every keyword-table state calls copied its matched prefix on every byte (k²/2 pairs for a k-byte match), which neither slope could see because the HTTP fixture has no keyword table and both hold a header name's match length fixed. The walk now compares each keyword in place, in one pass, and allocates only its answer, and the lane asserts that shape for every k from 0 to 17 against a live control (the pre-fix walk)"
       ())
      ("§26:1681"
       "public libraries and generated-runtime dependency boundaries are documented"
       met mechanical
       ".reference/generated-code-integration-chez.md documents the boundary — generated parsers import only (byte-machine runtime) — with parent §7.2's diagram (§27:1697)"
       ())
      ("§26:1682"
       "examples generate, compile, and run from a clean checkout"
       met judgement
       "examples/generate-simple-machine/ ships and uses only the public API (§27:1703); the CLEAN-CHECKOUT run — a fresh clone, the documented command, generating/compiling/running — was PERFORMED 2026-09-12 (§25:1663), its output recorded in the Slice ⑤ close. A test lane cannot witness a fresh clone (§3.2 item 1), so this is a recorded judgement"
       ())
      ("§26:1683"
       "`README.org` explains scope and quick start"
       met mechanical
       "the intro explains scope; a Quick start section builds a machine (not the repository) and links the reference set. (README's status paragraph and Documentation list are refreshed by Slice ⑤'s status-surface sweep, §3.2 item 4.)"
       ())
      ("§26:1684"
       "`CHANGELOG.md` contains the `0.1.0` entry"
       met mechanical
       "CHANGELOG.md carries the [0.1.0] - 2026-09-12 section with the release summary and the known-open list"
       ())
      ("§26:1685"
       "no native build artifacts or unrelated HTTP/server code are committed"
       met mechanical
       "git ls-files matching the native-artifact pattern is empty; every HTTP path is under test/ or docs/, and byte-machine.unit.http-leak asserts the fixture is not re-exported"
       ())))

  ;; §27 — the eleven documentation deliverables (parent plan §27, 1691-1701).
  (define release-deliverables
    '(("§27:1691" "concise README quick start"                       #t ())
      ("§27:1692" "source IR and builder reference"                  #t ())
      ("§27:1693" "transition/cursor semantics reference"            #t ())
      ("§27:1694" "callback/span lifetime reference"                 #t ())
      ("§27:1695" "field and overflow reference"                     #t ())
      ("§27:1696" "verifier diagnostic catalog"                      #t ())
      ("§27:1697" "generated-code integration guide for Chez"        #t ())
      ("§27:1698" "grammar-author testing guide"                     #t ())
      ("§27:1699" "benchmark methodology and baseline report"        #t ())
      ("§27:1700" "portability matrix and pinned runtime versions"   #t ())
      ("§27:1701" "changelog"                                        #t (five))))

  ;; §4.5 — the version surface. The CURRENT release string has ONE owner (the
  ;; value here) and a mirror rule: every surface below carries it. Milestone 14
  ;; (the emitted dispatches stop being linear scans, decisions 0048-0053) bumps
  ;; it to `0.6.0`. It adds NO public API at all — no node kind, no graph
  ;; constructor, no diagnostic — so by the reading below it would be a patch;
  ;; it is a MINOR because the generated-runtime ABI breaks (8 -> 9) and two
  ;; runtime bindings generated code calls are retired to tombstones, which is
  ;; the same call M11 and M13 made for their own ABI bumps. Milestone 13
  ;; (a parser can start in a mode, decision 0047) bumped it to `0.5.0`; the
  ;; `§26`/`§27` census above is UNCHANGED — those are the release exit criteria
  ;; (the append rule freezes them, a settable field adds no criterion row, and
  ;; every one still holds, the two amended still the CI-blocked pair), so the
  ;; ledger keeps checking them while this value tracks the release they were met
  ;; for. The `(byte-machine version)` export stays DECLINED (§4.9 item 3): no
  ;; public library exports a `version` NAME, so `release-version-export?` is #f
  ;; and the leak sweep asserts as much. (Milestone 13 DID add public API — the
  ;; optional `settable?` on `make-uint-field` with `uint-field-settable?`, and
  ;; the optional `field-initials` argument to `make-parser` — but that is a
  ;; semver-minor's added optional API, not a version-string export.)
  ;; `current-abi-version` (now 9, runtime.sls) is the generated-runtime ABI — a
  ;; different thing with a different lifecycle — and is deliberately NOT this
  ;; value. It moved 7->8 at v0.5.0 for the settable table (an OPTIONAL fourth
  ;; payload member the generated make-parser range-checks an override against)
  ;; and 8->9 at v0.6.0 for decision 0052, where the callback seam changed what
  ;; it ANSWERS — the outcome object rather than a list tagged with the
  ;; outcome's name — so an ABI-8 parser would decode every callback wrong and
  ;; is refused at construction. The two lifecycles have now diverged twice in
  ;; the same direction and once in the other: an ABI bump has never been a
  ;; major here, and v0.5.0's minor carried no ABI-breaking change at all.
  ;; THIS COMMENT IS WHY THE VALUE BELOW IS NOT THE ONLY THING TO MOVE AT A
  ;; RELEASE: it read `now 8` for the whole of Milestone 14, through an ABI bump
  ;; the lane could not catch because prose is not a checked value.
  (define release-version "0.6.0")
  (define release-version-export? #f)
  (define release-version-surfaces
    '("CHANGELOG.md 0.6.0 entry (§26:1684)"
      "README.org status paragraph"
      "the parent plan's dated disposition"
      ;; NOT `milestone-14-design.md`: this milestone has no design document,
      ;; because it was chosen a slice at a time from the previous slice's
      ;; measurement. The close record carries the status header instead, and
      ;; says why it is a close rather than a design.
      "the milestone-14-close.md status header"
      "the git tag"))

  ;; --- accessors -----------------------------------------------------------
  (define (criterion-ref r)      (list-ref r 0))
  (define (criterion-text r)     (list-ref r 1))
  (define (criterion-state r)    (list-ref r 2))
  (define (criterion-kind r)     (list-ref r 3))
  (define (criterion-witness r)  (list-ref r 4))
  (define (criterion-receiver r) (list-ref r 5))
  (define (deliverable-ref d)     (list-ref d 0))
  (define (deliverable-text d)    (list-ref d 1))
  (define (deliverable-exists? d) (list-ref d 2))
  (define (deliverable-receiver d)(list-ref d 3)))
