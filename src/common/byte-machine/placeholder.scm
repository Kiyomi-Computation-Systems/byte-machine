;;; Placeholder body for the Milestone 0 portability proof.
;;;
;;; SHARED BODY: no library form, no include, no runtime-specific identifier.
;;; Included by exactly one owner library,
;;; src/chez/byte-machine/placeholder.sls (decisions 0002/0003).
;;;
;;; This carries no byte-machine semantics and is deleted in Milestone 1
;;; (milestone-0-portability-spike.md, decision D4). It exists to prove that
;;; the include mechanism loads a body through its owner wrapper, and to give
;;; slice 4 a value whose identity can be compared across a library boundary.
;;;
;;; THE TAG AND THE MARKER ARE FRESHLY ALLOCATED, NEVER SYMBOLS
;;;
;;; Symbols are interned, so (eq? 'x 'x) is true however many separate copies of
;;; this body produced those two occurrences. A symbol tag would make the
;;; double-include defect that byte-machine-implementation-plan.md's section 7.2
;;; forbids structurally invisible: two libraries that had each included this
;;; body would recognise each other's values, and slice 4's identity test would
;;; pass against exactly the tree the rule exists to prevent. A freshly
;;; allocated vector gives a second include a second tag, so the second library
;;; rejects the first's values and the defect is caught.
;;;
;;; test/common/placeholder-tests.scm holds the executable form of this rule.

(define placeholder-tag (vector 'byte-machine-placeholder))

(define placeholder-marker-object (vector 'byte-machine-marker))

(define (make-placeholder value)
  (vector placeholder-tag value))

;; Three decisions, deliberately not folded into one: each is broken by its own
;; mutation in SchemeMutationSuite.cmake.
(define (placeholder? x)
  (and (vector? x)
       (= (vector-length x) 2)
       (eq? (vector-ref x 0) placeholder-tag)))

(define (placeholder-value p)
  (vector-ref p 1))

;; Allocation-free: the object is built once, when this body is loaded, and
;; every call returns that same object.
(define (placeholder-marker)
  placeholder-marker-object)
