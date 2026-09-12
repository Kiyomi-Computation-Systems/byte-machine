;;; SPDX-License-Identifier: BSD-3-Clause
;;; (byte-machine private names): the portable ASCII name grammar,
;;; [a-z][a-z0-9-]*, in ONE place (parent §9.3:423, §10.1:480, §16.2:886;
;;; Milestone 6 Slice ⓪, design §4.12 item 2).
;;;
;;; Three libraries check names against it, and the runtime may import neither of
;;; the other two: verify.sls checks every declared name (§16.2:886), compile.sls checks
;;; the caller's output binding (§20), and runtime.sls checks an application's
;;; callback failure code (§9.3:423) -- and the runtime is downstream of
;;; verification, so it must not import (byte-machine verify). Through
;;; Milestone 5 the grammar was two textually identical bodies in verify.sls and
;;; compile.sls and NO body in runtime.sls, which checked `symbol?` alone and
;;; recorded the grammar half as owed. identifier-repertoire-tests.sps proves
;;; the verify and compile sites agree by driving both; the mutation suite's
;;; twinned FIND, which the duplication left, is retired with the copy.
;;;
;;; The grammar is the whole of this library. The reserved sets stay with their
;;; owners -- member 1 (R6RS syntactic keywords) with verify.sls and compile.sls,
;;; members 2 and 3 (the emitted library's own bindings) with compile.sls alone --
;;; because which set applies is a property of the SITE and not of the name.
(library (byte-machine private names)
  (export portable-name?)
  (import (rnrs))

  (define (lower-alpha? c) (and (char>=? c #\a) (char<=? c #\z)))
  (define (name-char? c)
    (or (lower-alpha? c) (and (char>=? c #\0) (char<=? c #\9)) (char=? c #\-)))
  ;; A symbol whose first character is [a-z] and whose rest are [a-z0-9-]. The
  ;; length guard comes first: `string-ref` on the empty name would raise, and a
  ;; refusal is the contract, not a crash. The argument is a symbol by every
  ;; caller's own contract; this predicate does not re-check that.
  (define (portable-name? sym)
    (let ((s (symbol->string sym)))
      (and (> (string-length s) 0)
           (lower-alpha? (string-ref s 0))
           (let loop ((i 1))
             (or (>= i (string-length s))
                 (and (name-char? (string-ref s i)) (loop (+ i 1)))))))))
