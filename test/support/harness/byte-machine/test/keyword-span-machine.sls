;;; The Milestone 11 Slice ③ span-composition proving machine (brief §7
;;; criterion 5): a method span opened BEFORE a keyword table closes at the
;;; matched keyword's length, not at a delimiter. Built only through
;;; (byte-machine graph); shared by the keyword-span lane.
;;;
;;; Shape:  span-start(method) -> keyword-table -> span-end(method) -> tail -> done
;;;
;;; The keyword table carries the brief's proper-prefix pair GET ⊂ GET-PARAMETER
;;; (the sole such pair across the 47 llhttp methods) plus MKCOL. `MKCOLA` is NOT
;;; a keyword -- it is the brief's failure/short-match input: the walk matches
;;; MKCOL (5 bytes), the sixth byte `A` does not extend toward any keyword, so the
;;; span closes at 5 and the parser reads on. Every keyword routes to the SAME
;;; span-end, so the delivered span DATA (not a distinct stop) witnesses which
;;; keyword matched and at what length.
;;;
;;; Two details the Slice ③ prototype settled and that a reader must not "tidy":
;;;  - A byte-dispatch `tail` follows the span-end so no parked state EOF-walks to
;;;    a stop: routing span-end straight to a stop trips `eof-reachable-stop`
;;;    (a parser can park on a span-end's completion substep, and its EOF walk
;;;    would then reach the stop).
;;;  - The span-ACTIVE region (kw) and the span-CLOSED region (tail) carry
;;;    SEPARATE error nodes (reject-in/eof-in vs reject-out/eof-out). Sharing one
;;;    error node across the two regions makes its incoming span-state disagree
;;;    (`inconsistent-span-state`, decision 0029's merge rule).
(library (byte-machine test keyword-span-machine)
  (export make-keyword-span-machine keyword-span-keywords)
  (import (rnrs) (byte-machine graph))

  ;; The keywords and their (shared) span-end target, in table order. GET is a
  ;; proper prefix of GET-PARAMETER; MKCOL is the short-match / MKCOLA case.
  (define keyword-span-keywords
    '("GET" "GET-PARAMETER" "MKCOL"))

  (define (string->bytes s) (map char->integer (string->list s)))
  (define (entry s) (make-keyword-entry (string->bytes s) 'sclose #f))

  (define (make-keyword-span-machine)
    (make-machine 'kwspan 'sstart '()
      (list (make-callback-declaration 'ondata 'span-data #t '() #f #f))
      (list (make-span-declaration 'method 'ondata #f #f))
      (list (make-error-declaration 'default-eof 'eof "unexpected end of input" #f)
            (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f)
            (make-error-declaration 'incomplete 'truncated-keyword "incomplete keyword at end of input" #f))
      (list (make-span-start-node 'sstart 'method 'kw #f)
            (make-keyword-table-node 'kw
              (map entry keyword-span-keywords)
              (make-edge 'reject-in 'reexecute)  ; no-match inside the span
              'eof-in                            ; EOF mid-keyword, span still open
              #f #f)
            (make-span-end-node 'sclose 'method 'tail #f)
            ;; the span has closed; consume the delimiter the keyword reexecuted
            (make-byte-dispatch-node 'tail
              (list (make-byte-case (make-byte-range-matcher 0 255) (make-edge 'done 'advance) #f))
              (make-edge 'reject-out 'reexecute) 'eof-out #f)
            (make-stop-node 'done #f)
            ;; span-active region's errors
            (make-error-node 'eof-in 'incomplete #f)
            (make-error-node 'reject-in 'rejected #f)
            ;; span-closed region's errors (separate, or the merge disagrees)
            (make-error-node 'eof-out 'incomplete #f)
            (make-error-node 'reject-out 'rejected #f))
      'default-eof #f)))
