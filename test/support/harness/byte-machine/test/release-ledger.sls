;;; The release ledger: the fifteen release criteria and the eleven
;;; documentation deliverables, carried as DATA a lane reads, not prose a human
;;; audits.
;;;
;;; A criterion row is (ref text state kind witness receiver):
;;;   ref      -- "§26:NNNN", a label. The row is KEYED ON `text`, never the line
;;;               number: line numbers move, the criterion's words do not.
;;;   text     -- the criterion, VERBATIM from the release-criteria list, minus
;;;               the "- " bullet prefix and the trailing ";". The totality lane
;;;               re-reads that list and set-compares against these strings, so a
;;;               drift in either side fails by name.
;;;   state    -- `met`, `partly`, `open`, or `amended`. `amended` is a criterion
;;;               the release ships NOT fully met, with an explicit dated
;;;               amendment and a release-note entry — never a silent waiver. A
;;;               property that holds but that no lane asserts is `open`, not
;;;               `met`: the distinction between a property holding and a suite
;;;               KNOWING it holds is the whole reason the ledger exists, and a
;;;               row marked `met` on this document's say-so would be a sentinel
;;;               computed from the test's own expectation.
;;;   kind     -- `mechanical` (the lane executes the witness: a file exists, a
;;;               lane is registered, a `git ls-files` result is empty, a
;;;               directory holds only `.gitkeep`) or `judgement` (the witness is
;;;               a close-note paragraph the lane records but does not pretend to
;;;               check — a ledger that "checked" a judgement by recomputing the
;;;               expectation it was handed asserts nothing).
;;;   witness  -- what establishes the row: the check descriptor for a mechanical
;;;               row, the standing paragraph for a judgement row.
;;;   receiver -- the owners that move the row (symbols), or `()` for `met`.
;;;
;;; A deliverable row is (ref text exists? receiver): a deliverable exists as a
;;; committed document, or it does not and a receiver owns it.
;;;
;;; TWO TOTALITY ROWS, checked by the lane, self-ratcheting (no mutation entry):
;;; the criterion set against the source list's fifteen and the deliverable set
;;; against its eleven. Adding or dropping a criterion in either the source list
;;; or this ledger fails BY NAME.
;;;
;;; The release state is 13 `met`, 2 `amended` (§26:1677 and :1678), 0 `open`,
;;; and the lane asserts that partition.
;;;
;;; This library lives with the fixture harness, no `src/` library imports it,
;;; and it carries no name into the `(byte-machine ...)` prefix a public importer
;;; would use — the leak sweep asserts both.
(library (byte-machine test release-ledger)
  (export release-criteria release-deliverables
          criterion-ref criterion-text criterion-state criterion-kind
          criterion-witness criterion-receiver
          deliverable-ref deliverable-text deliverable-exists? deliverable-receiver
          release-version release-version-surfaces release-version-export?)
  (import (rnrs))

  ;; The fifteen release criteria. `text` is verbatim minus "- " and the
  ;; trailing ";".
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
       "byte-machine.unit.allocation-audit asserts the generated per-byte slope is zero (alloc(short)=alloc(long)) against a live nonzero control, both executors measured, callbacks disabled with the callback-bound figure recorded beside it (decision 0040). A SECOND slope, per header, with its own live control (decision 0052): the per-byte pair holds the header count fixed, so 128 B/header -- four consed callback outcomes -- sat in the per-message intercept that 0040 item 1 never divides by anything, and read as green here for six milestones. Both slopes are now zero and both are asserted in both wordings. A THIRD dimension, bytes matched per keyword (decision 0054, issue #139): the runtime keyword walk every keyword-table state calls copied its matched prefix on every byte (k²/2 pairs for a k-byte match), which neither slope could see because the HTTP fixture has no keyword table and both hold a header name's match length fixed. The walk now compares each keyword in place, in one pass, and allocates only its answer, and the lane asserts that shape for every k from 0 to 17 against a live control (the pre-fix walk). The claim's SCOPE is a census (decision 0055): the lane derives the twelve runtime procedures emitted code can call from compile.sls's string literals and counts, on a counting twin of each audited machine, which ones its inputs run. Six had never run under the lane -- both error-record constructors, the three callback-failure readers, and the keyword walk as its emitted arm calls it -- and each now has a witness asserting that the event costs the same however many bytes precede it. A totality row fails for any derived op no witness reaches, so a new node kind whose lowering calls a new op reddens the lane until it gains one. A FOURTH dimension, digits read into a 64-bit field (decision 0057): the accumulate arm checked its bound by bignum arithmetic on a u64 field's maximum, about 32 B per digit, and neither the slopes nor the census could see it, because every audited message has no body and the arm calls no runtime op. The emitter now works the bound out at emit time and the arm only compares; the lane asserts that 1000 more numbers up to (greatest-fixnum) allocate nothing in base 10 and base 16, against the same arm above the fixnum range as the live control. A value above the fixnum range is a bignum and the digit that stores it allocates it, which is the claim's stated limit. The census is of ARM KINDS too (decision 0058): the counting twin counts the states each witness enters, and the lane fails for an arm kind an audited machine renders that no witness enters there, for a kind render-state-arm renders that no audited machine has, and for a field operation or predicate no witness runs. Measured before its witnesses, the HTTP machine's accumulate and counted-consume arms had never run, no audited machine had a pause, and 11 of 14 field operations and predicates had run under no input. Its witnesses add fixed and chunked bodies (per body byte and per chunk, including counts above the fixnum range), a pause, the digit machines' overflow, and every field operation and predicate on a u64 field, none allocating while its values are fixnums"
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

  ;; The eleven documentation deliverables.
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

  ;; The version surface. The CURRENT release string has ONE owner (the value
  ;; here) and a mirror rule: every surface in `release-version-surfaces`
  ;; carries it. Added public API makes a release a minor, and so does a
  ;; generated-runtime ABI break; a release that changes no public API, no ABI,
  ;; no emitted text and no golden is a patch. The criteria above do not change
  ;; with the version: they are the release exit criteria, and the ledger keeps
  ;; checking them while this value tracks the release they were met for. The
  ;; `(byte-machine version)` export is DECLINED: no public library exports a
  ;; `version` NAME, so `release-version-export?` is #f and the leak sweep
  ;; asserts as much.
  ;; `current-abi-version` (runtime.sls) is the generated-runtime ABI — a
  ;; different thing with a different lifecycle — and is deliberately NOT this
  ;; value. Do not state the ABI's number in this comment: prose here is not a
  ;; checked value, and a number written here goes stale at the next ABI bump
  ;; without any lane noticing.
  (define release-version "0.7.0")
  (define release-version-export? #f)
  (define release-version-surfaces
    '("CHANGELOG.md 0.7.0 entry (§26:1684)"
      "README.org status paragraph"
      "the parent plan's dated disposition"
      ;; The record that sets this release's version names the release in its
      ;; status block.
      "decision 0056's status block"
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
