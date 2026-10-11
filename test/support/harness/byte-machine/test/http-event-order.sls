;;; The HTTP event contract as a GRAMMAR OVER EVENTS, checked once. Every HTTP
;;; fixture lane validates its recorded event trace against this, rather than
;;; each writing its own expected sequence: a shared checker catches an
;;; ordering defect no single expected-trace case was written for.
;;;
;;; A trace is a list of entries, each either an event-name symbol
;;; (`message-begin`, `method-complete`, `version-complete`, ...) or a
;;; two-element list `(data-name fragment)` for a span-data delivery
;;; (`(method-data "GET")`). `trace-skeleton` drops the fragments and COALESCES
;;; consecutive deliveries of the same span-data event into one token, because
;;; the coalesced trace — not the raw fragment boundaries — is the thing
;;; invariant across feed schedules.
;;;
;;; The grammar is a list of terms (`one`, `star`, `rep`, `opt`; see
;;; `match-terms`). Terminals are distinct event names, so a greedy
;;; left-to-right match needs no backtracking. `http-request-grammar` grows
;;; with the fixture; the matcher does not.
(library (byte-machine test http-event-order)
  (export http-data-events http-request-grammar
          trace-skeleton event-sequence-matches? event-sequence-diagnosis)
  (import (rnrs))

  ;; The span-data events: the ones a fragment splits, so the ones `star`
  ;; quantifies and `trace-skeleton` coalesces. Grows with the fixture.
  (define http-data-events
    '(method-data target-data header-name-data header-value-data body-data
      chunk-extension-name-data chunk-extension-value-data
      trailer-name-data trailer-value-data))

  ;; A request message's event order. `method`/`target` are 1*, so their data
  ;; is `star`. The header section is zero or more header-fields — a `rep` of a
  ;; header group — then headers-complete, the body, and message-complete.
  ;; `header-value` may be empty, so its data is `star` and can be absent
  ;; entirely.
  (define http-request-grammar
    '((one message-begin)
      (star method-data)
      (one method-complete)
      (star target-data)
      (one target-complete)
      (one version-complete)
      (rep (star header-name-data) (one header-name-complete)
           (star header-value-data) (one header-value-complete))
      (one headers-complete)
      ;; the body is one of three shapes, distinguished by which events appear:
      ;;  * fixed body: body-data* with no completion event;
      ;;  * chunked body: nonzero chunks*, the zero chunk, trailers*;
      ;;  * empty: none of the above.
      ;; A chunk carries optional extensions before its chunk-header; a nonzero
      ;; chunk adds body-data* and chunk-complete, the zero chunk does not.
      (star body-data)
      (rep (rep (star chunk-extension-name-data) (one chunk-extension-name-complete)
                (opt (star chunk-extension-value-data) (one chunk-extension-value-complete)))
           (one chunk-header) (star body-data) (one chunk-complete))
      (opt (rep (star chunk-extension-name-data) (one chunk-extension-name-complete)
                (opt (star chunk-extension-value-data) (one chunk-extension-value-complete)))
           (one chunk-header))
      (rep (star trailer-name-data) (one trailer-name-complete)
           (star trailer-value-data) (one trailer-value-complete))
      (one message-complete)))

  (define (entry-name e) (if (pair? e) (car e) e))

  ;; Drop fragments; collapse a run of the same data event to one token.
  (define (trace-skeleton trace)
    (let loop ((es trace) (prev #f) (out '()))
      (cond
       ((null? es) (reverse out))
       (else
        (let ((n (entry-name (car es))))
          (if (and (memq n http-data-events) (eq? n prev))
              (loop (cdr es) prev out)                 ; coalesce the run
              (loop (cdr es) n (cons n out))))))))

  ;; Match a term list against a skeleton, returning the remaining skeleton or
  ;; #f. Terminals are distinct event names, so a greedy left-to-right match
  ;; needs no backtracking. Terms: (one E); (star E); (rep T...) — zero or more
  ;; repetitions of the sub-sequence T...; (opt T...) — zero or one. `rep`/`opt`
  ;; sub-sequences may themselves nest. `match-terms` is functional (it never
  ;; mutates the position), so a group that partially matches then fails leaves
  ;; the caller at its original position — which is what lets a greedy `rep`
  ;; stop cleanly and a following `opt`/`one` take over (the zero chunk).
  (define (match-terms terms s)
    (if (null? terms)
        s
        (let ((term (car terms)) (rest (cdr terms)))
          (case (car term)
            ((one)
             (and (pair? s) (eq? (car s) (cadr term)) (match-terms rest (cdr s))))
            ((star)
             (let skip ((s s))
               (if (and (pair? s) (eq? (car s) (cadr term)))
                   (skip (cdr s))
                   (match-terms rest s))))
            ((rep)
             (let loop ((s s))
               (let ((r (match-terms (cdr term) s)))
                 (if (and r (not (eq? r s)))     ; matched and consumed >= 1
                     (loop r)
                     (match-terms rest s)))))
            ((opt)
             (let ((r (match-terms (cdr term) s)))
               (match-terms rest (or r s))))
            (else #f)))))

  (define (event-sequence-matches? grammar skeleton)
    (let ((r (match-terms grammar skeleton))) (and r (null? r) #t)))

  ;; A reason on mismatch, for a check's detail; `#f` on match.
  (define (event-sequence-diagnosis grammar skeleton)
    (if (event-sequence-matches? grammar skeleton)
        #f
        (list 'did-not-match 'skeleton skeleton))))
