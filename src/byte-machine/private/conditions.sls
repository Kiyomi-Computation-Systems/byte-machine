;;; SPDX-License-Identifier: BSD-3-Clause
;;; The byte-machine contract-violation condition type and its raiser.
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

  ;; A &byte-machine-contract condition (subtype of &condition), carrying an
  ;; identifying code and who plus an optional detail.  Its exported predicate
  ;; and accessors (ContractCondition = a value satisfying the predicate):
  ;;   byte-machine-contract-condition?       : Any -> Boolean
  ;;   byte-machine-contract-condition-code   : ContractCondition -> Symbol
  ;;   byte-machine-contract-condition-who    : ContractCondition -> Symbol
  ;;   byte-machine-contract-condition-detail : ContractCondition -> (Option Any)
  (define-condition-type &byte-machine-contract &condition
    make-byte-machine-contract-condition byte-machine-contract-condition?
    (code byte-machine-contract-condition-code)
    (who* byte-machine-contract-condition-who)
    (detail byte-machine-contract-condition-detail))

  ;; byte-machine-contract-violation : Symbol Symbol (Option Any) -> Nothing
  ;; (who code detail) — always raises the contract condition, never returns.
  (define (byte-machine-contract-violation who code detail)
    (raise (make-byte-machine-contract-condition code who detail))))
