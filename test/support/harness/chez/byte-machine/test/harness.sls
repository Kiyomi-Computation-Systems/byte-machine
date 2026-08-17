;;; Chez runtime adapter for the byte-machine private test runner.
;;;
;;; This file and its Gambit counterpart are the only places in the harness
;;; where runtime-specific identifiers may appear, and the two must export
;;; exactly the same names. That requirement is checked by mutation: deleting an
;;; export here must make the self-tests fail (spec section 9.1).
;;;
;;; The shared body is included by bare filename and resolved through Chez's
;;; source-directories, which the launcher sets. That keeps absolute paths out
;;; of the source tree and keeps the include independent of the working
;;; directory.

(library (byte-machine test harness)
  (export
    ;; suite lifecycle
    harness-begin harness-finish harness-summary harness-exit-status
    harness-status-pass harness-status-failed
    harness-status-harness-error harness-status-provenance
    harness-empty-selection-error harness-empty-selection-diagnosis
    ;; structure
    harness-group harness-case
    ;; assertions
    check check-equal check-not-equal check-fail check-raises with-cleanup
    ;; self-testing
    harness-probe harness-set-filter!
    probe-cases probe-failed-cases probe-checks probe-failures
    probe-errors probe-skipped probe-cleanup-failures probe-raised?
    probe-failure-records
    failure-record-id failure-record-what failure-record-detail
    ;; pure helpers, exported so the runner's own tests can reach them
    harness-string-contains? harness-join harness-split harness-take
    harness-member? harness-failure-context harness-normalize-filter
    harness-counters harness-restore-counters! harness-capture-state
    ;; content fingerprint
    harness-fingerprint-bytevector harness-fingerprint-combine
    harness-fingerprint->string harness-fingerprint-file
    ;; adapter protocol
    adapter-runtime-name adapter-runtime-version adapter-machine-type
    adapter-os adapter-architecture adapter-execution-mode
    adapter-environment-variable adapter-exit
    adapter-value->string adapter-describe-condition adapter-file-bytes
    adapter-flush-output
    ;; arithmetic the shared subset uses, which R6RS keeps outside (rnrs)
    modulo quotient remainder)

  (import
    (rnrs)
    (only (rnrs r5rs) modulo quotient remainder)
    (only (chezscheme)
          include machine-type scheme-version getenv
          with-output-to-string display-condition))

  ;; --- runtime identity ----------------------------------------------------

  (define (adapter-runtime-name) "chez")

  ;; (scheme-version) is "Chez Scheme Version 10.4.1"; evidence records compare
  ;; the bare number, so take the final whitespace-delimited token.
  (define (adapter-runtime-version)
    (let* ((full (scheme-version))
           (n (string-length full)))
      (let loop ((i (- n 1)))
        (cond ((< i 0) full)
              ((char=? (string-ref full i) #\space) (substring full (+ i 1) n))
              (else (loop (- i 1)))))))

  (define (adapter-machine-type) (symbol->string (machine-type)))

  ;; --- OS and architecture, derived from the machine type ------------------
  ;;
  ;; Chez's machine type names the target the runtime was actually built for,
  ;; which is what a portability claim needs: an observed architecture, not a
  ;; configure-time guess. A threaded build carries a leading "t".

  (define (adapter-machine-type-body)
    (let ((m (adapter-machine-type)))
      (if (and (> (string-length m) 0) (char=? (string-ref m 0) #\t))
          (substring m 1 (string-length m))
          m)))

  (define (adapter-string-starts-with? s prefix)
    (let ((sn (string-length s)) (pn (string-length prefix)))
      (and (>= sn pn)
           (string=? (substring s 0 pn) prefix))))

  (define adapter-architecture-table
    '(("arm64" . "arm64")
      ("arm32" . "arm32")
      ("a6" . "amd64")
      ("i3" . "x86")
      ("ppc32" . "ppc32")
      ("rv64" . "riscv64")
      ("la64" . "loongarch64")))

  (define adapter-os-table
    '(("le" . "linux")
      ("osx" . "darwin")
      ("nt" . "windows")
      ("fb" . "freebsd")
      ("ob" . "openbsd")
      ("nb" . "netbsd")
      ("s2" . "solaris")
      ("qnx" . "qnx")
      ("ti" . "ios")
      ("a" . "android")))

  (define (adapter-lookup-prefix table s)
    (cond ((null? table) #f)
          ((adapter-string-starts-with? s (car (car table))) (car table))
          (else (adapter-lookup-prefix (cdr table) s))))

  (define (adapter-architecture)
    (let ((hit (adapter-lookup-prefix adapter-architecture-table
                                      (adapter-machine-type-body))))
      (if hit (cdr hit) "unknown")))

  (define (adapter-os)
    (let* ((body (adapter-machine-type-body))
           (arch-hit (adapter-lookup-prefix adapter-architecture-table body)))
      (if (not arch-hit)
          "unknown"
          (let* ((rest (substring body (string-length (car arch-hit))
                                  (string-length body)))
                 (os-hit (adapter-lookup-prefix adapter-os-table rest)))
            (if os-hit (cdr os-hit) "unknown")))))

  ;; The lane registration declares the execution mode; the launcher never
  ;; touches this variable. The launcher's object guard is what makes the
  ;; declaration unfalsifiable: it makes a compiled object impossible to load.
  (define (adapter-execution-mode)
    (let ((m (getenv "BYTE_MACHINE_EXECUTION_MODE")))
      (if (and m (not (string=? m ""))) m "unknown")))

  ;; --- services ------------------------------------------------------------

  (define (adapter-environment-variable name) (getenv name))

  (define (adapter-exit code) (exit code))

  (define (adapter-value->string v)
    (with-output-to-string (lambda () (write v))))

  (define (adapter-describe-condition obj)
    (if (condition? obj)
        (with-output-to-string (lambda () (display-condition obj)))
        (with-output-to-string (lambda () (write obj)))))

  ;; A binary port, so the value is a fingerprint of bytes rather than of
  ;; decoded characters -- and so an LF is an LF on a platform whose text ports
  ;; would translate it. get-bytevector-all returns the EOF object for an empty
  ;; file rather than a zero-length bytevector, so an empty file fingerprints as
  ;; the seed instead of raising.
  (define (adapter-file-bytes path)
    (let* ((port (open-file-input-port path))
           (bytes (get-bytevector-all port)))
      (close-port port)
      (if (eof-object? bytes) (make-bytevector 0) bytes)))

  (define (adapter-flush-output) (flush-output-port (current-output-port)))

  ;; --- shared bodies -------------------------------------------------------
  ;;
  ;; Included by bare filename, resolved through the launcher's
  ;; source-directories. Nothing below this point is Chez-specific.

  (include "fingerprint.scm")
  (include "harness-runner.scm"))
