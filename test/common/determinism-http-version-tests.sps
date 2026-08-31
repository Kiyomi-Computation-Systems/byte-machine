;;; §22.9 determinism over a MULTI-ALTERNATIVE sequence machine, proved against
;;; a committed golden. Byte-identity in this process AND equality to the
;;; golden (which every cell and lane compares against) give cross-process,
;;; cross-lane, and cross-cell identity transitively; M9 completes the four-cell
;;; matrix with the same golden. Comparison is over raw bytes through the
;;; project-owned writer, never via implementation `write`.
;;;
;;; Why a third golden rather than reusing one: decision 0016's ascending-byte
;;; child rule and two-phase id allocation are what keep a BRANCHING trie's
;;; emission deterministic, and neither the one-byte nor the pause golden
;;; contains a branch. An unstable child order at the branch is precisely how
;;; §25:1539's "normalized output is deterministic" would be lost, and only a
;;; machine with a branch can witness it.
;;;
;;; The order in question is trie-put's own insert-before-if-less arm, NOT the
;;; `list-sort` that orders a byte-dispatch node's transitions (decision 0014).
;;; This fixture declares no byte-dispatch node at all, so that comparator never
;;; runs for it: flipping it leaves this golden byte-identical, measured, with
;;; the numbers recorded beside SchemeMutationSuite.cmake's Pass 49.
(import (rnrs) (rnrs eval)
        (only (chezscheme) load)
        (byte-machine test harness)
        (byte-machine test http-version-machine)
        (byte-machine compile)
        (byte-machine runtime))

(harness-begin "determinism.http-version")

(define ok (compile-machine (make-http-version-machine) '()))

(define golden-file
  (let ((f (adapter-environment-variable "BYTE_MACHINE_HTTP_VERSION_GOLDEN_FILE")))
    (if (and f (not (string=? f ""))) f
        (assertion-violation 'determinism "BYTE_MACHINE_HTTP_VERSION_GOLDEN_FILE is unset" f))))

(harness-group "byte-identical emission"
  (lambda ()
    (harness-case "rendering twice in one process yields identical bytes"
      (lambda ()
        (check-equal "twice" (render-machine ok 'http-version-parser)
                     (render-machine ok 'http-version-parser))))
    (harness-case "the emitted bytes equal the committed sequence golden"
      (lambda ()
        (check-equal "golden" (render-machine ok 'http-version-parser)
                     (adapter-file-bytes golden-file))))))

(harness-group "the golden output compiles and executes BOTH alternatives"
  (lambda ()
    (harness-case "each alternative reaches its own target and the branch byte mismatches"
      (lambda ()
        (let* ((tmpdir (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR"))
               (genfile (string-append tmpdir "/determinism-http-version.sls")))
          (call-with-port (open-file-output-port genfile (file-options no-fail))
            (lambda (p) (emit-machine ok 'http-version-parser p)))
          (load genfile)
          (let* ((cm (eval 'http-version-parser (environment '(generated http-version))))
                 (run (lambda (bs)
                        (let ((bv (u8-list->bytevector bs)))
                          (parser-feed! (make-parser cm '() #f) bv 0 (bytevector-length bv)))))
                 (r0 (run (http-version-bytes 'zero)))
                 (r1 (run (http-version-bytes 'one)))
                 (rx (run (append (http-version-shared-prefix) '(50)))))  ; `HTTP/1.2`
            ;; A single-alternative walk would leave the branching prefix state
            ;; untested by this lane, which is the whole reason for a third
            ;; golden -- so both alternatives AND the branch mismatch are driven.
            (check-equal "HTTP/1.0 status" (parser-result-status r0) 'stopped)
            (check-equal "HTTP/1.0 consumed" (parser-result-consumed r0) 8)
            (check-equal "HTTP/1.1 status" (parser-result-status r1) 'stopped)
            (check-equal "HTTP/1.1 consumed" (parser-result-consumed r1) 8)
            ;; Not asserted: that the two accepts differ. Both targets are stop
            ;; nodes, so they are behaviourally identical here -- the structural
            ;; claim lives in normal-ir-tests.sps's "two alternatives over a
            ;; shared prefix lower to one trie" group and in the golden's own
            ;; bytes, which this group already pins.
            ;;
            ;; What the two accepts DO catch is a generated machine that lost
            ;; an alternative. Measured against this program with both of
            ;; SchemeMutationSuite.cmake's Pass 48 truncations -- note each
            ;; KEEPS one arm and drops the other, so the arm named is the one
            ;; that survives, not the one that goes:
            ;;   "compile: a branching state renders only its FIRST transition
            ;;   arm" keeps `HTTP/1.0`'s arm and reddens "HTTP/1.1 status" and
            ;;   "HTTP/1.1 consumed";
            ;;   "compile: a branching state renders only its LAST transition
            ;;   arm" keeps `HTTP/1.1`'s and reddens the HTTP/1.0 pair.
            ;; Nothing else in this group moves for either.
            ;;
            ;; The mismatch pair below catches a different thing, the DEPTH of
            ;; the shared-prefix walk: that the seven prefix states chain and
            ;; the branch is consulted at offset 7. It does not catch a lost
            ;; alternative -- under either truncation above byte 50 still falls
            ;; through to the same mismatch edge at the same offset, and both
            ;; checks stay green. What reddens it is a mis-numbered prefix
            ;; block: prefix ids starting at 0 rather than after the declared
            ;; block report offset 1.
            (check-equal "HTTP/1.2 status" (parser-result-status rx) 'error)
            (check-equal "HTTP/1.2 stops at the branch byte"
                         (parser-result-stream-offset rx) 7)))))))

(harness-finish)
