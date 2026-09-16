;;; (byte-machine test machine-print): the fixture printer (Milestone 7 Slice ③,
;;; design §4.7, decision 0033 item 4). Given a built machine, it returns a DATUM
;;; -- a Scheme s-expression of `(byte-machine graph)` constructor calls -- that,
;;; evaluated in an environment importing `(rnrs)` and `(byte-machine graph)`,
;;; rebuilds a machine with the same IR. The saver (Slice ③, in the property lane)
;;; `write`s that datum into a fixture; the round-trip test evaluates it directly.
;;;
;;; A FUNCTIONAL CORE (F18, as the property driver is): every entry returns a datum
;;; and asserts NOTHING -- no `check`, no harness import, no I/O. The one seam that
;;; writes is the saver, in the LANE.
;;;
;;; IT DOES NOT `write` A MACHINE OBJECT (Task 2 Step 6). A machine is a tagged
;;; vector and `(write machine)` renders `#(…)`, which no reader rebuilds through
;;; the public API. So the printer walks the machine through `(byte-machine private
;;; ir)`'s accessors and BUILDS a list of constructor-call forms. §4.7's phrase "the
;;; harness's own writer" names no such export (`harness.sls`'s only datum writer is
;;; the internal `with-output-to-string`+`write` at :149); Task 12 corrects it.
;;;
;;; READS through `(byte-machine private ir)` (F3): §9.1 fixes a construction
;;; surface and `graph.sls` exports no node accessors, so reading a built machine
;;; back is not part of the public API and the printer reaches the private library
;;; -- F18's option 2, the four-program precedent. It EMITS calls to `graph.sls`'s
;;; public constructors only: the datum names `make-machine`, the thirteen
;;; `make-*-node`, `make-byte-case`, `make-sequence-case`, `make-edge`, the four
;;; matcher constructors, and the four declaration constructors, and nothing private.
;;;
;;; THE ARM TABLES ARE HAND-WRITTEN AND EXPORTED (F4, the S2 technique). Dispatch
;;; runs off `node-print-arm-table` / `matcher-print-arm-table`, each a literal list
;;; of `(kind-stem predicate arm)` naming all thirteen node kinds and all four
;;; matcher kinds by hand. The fixture program's totality row derives `node?`'s and
;;; `matcher?`'s disjuncts from `ir.sls` AS A DATUM and set-equals them to these
;;; tables' `(map car …)`. If the dispatch read a list out of `ir.sls` at run time
;;; the row would compare `ir.sls` against itself and close nothing; hand-writing
;;; the table is what makes a fourteenth node kind added to `ir.sls` without a
;;; printer arm fail the row (and the dispatcher's own `no-arm` raise) rather than
;;; pass silently. This table is one of the test-side censuses design §4.9's
;;; Appendix names for Milestone 8.
(library (byte-machine test machine-print)
  (export print-machine node-print-arm-table matcher-print-arm-table)
  (import (rnrs) (byte-machine private ir))

  ;; A leaf operand of a constructor. Symbols and lists must be QUOTED so the datum
  ;; evaluates to the value rather than a variable reference or a procedure call;
  ;; numbers, booleans and strings are self-quoting and pass through. Every operand
  ;; the IR stores at a leaf is one of these: node names / targets / kinds /
  ;; operations / predicates (symbols), eof-target / error / default-branch /
  ;; complete-callback / source-label (symbol or #f), byte lists / branch-keys /
  ;; branch-targets / field arguments (lists of literals), widths / initials / bases
  ;; / bytes (exact integers), required? (boolean), reason (string).
  (define (lit x)
    (cond ((symbol? x) (list 'quote x))
          ((or (pair? x) (null? x)) (list 'quote x))
          (else x)))

  ;; ---- matchers (four kinds; recursive through byte-complement) ----
  (define (print-exact-byte m)
    (list 'make-exact-byte-matcher (exact-byte-matcher-byte m)))
  (define (print-byte-set m)
    (list 'make-byte-set-matcher (lit (byte-set-matcher-bytes m))))
  (define (print-byte-range m)
    (list 'make-byte-range-matcher (byte-range-matcher-low m) (byte-range-matcher-high m)))
  (define (print-byte-complement m)
    (list 'make-byte-complement-matcher (print-matcher (byte-complement-matcher-matcher m))))

  (define matcher-print-arm-table
    (list (list 'exact-byte     exact-byte-matcher?      print-exact-byte)
          (list 'byte-set       byte-set-matcher?        print-byte-set)
          (list 'byte-range     byte-range-matcher?      print-byte-range)
          (list 'byte-complement byte-complement-matcher? print-byte-complement)))

  (define (print-matcher m)
    (let loop ((t matcher-print-arm-table))
      (cond ((null? t)
             (assertion-violation 'print-matcher "no arm for matcher kind" m))
            (((cadr (car t)) m) ((caddr (car t)) m))
            (else (loop (cdr t))))))

  ;; ---- edge, byte case, sequence case ----
  (define (print-edge e)
    (list 'make-edge (lit (edge-target e)) (lit (edge-mode e))))
  (define (print-byte-case c)
    (list 'make-byte-case (print-matcher (byte-case-matcher c))
          (print-edge (byte-case-edge c)) (lit (byte-case-source-label c))))
  (define (print-sequence-case c)
    (list 'make-sequence-case (lit (sequence-case-bytes c))
          (lit (sequence-case-target c)) (lit (sequence-case-source-label c))))

  (define (list-of f xs) (cons 'list (map f xs)))

  ;; ---- nodes (thirteen kinds) ----
  (define (print-byte-dispatch n)
    (list 'make-byte-dispatch-node (lit (byte-dispatch-node-name n))
          (list-of print-byte-case (byte-dispatch-node-cases n))
          (print-edge (byte-dispatch-node-fallback n))
          (lit (byte-dispatch-node-eof-target n))
          (lit (byte-dispatch-node-source-label n))))
  (define (print-sequence-dispatch n)
    (list 'make-sequence-dispatch-node (lit (sequence-dispatch-node-name n))
          (list-of print-sequence-case (sequence-dispatch-node-cases n))
          (print-edge (sequence-dispatch-node-mismatch n))
          (lit (sequence-dispatch-node-eof-target n))
          (lit (sequence-dispatch-node-source-label n))))
  (define (print-keyword-entry e)
    (list 'make-keyword-entry (lit (keyword-entry-bytes e))
          (lit (keyword-entry-target e)) (lit (keyword-entry-source-label e))))
  (define (print-keyword-table n)
    (list 'make-keyword-table-node (lit (keyword-table-node-name n))
          (list-of print-keyword-entry (keyword-table-node-entries n))
          (print-edge (keyword-table-node-no-match n))
          (lit (keyword-table-node-eof-target n))
          (lit (keyword-table-node-case-insensitive? n))
          (lit (keyword-table-node-source-label n))))
  (define (print-stop n)
    (list 'make-stop-node (lit (stop-node-name n)) (lit (stop-node-source-label n))))
  (define (print-error n)
    (list 'make-error-node (lit (error-node-name n)) (lit (error-node-error-name n))
          (lit (error-node-source-label n))))
  (define (print-finish n)
    (list 'make-finish-node (lit (finish-node-name n)) (lit (finish-node-source-label n))))
  (define (print-pause n)
    ;; M12: the 4-arg form carrying the optional reason (a symbol or #f), so a
    ;; reason-bearing pause survives print -> reparse.
    (list 'make-pause-node (lit (pause-node-name n)) (lit (pause-node-continuation n))
          (lit (pause-node-reason n)) (lit (pause-node-source-label n))))
  (define (print-field-action n)
    (list 'make-field-action-node (lit (field-action-node-name n))
          (lit (field-action-node-operation n)) (lit (field-action-node-arguments n))
          (lit (field-action-node-next n)) (lit (field-action-node-error n))
          (lit (field-action-node-source-label n))))
  (define (print-field-branch n)
    (list 'make-field-branch-node (lit (field-branch-node-name n))
          (lit (field-branch-node-predicate n)) (lit (field-branch-node-arguments n))
          (lit (field-branch-node-true-target n)) (lit (field-branch-node-false-target n))
          (lit (field-branch-node-source-label n))))
  (define (print-integer-accumulate n)
    (list 'make-integer-accumulate-node (lit (integer-accumulate-node-name n))
          (lit (integer-accumulate-node-field n)) (integer-accumulate-node-base n)
          (lit (integer-accumulate-node-digit-target n))
          (print-edge (integer-accumulate-node-nondigit-edge n))
          (lit (integer-accumulate-node-overflow-error n))
          (lit (integer-accumulate-node-eof-target n))
          (lit (integer-accumulate-node-source-label n))))
  (define (print-callback n)
    ;; M12: the 7-arg form carrying the optional reason (a symbol or #f).
    (list 'make-callback-node (lit (callback-node-name n)) (lit (callback-node-callback n))
          (lit (callback-node-continue-target n)) (lit (callback-node-branch-targets n))
          (lit (callback-node-pause-continuation n)) (lit (callback-node-reason n))
          (lit (callback-node-source-label n))))
  (define (print-span-start n)
    (list 'make-span-start-node (lit (span-start-node-name n)) (lit (span-start-node-span n))
          (lit (span-start-node-next n)) (lit (span-start-node-source-label n))))
  (define (print-span-end n)
    (list 'make-span-end-node (lit (span-end-node-name n)) (lit (span-end-node-span n))
          (lit (span-end-node-next n)) (lit (span-end-node-source-label n))))
  (define (print-counted-consume n)
    (list 'make-counted-consume-node (lit (counted-consume-node-name n))
          (lit (counted-consume-node-field n)) (lit (counted-consume-node-next n))
          (lit (counted-consume-node-eof-target n))
          (lit (counted-consume-node-source-label n))))

  (define node-print-arm-table
    (list (list 'byte-dispatch       byte-dispatch-node?       print-byte-dispatch)
          (list 'sequence-dispatch   sequence-dispatch-node?   print-sequence-dispatch)
          (list 'keyword-table       keyword-table-node?       print-keyword-table)
          (list 'stop                stop-node?                print-stop)
          (list 'error               error-node?               print-error)
          (list 'finish              finish-node?              print-finish)
          (list 'pause               pause-node?               print-pause)
          (list 'field-action        field-action-node?        print-field-action)
          (list 'field-branch        field-branch-node?        print-field-branch)
          (list 'integer-accumulate  integer-accumulate-node?  print-integer-accumulate)
          (list 'callback            callback-node?            print-callback)
          (list 'span-start          span-start-node?          print-span-start)
          (list 'span-end            span-end-node?            print-span-end)
          (list 'counted-consume     counted-consume-node?     print-counted-consume)))

  (define (print-node n)
    (let loop ((t node-print-arm-table))
      (cond ((null? t)
             (assertion-violation 'print-node "no arm for node kind" n))
            (((cadr (car t)) n) ((caddr (car t)) n))
            (else (loop (cdr t))))))

  ;; ---- declarations ----
  (define (print-error-declaration d)
    (list 'make-error-declaration (lit (error-declaration-name d))
          (lit (error-declaration-code d)) (error-declaration-reason d)
          (lit (error-declaration-source-label d))))
  (define (print-uint-field f)
    ;; The 5-arg form, always: the settable flag (Milestone 13) is the field's
    ;; fourth element, so a settable machine printed and reparsed keeps it -- the
    ;; 4-arg form would silently reparse settable? to #f.
    (list 'make-uint-field (lit (uint-field-name f)) (uint-field-width f)
          (uint-field-initial f) (lit (uint-field-settable? f))
          (lit (uint-field-source-label f))))
  (define (print-callback-declaration d)
    (list 'make-callback-declaration (lit (callback-declaration-name d))
          (lit (callback-declaration-kind d)) (callback-declaration-required? d)
          (lit (callback-declaration-branch-keys d))
          (lit (callback-declaration-default-branch d))
          (lit (callback-declaration-source-label d))))
  (define (print-span-declaration d)
    (list 'make-span-declaration (lit (span-declaration-name d))
          (lit (span-declaration-data-callback d))
          (lit (span-declaration-complete-callback d))
          (lit (span-declaration-source-label d))))

  ;; ---- the machine (Task 2 Step 3: declarations and make-machine, not only
  ;; nodes -- a printer total over nodes but partial over declarations reprints a
  ;; machine that verifies and is not the same machine). ----
  (define (print-machine m)
    (list 'make-machine
          (lit (machine-name m))
          (lit (machine-entry m))
          (list-of print-uint-field (machine-fields m))
          (list-of print-callback-declaration (machine-callbacks m))
          (list-of print-span-declaration (machine-spans m))
          (list-of print-error-declaration (machine-errors m))
          (list-of print-node (machine-nodes m))
          (lit (machine-default-eof-error m))
          (lit (machine-source-label m)))))
