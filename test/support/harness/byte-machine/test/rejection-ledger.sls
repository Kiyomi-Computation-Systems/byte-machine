;;; The rejection ledger (decision 0033 item 1; Milestone 7 Slice ④, F13).
;;;
;;; A record of ONE rejected draw -- its index, the machine, its diagnostics, and
;;; the two derived views the catalogue and the independent oracle read: the sorted
;;; unique code set and the sorted unique (code . node) pairs.
;;;
;;; WHY ITS OWN LIBRARY, AND EXECUTOR-FREE. The ledger was born inside
;;; `property-driver.sls` (Slice ②'s "8. rejection ledger" block), which imports
;;; (byte-machine interpret), (byte-machine compile) and (byte-machine runtime) --
;;; it RUNS the differential, so it is executor-bound by construction. Slice ④'s
;;; rejections program must have NO executor in scope (§4.5 / §22.6:1297, F7): the
;;; corrupted machine is never handed to an executor, and the enforcement is
;;; structural -- the program's lane manifest simply does not carry the three
;;; executor libraries, so under the AOT lane the program CANNOT import them. A
;;; ledger left in the driver would drag all three into that manifest and the
;;; structural assertion would be gone. So the record and `make-rejection*` move
;;; here, importing only (rnrs) and (byte-machine verify)'s diagnostic accessors --
;;; verify is not an executor. `property-driver.sls` imports this library and
;;; RE-EXPORTS the seven bindings, so its export list is byte-identical and nothing
;;; that reads the driver moves; the rejections program imports this library
;;; directly and never mentions the driver. One body, two consumers -- the
;;; `error-projection` precedent the driver's own header cites ("eight local copies
;;; ... is eight places for it to drift").

(library (byte-machine test rejection-ledger)
  (export make-rejection* rejection? rejection-index rejection-machine
          rejection-diagnostics rejection-codes rejection-code-sites)
  (import (rnrs)
          (byte-machine verify))

  (define-record-type rejection (fields index machine diagnostics codes code-sites))
  (define (make-rejection* index machine diagnostics)
    (make-rejection index machine diagnostics
                    (sort-unique (map diagnostic-code diagnostics))
                    (sort-unique-pairs (map (lambda (d) (cons (diagnostic-code d) (diagnostic-node d))) diagnostics))))
  (define (sort-unique xs)
    (list-sort (lambda (a b) (string<? (symbol->string a) (symbol->string b)))
               (fold-left (lambda (a x) (if (memq x a) a (cons x a))) '() xs)))
  (define (sort-unique-pairs xs) (fold-left (lambda (a x) (if (member x a) a (cons x a))) '() xs)))
