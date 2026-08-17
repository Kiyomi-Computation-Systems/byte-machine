;;; Gambit runtime adapter for the byte-machine private test runner.
;;;
;;; This file and its Chez counterpart are the only places in the harness where
;;; runtime-specific identifiers may appear, and the two must export exactly the
;;; same names. That is checked by mutation: deleting an export here must make
;;; the self-tests fail on Gambit (spec section 9.1).
;;;
;;; The shared body is included by a path relative to this file, which is how
;;; Gambit resolves `include` inside `define-library`. Chez resolves the same
;;; body by bare filename through its launcher's source-directories. That
;;; difference is the one place the two mechanisms are visibly not the same.
;;;
;;; The import from `(gambit)` is deliberately narrow: importing it wholesale
;;; collides with `(scheme base)`.

(define-library (byte-machine test harness)
  (export
    ;; suite lifecycle
    harness-begin harness-finish harness-summary harness-exit-status
    harness-empty-selection-error harness-empty-selection-diagnosis
    harness-status-pass harness-status-failed
    harness-status-harness-error harness-status-provenance
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
    ;; arithmetic the shared subset uses; R7RS has it in (scheme base), R6RS
    ;; does not, so both adapters export it and shared bodies need not care
    modulo quotient remainder)

  (import (scheme base) (scheme write) (scheme process-context) (scheme file)
          (only (gambit) system-version-string system-type-string
                display-exception))

  (begin

    ;; --- small local helpers ---------------------------------------------
    ;;
    ;; Deliberately local rather than reused from the runner: the adapter is
    ;; what the runner is built on, so it must not depend on it.

    (define (adapter-contains? haystack needle)
      (let ((hn (string-length haystack)) (nn (string-length needle)))
        (let outer ((start 0))
          (cond ((> (+ start nn) hn) #f)
                ((let inner ((i 0))
                   (cond ((= i nn) #t)
                         ((char=? (string-ref haystack (+ start i))
                                  (string-ref needle i))
                          (inner (+ i 1)))
                         (else #f)))
                 #t)
                (else (outer (+ start 1)))))))

    (define (adapter-trim s)
      (let ((n (string-length s)))
        (let find-start ((a 0))
          (cond ((= a n) "")
                ((char=? (string-ref s a) #\space) (find-start (+ a 1)))
                (else
                 (let find-end ((b n))
                   (if (char=? (string-ref s (- b 1)) #\space)
                       (find-end (- b 1))
                       (substring s a b))))))))

    ;; Gambit's display-exception writes several lines and a trailing newline.
    ;; A FAIL record is one line, and a multi-line detail would break every
    ;; consumer that reads the log a line at a time, so newlines are folded to
    ;; spaces. Chez's display-condition already yields one line.
    (define (adapter-flatten text)
      (let loop ((chars (string->list text)) (acc '()))
        (cond ((null? chars) (adapter-trim (list->string (reverse acc))))
              ((or (char=? (car chars) #\newline)
                   (char=? (car chars) #\return))
               (loop (cdr chars) (cons #\space acc)))
              (else (loop (cdr chars) (cons (car chars) acc))))))

    ;; --- runtime identity -------------------------------------------------

    (define (adapter-runtime-name) "gambit")

    ;; (system-version-string) is "v4.9.8". Evidence records compare bare
    ;; numbers, so the marker is stripped here rather than in every consumer --
    ;; the same normalization cmake/ByteMachineGambit.cmake performs.
    (define (adapter-runtime-version)
      (let ((s (system-version-string)))
        (if (and (> (string-length s) 0) (char=? (string-ref s 0) #\v))
            (substring s 1 (string-length s))
            s)))

    ;; The target triple, e.g. "aarch64-apple-darwin25.6.0". Reported whole as
    ;; evidence; os and architecture are derived from it below.
    (define (adapter-machine-type) (system-type-string))

    (define (adapter-triple-architecture)
      (let* ((triple (adapter-machine-type))
             (n (string-length triple)))
        (let loop ((i 0))
          (cond ((= i n) triple)
                ((char=? (string-ref triple i) #\-) (substring triple 0 i))
                (else (loop (+ i 1)))))))

    (define adapter-architecture-table
      '(("aarch64" . "arm64")
        ("arm64" . "arm64")
        ("x86_64" . "amd64")
        ("amd64" . "amd64")
        ("i386" . "x86")
        ("i686" . "x86")
        ("armv7l" . "arm32")
        ("riscv64" . "riscv64")))

    (define adapter-os-table
      '(("darwin" . "darwin")
        ("linux" . "linux")
        ("mingw" . "windows")
        ("cygwin" . "windows")
        ("windows" . "windows")
        ("freebsd" . "freebsd")
        ("openbsd" . "openbsd")
        ("netbsd" . "netbsd")
        ("solaris" . "solaris")))

    (define (adapter-lookup-exact table key)
      (cond ((null? table) #f)
            ((string=? key (car (car table))) (cdr (car table)))
            (else (adapter-lookup-exact (cdr table) key))))

    (define (adapter-lookup-substring table text)
      (cond ((null? table) #f)
            ((adapter-contains? text (car (car table))) (cdr (car table)))
            (else (adapter-lookup-substring (cdr table) text))))

    (define (adapter-architecture)
      (let ((hit (adapter-lookup-exact adapter-architecture-table
                                       (adapter-triple-architecture))))
        (if hit hit "unknown")))

    (define (adapter-os)
      (let ((hit (adapter-lookup-substring adapter-os-table
                                           (adapter-machine-type))))
        (if hit hit "unknown")))

    ;; Declared by the registration, because the lane is the only party that
    ;; knows what it actually loaded.
    (define (adapter-execution-mode)
      (let ((m (get-environment-variable "BYTE_MACHINE_EXECUTION_MODE")))
        (if (and m (not (string=? m ""))) m "unknown")))

    ;; --- services ----------------------------------------------------------

    (define (adapter-environment-variable name) (get-environment-variable name))

    (define (adapter-exit code) (exit code))

    (define (adapter-value->string v)
      (let ((port (open-output-string)))
        (write v port)
        (get-output-string port)))

    (define (adapter-describe-condition obj)
      (let ((port (open-output-string)))
        (display-exception obj port)
        (adapter-flatten (get-output-string port))))

    ;; A binary port, for the reason the Chez adapter gives. R7RS has no
    ;; get-bytevector-all, so this reads in chunks and concatenates; 65536 is a
    ;; block size, not a limit, and a body larger than one chunk is the ordinary
    ;; case rather than an edge case.
    (define (adapter-file-bytes path)
      (let ((port (open-binary-input-file path)))
        (let loop ((chunks '()) (total 0))
          (let ((chunk (read-bytevector 65536 port)))
            (if (eof-object? chunk)
                (begin
                  (close-port port)
                  (let ((bv (make-bytevector total 0)))
                    (let fill ((rest (reverse chunks)) (at 0))
                      (if (null? rest)
                          bv
                          (let ((c (car rest)))
                            (let copy ((i 0))
                              (if (< i (bytevector-length c))
                                  (begin
                                    (bytevector-u8-set! bv (+ at i)
                                                        (bytevector-u8-ref c i))
                                    (copy (+ i 1)))))
                            (fill (cdr rest)
                                  (+ at (bytevector-length c))))))))
                (loop (cons chunk chunks) (+ total (bytevector-length chunk))))))))

    (define (adapter-flush-output) (flush-output-port (current-output-port))))

  ;; --- shared bodies -------------------------------------------------------
  ;;
  ;; Source-file-relative, which is how Gambit resolves include inside
  ;; define-library. Nothing below this point is Gambit-specific.

  (include "../../../shared/fingerprint.scm")
  (include "../../../shared/harness-runner.scm"))
