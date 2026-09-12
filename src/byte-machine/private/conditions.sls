;;; SPDX-License-Identifier: BSD-3-Clause
;;; The byte-machine contract-violation condition (parent §9.4, M1 subset).
;;; A programmer error against the public API — bad argument shape, an
;;; unverified machine handed to the interpreter, and so on. Codes are symbols;
;;; tests compare the code and who, never rendered text.
(library (byte-machine private conditions)
  (export byte-machine-contract-violation
          byte-machine-contract-condition?
          byte-machine-contract-condition-code
          byte-machine-contract-condition-who
          byte-machine-contract-condition-detail)
  (import (rnrs))

  (define-condition-type &byte-machine-contract &condition
    make-byte-machine-contract-condition byte-machine-contract-condition?
    (code byte-machine-contract-condition-code)
    (who* byte-machine-contract-condition-who)
    (detail byte-machine-contract-condition-detail))

  (define (byte-machine-contract-violation who code detail)
    (raise (make-byte-machine-contract-condition code who detail))))
