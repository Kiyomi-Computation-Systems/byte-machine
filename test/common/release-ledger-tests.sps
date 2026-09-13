;;; Milestone 9 Slice ⓪: the release ledger, read by a lane (decision 0038).
;;; The two totality rows re-read §26 and §27 from the parent plan as DATA and
;;; set-compare against the ledger, so a drift in either side fails by name
;;; (self-ratcheting; no mutation entry). Mechanical rows are executed here;
;;; judgement rows are recorded, not re-checked. The §4.5 version surface is
;;; checked: `0.1.0` is the single owner, the export is declined, and no public
;;; library exports a `version` name.
(import (rnrs)
        (only (chezscheme) directory-list)
        (byte-machine test harness)
        (byte-machine test release-ledger))

(harness-begin "unit.release-ledger")

(define (env name)
  (let ((v (adapter-environment-variable name)))
    (if (and v (not (string=? v ""))) v
        (assertion-violation 'release-ledger (string-append name " is unset") v))))
(define repo (env "BYTE_MACHINE_REPO_ROOT"))
(define source-root (env "BYTE_MACHINE_SOURCE_ROOT"))
(define native-artifacts-file (env "BYTE_MACHINE_NATIVE_ARTIFACTS_FILE"))

;; Read a whole file as a latin-1 string (bytes 0-255 -> chars), newlines kept.
(define (file-string path)
  (let ((bv (adapter-file-bytes path)))
    (let loop ((i (- (bytevector-length bv) 1)) (acc '()))
      (if (< i 0) (list->string acc)
          (loop (- i 1) (cons (integer->char (bytevector-u8-ref bv i)) acc))))))
(define (lines-of s) (harness-split s #\newline))
(define (trim-right s)
  (let loop ((n (string-length s)))
    (if (and (> n 0)
             (let ((c (string-ref s (- n 1))))
               (or (char=? c #\space) (char=? c #\tab) (char=? c #\return))))
        (loop (- n 1))
        (substring s 0 n))))
(define (starts-with? s p)
  (and (>= (string-length s) (string-length p))
       (string=? (substring s 0 (string-length p)) p)))
(define (sort-strings xs) (list-sort string<? xs))

;; A §26/§27 bullet, normalised: "- <text>;" or "- <text>." -> "<text>".
(define (bullet-text line)
  (let* ((t (trim-right line))
         (b (if (starts-with? t "- ") (substring t 2 (string-length t)) t))
         (n (string-length b)))
    (if (and (> n 0)
             (let ((c (string-ref b (- n 1)))) (or (char=? c #\;) (char=? c #\.))))
        (substring b 0 (- n 1))
        b)))

;; Collect the "- " bullets in the plan between a start heading and the first
;; heading/marker that ends the section.
(define (plan-bullets plan start-prefix end-prefixes)
  (let loop ((ls (lines-of plan)) (in #f) (acc '()))
    (cond
      ((null? ls) (reverse acc))
      ((and (not in) (starts-with? (car ls) start-prefix)) (loop (cdr ls) #t acc))
      ((and in (exists (lambda (p) (starts-with? (car ls) p)) end-prefixes))
       (reverse acc))
      ((and in (starts-with? (trim-right (car ls)) "- "))
       (loop (cdr ls) in (cons (bullet-text (car ls)) acc)))
      (else (loop (cdr ls) in acc)))))

(define plan (file-string (string-append repo "/.plans/byte-machine-implementation-plan.md")))
(define cmakelists (file-string (string-append repo "/test/CMakeLists.txt")))

;; ---- totality row 1: §26's fifteen ----------------------------------------
(harness-group "totality: the ledger's criterion set equals §26's fifteen (self-ratcheting)"
  (lambda ()
    (let ((plan-set (sort-strings (plan-bullets plan "## 26." '("## 27."))))
          (ledger-set (sort-strings (map criterion-text release-criteria))))
      (harness-case "count is fifteen"
        (lambda ()
          (check-equal "ledger rows" (length release-criteria) 15)
          (check-equal "plan §26 bullets" (length plan-set) 15)))
      (harness-case "the ledger's criterion texts equal §26's, verbatim"
        (lambda ()
          (check-equal "set-equal (plan vs ledger)" ledger-set plan-set))))))

;; ---- totality row 2: §27's eleven -----------------------------------------
(harness-group "totality: the ledger's deliverable set equals §27's eleven (self-ratcheting)"
  (lambda ()
    (let ((plan-set (sort-strings (plan-bullets plan "## 27." '("## 28." "Examples must use"))))
          (ledger-set (sort-strings (map deliverable-text release-deliverables))))
      (harness-case "count is eleven"
        (lambda ()
          (check-equal "ledger rows" (length release-deliverables) 11)
          (check-equal "plan §27 bullets" (length plan-set) 11)))
      (harness-case "the ledger's deliverable texts equal §27's, verbatim"
        (lambda ()
          (check-equal "set-equal (plan vs ledger)" ledger-set plan-set))))))

;; ---- the disposition partition (the design Appendix, authoritative) --------
(define (refs-with-state st)
  (sort-strings (map criterion-ref (filter (lambda (r) (eq? (criterion-state r) st)) release-criteria))))
(harness-group "the disposition partition (v0.1 close: 13 met, 2 amended, 0 open)"
  (lambda ()
    (harness-case "met rows are exactly the thirteen (Slice ⑤ added §26:1682, §26:1684)"
      (lambda ()
        (check-equal "met"
                     (refs-with-state 'met)
                     (sort-strings '("§26:1671" "§26:1672" "§26:1673" "§26:1674" "§26:1675"
                                     "§26:1676" "§26:1679" "§26:1680" "§26:1681" "§26:1682"
                                     "§26:1683" "§26:1684" "§26:1685")))))
    (harness-case "the two amended rows are exactly the CI-blocked pair (decision 0041)"
      (lambda ()
        (check-equal "amended"
                     (refs-with-state 'amended)
                     (sort-strings '("§26:1677" "§26:1678")))))
    (harness-case "nothing remains partly or open at the v0.1 close"
      (lambda ()
        (check-equal "partly" (refs-with-state 'partly) '())
        (check-equal "open" (refs-with-state 'open) '())))
    (harness-case "every row is met or amended, and none names a receiver (nothing is owed)"
      (lambda ()
        (for-each
         (lambda (r)
           (check (string-append (criterion-ref r) " is met or amended")
                  (and (memq (criterion-state r) '(met amended)) #t))
           (check (string-append (criterion-ref r) " names no receiver")
                  (null? (criterion-receiver r))))
         release-criteria)))))

;; ---- mechanical rows are executed -----------------------------------------
(define (row ref) (find (lambda (r) (string=? (criterion-ref r) ref)) release-criteria))
(define (mechanical? ref) (eq? (criterion-kind (row ref)) 'mechanical))
(define (lane-registered? name) (harness-string-contains? cmakelists name))
(define (dir-entries p) (if (file-exists? p) (list-sort string<? (directory-list p)) 'no-dir))

(harness-group "mechanical rows: the lane executes each witness"
  (lambda ()
    (harness-case "§26:1673 differential lanes are registered"
      (lambda ()
        (check "kind mechanical" (mechanical? "§26:1673"))
        (check "byte-machine.differential lane present" (lane-registered? "byte-machine.differential"))))
    (harness-case "§26:1677 amended for v0.1; the mechanism (six goldens) is complete"
      (lambda ()
        (check "state amended (decision 0041)" (eq? (criterion-state (row "§26:1677")) 'amended))
        (check "byte-machine.determinism lane present" (lane-registered? "byte-machine.determinism"))
        (check "the sixth (HTTP) golden is committed"
               (file-exists? (string-append repo "/test/fixtures/generated-http.golden.sls")))))
    (harness-case "§26:1679 the committed benchmark baseline is recorded with the §23.1 fields"
      (lambda ()
        (check "kind mechanical" (mechanical? "§26:1679"))
        (check "the runner is present"
               (file-exists? (string-append repo "/bench/runner/benchmark.sps")))
        (let* ((art (call-with-input-file
                     (string-append repo "/bench/fixtures/baseline-tarm64osx.sls") read))
               (keys (map car art)))
          (for-each
           (lambda (k) (check (string-append "baseline field: " (symbol->string k))
                              (and (memq k keys) #t)))
           '(schema harness-version runtime mode compiler-options warmup rounds
             iterations-per-round deterministic-seed exact-command one-time-metrics
             required-metrics unavailable-metrics workloads))
          (check-equal "twelve §23.2 workloads" (length (cadr (assq 'workloads art))) 12))))
    (harness-case "§26:1680 the allocation-audit lane is registered (generated slope gated)"
      (lambda ()
        (check "kind mechanical" (mechanical? "§26:1680"))
        (check "byte-machine.unit.allocation-audit lane present"
               (lane-registered? "byte-machine.unit.allocation-audit"))))
    (harness-case "§26:1671 the source IR and builder reference documents the node kinds"
      (lambda ()
        (check "kind mechanical" (mechanical? "§26:1671"))
        (check "reference present"
               (file-exists? (string-append repo "/.reference/source-ir-and-builder.md")))))
    (harness-case "§26:1681 the integration guide documents the dependency boundary"
      (lambda ()
        (check "kind mechanical" (mechanical? "§26:1681"))
        (check "reference present"
               (file-exists? (string-append repo "/.reference/generated-code-integration-chez.md")))))
    (harness-case "§26:1682 met; the example ships (its clean-checkout run is recorded in the close)"
      (lambda ()
        (check "state met" (eq? (criterion-state (row "§26:1682")) 'met))
        (check "example program present"
               (file-exists? (string-append repo "/examples/generate-simple-machine/generate.sps")))
        (check "example README present"
               (file-exists? (string-append repo "/examples/generate-simple-machine/README.md")))))
    (harness-case "§26:1684 CHANGELOG.md carries the 0.1.0 entry"
      (lambda ()
        (check "kind mechanical" (mechanical? "§26:1684"))
        (let ((cl (string-append repo "/CHANGELOG.md")))
          (check "CHANGELOG.md exists" (file-exists? cl))
          (check "has the [0.1.0] entry"
                 (harness-string-contains? (file-string cl) "[0.1.0]")))))
    (harness-case "§26:1685 no native artifact is tracked; the leak lane guards HTTP re-export"
      (lambda ()
        (check "kind mechanical" (mechanical? "§26:1685"))
        (check "git ls-files native pattern is empty"
               (string=? (harness-bytes->string (adapter-file-bytes native-artifacts-file)) ""))
        (check "byte-machine.unit.http-leak lane present" (lane-registered? "byte-machine.unit.http-leak"))))))

;; ---- judgement rows carry a standing witness paragraph ---------------------
(harness-group "judgement rows: recorded, never re-checked (no sentinel-from-expectation)"
  (lambda ()
    (harness-case "every judgement row carries a nonempty witness paragraph"
      (lambda ()
        (for-each
         (lambda (r)
           (if (eq? (criterion-kind r) 'judgement)
               (check (string-append (criterion-ref r) " has a witness")
                      (> (string-length (criterion-witness r)) 0))))
         release-criteria)))))

;; ---- §27 deliverables: each marked-existing deliverable is really present ---
(define reference-files
  '(("§27:1692" . ".reference/source-ir-and-builder.md")
    ("§27:1693" . ".reference/transition-and-cursor-semantics.md")
    ("§27:1694" . ".reference/callback-span-lifetime.md")
    ("§27:1695" . ".reference/field-and-overflow.md")
    ("§27:1696" . ".reference/verifier-diagnostic-catalog.md")
    ("§27:1697" . ".reference/generated-code-integration-chez.md")
    ("§27:1698" . ".reference/grammar-author-testing-guide.md")
    ("§27:1699" . ".reference/benchmark-methodology-and-baseline.md")
    ("§27:1700" . ".reference/portability-matrix.md")))
(harness-group "§27: every deliverable marked existing is really present (11 of 11)"
  (lambda ()
    (harness-case "each reference document exists as a committed file"
      (lambda ()
        (for-each
         (lambda (pair)
           (check (string-append (car pair) " -> " (cdr pair))
                  (file-exists? (string-append repo "/" (cdr pair)))))
         reference-files)))
    (harness-case "§27:1691 the README quick start exists"
      (lambda ()
        (check "README has a Quick start"
               (harness-string-contains? (file-string (string-append repo "/README.org")) "Quick start"))))
    (harness-case "§27:1701 the changelog exists"
      (lambda ()
        (check "CHANGELOG.md exists" (file-exists? (string-append repo "/CHANGELOG.md")))))
    (harness-case "all eleven §27 deliverables are marked existing"
      (lambda ()
        (check-equal "exists count" (length (filter deliverable-exists? release-deliverables)) 11)))))

;; ---- §4.5 the version surface ----------------------------------------------
;; Read the public libraries as data (the http-leak technique) and assert none
;; exports a `version` name — the declined export made observable.
(define (read-library-datum path)
  (call-with-input-file path (lambda (p) (read p))))
(define (lib-exports d) (cdr (caddr d)))   ; (library <name> (export …) (import …) …)
(define public-src-libs
  (map (lambda (n) (string-append source-root "/byte-machine/" n ".sls"))
       '("graph" "verify" "compile" "interpret" "runtime")))
(harness-group "§4.5: the version surface and the declined export"
  (lambda ()
    (harness-case "0.1.0 is the single owner and the export is declined"
      (lambda ()
        (check-equal "release-version" release-version "0.1.0")
        (check "export declined for v0.1" (not release-version-export?))
        (check "five mirror surfaces named" (= (length release-version-surfaces) 5))))
    (harness-case "no public library exports a `version` name"
      (lambda ()
        (for-each
         (lambda (path)
           (let ((leaked (filter (lambda (e) (harness-string-contains? (symbol->string e) "version"))
                                 (lib-exports (read-library-datum path)))))
             (check-equal (string-append path ": no version export") leaked '())))
         public-src-libs)))))

(harness-finish)
