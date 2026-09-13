;;; Milestone 9 Slice ①: the DRY Windows-cell audit, as assertions about the
;;; tree (design §6 item 2). Every question the Windows amd64 cell would answer is
;;; written down BEFORE it runs, so whoever funds CI after v0.1 turns the cell on
;;; against a written baseline, not a blank slate. Two of the rows are answerable
;;; only from a runner (the discovered scheme.exe path; the AOT object extension
;;; on ta6nt) and are DEFERRED past v0.1 with no CI (decision 0041) — they live in
;;; .plans/milestone-9-windows-cell-audit.md, not here. The rows below are
;;; answerable from the tree at this slice's base and are asserted, not narrated.
(import (rnrs)
        (byte-machine test harness))

(harness-begin "unit.windows-audit")

(define (env name)
  (let ((v (adapter-environment-variable name)))
    (if (and v (not (string=? v ""))) v
        (assertion-violation 'windows-audit (string-append name " is unset") v))))
(define repo (env "BYTE_MACHINE_REPO_ROOT"))
(define (file-string path)
  (let ((bv (adapter-file-bytes path)))
    (let loop ((i (- (bytevector-length bv) 1)) (acc '()))
      (if (< i 0) (list->string acc)
          (loop (- i 1) (cons (integer->char (bytevector-u8-ref bv i)) acc))))))

;; Row 1 — the BYTE_MACHINE_EXPECT_OS / ARCH the Windows cell asserts. The
;; harness derives OS and architecture from Chez's machine-type; the Windows
;; amd64 build is `ta6nt` (threaded) or `a6nt`. `nt` -> windows and `a6` -> amd64
;; are already in the harness's tables, so the identity assertion the cell runs
;; is answerable now, without a runner.
(harness-group "the Windows machine-type resolves to windows/amd64 (already in the harness tables)"
  (lambda ()
    (harness-case "ta6nt (threaded) -> windows / amd64"
      (lambda ()
        (check-equal "os" (adapter-machine-type->os "ta6nt") "windows")
        (check-equal "arch" (adapter-machine-type->architecture "ta6nt") "amd64")))
    (harness-case "a6nt (non-threaded) -> windows / amd64"
      (lambda ()
        (check-equal "os" (adapter-machine-type->os "a6nt") "windows")
        (check-equal "arch" (adapter-machine-type->architecture "a6nt") "amd64")))))

;; Row 2 — the discovery names. find_program(NAMES scheme chez chezscheme) is what
;; the cell relies on to find the installed runtime; the candidate list is in the
;; toolchain module. (Whether the Windows installer puts one of these on PATH is
;; the runner-only half — deferred.)
(harness-group "the runtime discovery names include chez and chezscheme"
  (lambda ()
    (harness-case "ByteMachineChez.cmake carries the candidate names"
      (lambda ()
        (check "candidate names present"
               (harness-string-contains?
                (file-string (string-append repo "/cmake/ByteMachineChez.cmake"))
                "BYTE_MACHINE_CHEZ_CANDIDATE_NAMES scheme chez chezscheme"))))))

;; Row 3 — the escape hatch. When discovery fails (the runner-only risk), the
;; caller sets -DBYTE_MACHINE_CHEZ_EXECUTABLE; the README documents it.
(harness-group "the -DBYTE_MACHINE_CHEZ_EXECUTABLE fallback is documented"
  (lambda ()
    (harness-case "README.org names the fallback"
      (lambda ()
        (check "documented"
               (harness-string-contains?
                (file-string (string-append repo "/README.org"))
                "BYTE_MACHINE_CHEZ_EXECUTABLE"))))))

(harness-finish)
