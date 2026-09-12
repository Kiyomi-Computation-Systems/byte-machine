;;; The §21.3 event contract as a GRAMMAR OVER EVENTS, checked once (§4.9 item 1,
;;; owner-approved). Every HTTP fixture lane validates its recorded event trace
;;; against this, rather than each writing its own expected sequence: a shared
;;; checker catches an ordering defect no single expected-trace case was written
;;; for (the reason the scope addition was approved).
;;;
;;; A trace is a list of entries, each either an event-name symbol
;;; (`message-begin`, `method-complete`, `version-complete`, ...) or a
;;; two-element list `(data-name fragment)` for a span-data delivery
;;; (`(method-data "GET")`). `trace-skeleton` drops the fragments and COALESCES
;;; consecutive deliveries of the same span-data event into one token, because
;;; §22.5:1287 makes the coalesced trace — not the raw fragment boundaries —
;;; the thing invariant across feed schedules.
;;;
;;; The grammar is a list of terms, each `(one E)` or `(star E)`. Terminals are
;;; distinct event names, so a greedy left-to-right match needs no backtracking.
;;; MILESTONE 8 SLICE ①: the request line, ending at `version-complete`. Later
;;; slices EXTEND `http-request-grammar` (headers, body, chunks, trailers, the
;;; message loop) — the grammar grows, the matcher does not.
(library (byte-machine test http-event-order)
  (export http-data-events http-request-grammar
          trace-skeleton event-sequence-matches? event-sequence-diagnosis)
  (import (rnrs))

  ;; The span-data events: the ones a fragment splits, so the ones `star`
  ;; quantifies and `trace-skeleton` coalesces. Grows with the fixture.
  (define http-data-events
    '(method-data target-data header-name-data header-value-data))

  ;; §21.3's no-body message event order (Slices ① and ②). `method`/`target`
  ;; are 1*, so their data is `star`. The header section is zero or more
  ;; header-fields — a `rep` of a header group — then headers-complete and, with
  ;; no body yet, message-complete. `header-value` may be empty (§21.2:1097), so
  ;; its data is `star` and can be absent entirely. Slice ③ inserts the body
  ;; between headers-complete and message-complete.
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
  ;; needs no backtracking. Terms: (one E), (star E), (rep T...) — zero or more
  ;; repetitions of the sub-sequence T....
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
            (else #f)))))

  (define (event-sequence-matches? grammar skeleton)
    (let ((r (match-terms grammar skeleton))) (and r (null? r) #t)))

  ;; A reason on mismatch, for a check's detail; `#f` on match.
  (define (event-sequence-diagnosis grammar skeleton)
    (if (event-sequence-matches? grammar skeleton)
        #f
        (list 'did-not-match 'skeleton skeleton))))
