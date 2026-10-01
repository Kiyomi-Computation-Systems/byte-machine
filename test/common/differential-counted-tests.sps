;;; Milestone 6 Slice ①: the counted consume in BOTH lanes (design §6; decision
;;; 0030). Every case asserts the EXPECTED tuple, state and field value per lane
;;; -- labelled by lane, so a pin can name which lane went wrong -- and only then
;;; the lanes against each other. §22.3:1254's four cases, §22.5:1278-1281's
;;; schedules, §25:1602's truncation, §25:1609's two-message feed, the u64 count,
;;; the two ordering witnesses decision 0030 item 1 leaves observable, the
;;; only-consumer machine the reached-declaration walk owes, the structural
;;; witness for §25:1607, and Slice ②'s placement oracle validated as one case.
(import (rnrs) (rnrs eval) (only (chezscheme) load)
        (byte-machine test harness)
        (byte-machine test error-projection)
        (byte-machine test counted-machine)
        (byte-machine graph) (byte-machine verify)
        (byte-machine interpret) (byte-machine compile) (byte-machine runtime))

(harness-begin "differential.counted")

(define tmpdir (or (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")
                   (assertion-violation 'differential-counted "no tmpdir" #f)))

(define (generated m name binding libname)
  (let ((f (string-append tmpdir "/generated-" name ".sls")))
    (call-with-port (open-file-output-port f (file-options no-fail))
      (lambda (p) (emit-machine (compile-machine m '()) binding p)))
    (load f)
    (eval binding (environment (list 'generated libname)))))

(define m-loop (make-counted-machine))
(define cm-ref (make-interpreted-machine (verify-machine m-loop)))
(define cm-gen (generated m-loop "counted-loop" 'countedm-parser 'countedm))

(define (str->bv s) (u8-list->bytevector (map char->integer (string->list s))))
(define (bytes . bs) (u8-list->bytevector bs))

;; The result tuple through §22.4:1271's projection, plus what the tuple cannot
;; carry: where the parser is parked and what the count reads (F13 of the plan --
;; a need-input result's `next` is always #f, so the parked node is observed
;; through parser-state-name).
(define (snapshot r p field)
  (list (and r (parser-result-status r))
        (and r (parser-result-consumed r))
        (and r (parser-result-stream-offset r))
        (and r (project-error (parser-result-error r)))
        (parser-lifecycle p)
        (parser-state-name p)
        (parser-field-ref p field)))

;; A script is a list of steps: (feed "str") | (slice bv start end) | (finish) | (reset).
(define (run cm script field)
  (let ((p (make-parser cm '() #f)))
    (let loop ((ss script) (out '()))
      (if (null? ss) (reverse out)
          (let ((s (car ss)))
            (let ((r (case (car s)
                       ((feed) (let ((bv (str->bv (cadr s)))) (parser-feed! p bv 0 (bytevector-length bv))))
                       ((slice) (parser-feed! p (cadr s) (caddr s) (cadddr s)))
                       ((finish) (parser-finish! p))
                       ((reset) (parser-reset! p) #f)
                       (else (assertion-violation 'run "unknown step" s)))))
              (loop (cdr ss) (cons (snapshot r p field) out))))))))

;; Drive both lanes; assert `expected` (a list of snapshots, one per step) against
;; EACH lane by name, then the lanes against each other.
(define (both label script expected . field)
  (let* ((f (if (null? field) 'len (car field)))
         (a (run cm-ref script f))
         (b (run cm-gen script f)))
    (check-equal (string-append "interpreter: " label) a expected)
    (check-equal (string-append "generated: " label) b expected)
    (check-equal (string-append "the lanes agree: " label) a b)))

(define (ok status consumed offset state len)
  (list status consumed offset #f 'ready state len))

(harness-group "counted consume with zero, partial, exact and surplus input (§22.3:1254)"
  (lambda ()
    (harness-case "zero: 0:, transitions without consuming and completes the message"
      (lambda ()
        (both "zero body" '((feed "0:,")) (list (ok 'need-input 3 3 'idle 0)))))
    (harness-case "partial: 3:ab parks mid-body with the remaining count, c, completes it"
      (lambda ()
        (both "partial body" '((feed "3:ab") (feed "c,"))
              (list (ok 'need-input 4 4 'body 1) (ok 'need-input 2 6 'idle 0)))))
    (harness-case "exact: 3:abc completes the count and continues to the delimiter in the same feed"
      (lambda ()
        ;; Count completion wins by construction (decision 0030 item 2): the
        ;; parser is parked on `comma`, not on `body` with a zero count.
        (both "exact body" '((feed "3:abc")) (list (ok 'need-input 5 5 'comma 0)))))
    (harness-case "surplus: 3:abc,0:, in one feed reports both messages in one result (§25:1609)"
      (lambda ()
        (both "two messages, one feed" '((feed "3:abc,0:,")) (list (ok 'need-input 9 9 'idle 0)))))
    (harness-case "surplus into a rejection: the byte after the body is dispatched, not consumed as body"
      (lambda ()
        ;; `d` reaches the delimiter dispatch and is rejected AT offset 5; a
        ;; commit of `(- end pos)` instead of the min would swallow it.
        (both "surplus into a rejection" '((feed "3:abcd"))
              (list (list 'error 5 5 '(machine unexpected-byte "unexpected byte" reject 5 byte #f #f)
                          'error 'reject 0)))))))

(harness-group "every schedule of one message (§22.5:1278-1281)"
  (lambda ()
    (harness-case "every split point of 3:abc, ends at idle with the count cleared"
      (lambda ()
        (let ((bv (str->bv "3:abc,")) (seen 0))
          (do ((k 0 (+ k 1))) ((> k 6))
            (set! seen (+ seen 1))
            (let ((a (run cm-ref (list (list 'slice bv 0 k) (list 'slice bv k 6)) 'len))
                  (b (run cm-gen (list (list 'slice bv 0 k) (list 'slice bv k 6)) 'len)))
              (for-each
               (lambda (lane r)
                 (let ((tag (string-append "split at " (number->string k) ": " lane ": ")))
                   (check-equal (string-append tag "consumed in total") (+ (cadr (car r)) (cadr (cadr r))) 6)
                   (check-equal (string-append tag "ends at idle") (list-ref (cadr r) 5) 'idle)
                   (check-equal (string-append tag "count cleared") (list-ref (cadr r) 6) 0)))
               '("interpreter" "generated") (list a b))
              (check-equal (string-append "split at " (number->string k) ": the lanes agree") a b)))
          (check-equal "seven split points driven" seen 7))))
    (harness-case "leading, trailing and intermediate empty feeds (§22.5:1279)"
      (lambda ()
        (both "leading empty feed" '((feed "") (feed "3:abc,"))
              (list (ok 'need-input 0 0 'idle 0) (ok 'need-input 6 6 'idle 0)))
        (both "trailing empty feed" '((feed "3:abc,") (feed ""))
              (list (ok 'need-input 6 6 'idle 0) (ok 'need-input 0 6 'idle 0)))
        ;; An empty feed at a body with a positive count is need-input with nothing
        ;; consumed and the count untouched (§11.1:638).
        (both "empty feed mid-body" '((feed "3:") (feed "") (feed "abc,"))
              (list (ok 'need-input 2 2 'body 3) (ok 'need-input 0 2 'body 3) (ok 'need-input 4 6 'idle 0)))))
    (harness-case "sub-slices of a larger bytevector with unrelated prefix and suffix bytes (§22.5:1280-1281)"
      (lambda ()
        (let ((bv (str->bv "XX3:abc,YY")))
          (both "one sub-slice" (list (list 'slice bv 2 8)) (list (ok 'need-input 6 6 'idle 0)))
          (both "two sub-slices" (list (list 'slice bv 2 5) (list 'slice bv 5 8))
                (list (ok 'need-input 3 3 'body 2) (ok 'need-input 3 6 'idle 0))))))))

(harness-group "EOF: truncation and the clean end (§25:1602, §12.4:725)"
  (lambda ()
    (harness-case "EOF after 3:ab is the truncation error, eof at offset 4, in both lanes"
      (lambda ()
        (both "truncation mid-body" '((feed "3:ab") (finish))
              (list (ok 'need-input 4 4 'body 1)
                    (list 'error 0 4 '(machine eof "truncated message" trunc 4 eof #f #f) 'error 'trunc 1)))))
    (harness-case "EOF with the whole count still owed is the same truncation"
      (lambda ()
        (both "truncation with nothing consumed" '((feed "3:") (finish))
              (list (ok 'need-input 2 2 'body 3)
                    (list 'error 0 2 '(machine eof "truncated message" trunc 2 eof #f #f) 'error 'trunc 3)))))
    (harness-case "EOF between messages is finished; EOF before the delimiter is truncation"
      (lambda ()
        (both "fresh parser finishes" '((finish)) (list (list 'finished 0 0 #f 'finished 'fin 0)))
        (both "finish after a whole message" '((feed "3:abc,") (finish))
              (list (ok 'need-input 6 6 'idle 0) (list 'finished 0 6 #f 'finished 'fin 0)))
        (both "finish parked on the delimiter" '((feed "3:abc") (finish))
              (list (ok 'need-input 5 5 'comma 0)
                    (list 'error 0 5 '(machine eof "truncated message" trunc 5 eof #f #f) 'error 'trunc 0)))))))

(harness-group "reset restores the count (§12.5:738)"
  (lambda ()
    (harness-case "a reset mid-body restores the declared initial and the entry"
      (lambda ()
        (both "reset mid-body" '((feed "3:ab") (reset) (feed "3:abc,"))
              (list (ok 'need-input 4 4 'body 1)
                    (list #f #f #f #f 'ready 'idle 0)
                    (ok 'need-input 6 6 'idle 0)))))))

;; The smaller machines are built INSIDE their cases: a render that raises is
;; then a case's FAIL record and not a crash of the whole program, which is what
;; lets the reached-declaration pin below name the only-consumer case.
(harness-group "a u64 count above the fixnum range (§15:856)"
  (lambda ()
    (harness-case "the subtraction is exact bignum arithmetic in both lanes"
      (lambda ()
        (define m-big (make-big-count-machine))
        (define big-ref (make-interpreted-machine (verify-machine m-big)))
        (define big-gen (generated m-big "counted-big" 'bigcount-parser 'bigcount))
        (for-each (lambda (cm lane)
                    (let ((p (make-parser cm '() #f)))
                      (parser-feed! p (bytes 0 65 66 67) 0 4)
                      (check-equal (string-append lane ": the remaining count")
                                   (parser-field-ref p 'big) (- 9223372036854775808 3))
                      (check-equal (string-append lane ": parked on the body") (parser-state-name p) 'body)))
                  (list big-ref big-gen) '("interpreter" "generated"))))))

(harness-group "the two ordering witnesses (decision 0030 item 1)"
  (lambda ()
    (harness-case "after 0: the parser is parked on the delimiter dispatch, not the body (the feed order)"
      (lambda ()
        (for-each (lambda (cm lane)
                    (let ((p (make-parser cm '() #f)))
                      (parser-feed! p (str->bv "0:") 0 2)
                      (check-equal (string-append lane ": parked on the delimiter after 0:")
                                   (parser-state-name p) 'comma)))
                  (list cm-ref cm-gen) '("interpreter" "generated"))))
    (harness-case "a fresh parser whose entry is a zero-count consume finishes through next, not the EOF route (the finish order)"
      (lambda ()
        (define m-zero (make-entry-zero-machine))
        (define zero-ref (make-interpreted-machine (verify-machine m-zero)))
        (define zero-gen (generated m-zero "counted-entry-zero" 'entryzero-parser 'entryzero))
        (for-each (lambda (cm lane)
                    (let* ((p (make-parser cm '() #f)) (r (parser-finish! p)))
                      (check-equal (string-append lane ": the finish reports the empty-body error")
                                   (and (parser-result-error r) (parser-error-reason (parser-result-error r)))
                                   "empty body rejected")))
                  (list zero-ref zero-gen) '("interpreter" "generated"))))))

(harness-group "the only-consumer machine (compile.sls's reached-declaration walk)"
  (lambda ()
    (harness-case "the only-consumer machine renders, loads and runs"
      (lambda ()
        ;; Its ONLY default-EOF consumer is the counted consume, and no error node
        ;; names that declaration: a walk that does not credit the kind drops the
        ;; declaration from the errs table and render-machine raises on a
        ;; machine the verifier accepted.
        (let* ((m (make-only-consumer-machine))
               (v (verify-machine m)))
          (check "verifies clean" (verification-ok? v))
          (let ((ref (make-interpreted-machine v))
                (gen (generated m "counted-only" 'onlycc-parser 'onlycc)))
            (for-each (lambda (cm lane)
                        (let* ((p (make-parser cm '() #f)) (r (parser-feed! p (bytes 0 65) 0 2))
                               (f (parser-finish! p)))
                          (check-equal (string-append lane ": parked mid-body") (parser-result-status r) 'need-input)
                          (check-equal (string-append lane ": EOF mid-body takes the machine default")
                                       (and (parser-result-error f) (parser-error-reason (parser-result-error f)))
                                       "unexpected end of input")))
                      (list ref gen) '("interpreter" "generated"))))))))

(harness-group "the structural witness: one count-step per feed (§25:1607, design §4.7)"
  (lambda ()
    (harness-case "a body of one thousand bytes is one op message per feed, whether partial or complete"
      (lambda ()
        ;; The op closure sits in slot 2 of the compiled machine's tagged vector
        ;; -- the shipped practice for a test that needs an internal. A body
        ;; consumed one byte per message would pass every behavioural lane, and
        ;; so would an arm that re-asks the op after a partial commit; the
        ;; PARTIAL feed is where that second shape shows.
        (let* ((op (vector-ref cm-ref 2))
               (hits 0)
               (counting (make-compiled-machine
                          (lambda (msg . args)
                            (when (eq? msg 'count-step) (set! hits (+ hits 1)))
                            (apply op msg args))))
               (p (make-parser counting '() #f))
               (header (str->bv "1000:"))
               (body (make-bytevector 1000 65)))
          (parser-feed! p header 0 5)
          (check-equal "the header asks the op once, at the body's zero-length start" hits 1)
          (set! hits 0)
          (parser-feed! p body 0 999)
          (check-equal "one count-step per feed" hits 1)
          (check-equal "999 committed" (parser-field-ref p 'len) 1)
          (set! hits 0)
          (parser-feed! p body 999 1000)
          (check-equal "one count-step completes the body" hits 1)
          (check-equal "the body was consumed" (parser-field-ref p 'len) 0)
          (check-equal "parked on the delimiter" (parser-state-name p) 'comma))))))

;; --- Slice ②'s placement oracle, validated here as one case (design §7 oracle 3;
;; the plan's F10) ------------------------------------------------------------------
;;
;; The same loop with `body` wrapped in a span that has BOTH callbacks (the
;; recorder records `complete` only through the completion closure). Under the
;; byte-at-a-time schedule of `3:abc,` the completion event must land in the feed
;; that delivered `c` -- count completion wins, execution continues into the span
;; end in the same feed -- and the `,` feed records nothing. Asserted per feed as
;; a value in each lane, then across lanes; a symmetric wrong reading of 0030
;; item 2 puts the completion in the `,` feed in BOTH lanes and agrees with itself.
(define (make-span-loop)
  (make-machine 'spanloop 'idle
                (list (make-uint-field 'len 32 0 #f))
                (list (make-callback-declaration 'on-data 'span-data #t '() #f #f)
                      (make-callback-declaration 'on-done 'span-complete #t '() #f #f))
                (list (make-span-declaration 'sp 'on-data 'on-done #f))
                (list (make-error-declaration 'default-eof 'eof "unexpected end of input" #f)
                      (make-error-declaration 'truncated 'eof "truncated message" #f)
                      (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f)
                      (make-error-declaration 'too-long 'unexpected-byte "length overflow" #f))
                (list (make-byte-dispatch-node 'idle
                        (list (make-byte-case (make-byte-range-matcher 48 57) (make-edge 'len 'reexecute) #f))
                        (make-edge 'reject 'reexecute) 'fin #f)
                      (make-integer-accumulate-node 'len 'len 10 'len (make-edge 'colon 'reexecute) 'over 'trunc #f)
                      (make-byte-dispatch-node 'colon
                        (list (make-byte-case (make-exact-byte-matcher 58) (make-edge 'open 'advance) #f))
                        (make-edge 'reject 'reexecute) 'trunc #f)
                      (make-span-start-node 'open 'sp 'body #f)
                      ;; Its own truncation node: the shared one is reached with no
                      ;; span open, and one node cannot carry both states.
                      (make-counted-consume-node 'body 'len 'close 'trunc2 #f)
                      (make-span-end-node 'close 'sp 'comma #f)
                      (make-byte-dispatch-node 'comma
                        (list (make-byte-case (make-exact-byte-matcher 44) (make-edge 'clear 'advance) #f))
                        (make-edge 'reject 'reexecute) 'trunc #f)
                      (make-field-action-node 'clear 'clear '(len) 'idle #f #f)
                      (make-finish-node 'fin #f)
                      (make-error-node 'trunc 'truncated #f)
                      (make-error-node 'trunc2 'truncated #f)
                      (make-error-node 'over 'too-long #f)
                      (make-error-node 'reject 'rejected #f))
                'default-eof #f))

(define (recorder)
  ;; One recorder PER LANE, each with its own accumulator; `events` returns and
  ;; clears what was recorded since the last call, so a caller reads per feed.
  (let ((trace '()))
    (list (lambda (ps ux bv from to) (set! trace (cons (list 'data (- to from)) trace)) callback-continue)
          (lambda (ps ux) (set! trace (cons 'complete trace)) callback-continue)
          (lambda () (let ((t (reverse trace))) (set! trace '()) t)))))

(harness-group "Slice ②'s placement oracle, one case (§10.6:603)"
  (lambda ()
    (harness-case "under the byte-at-a-time schedule the completion lands in the feed that delivered the last body byte"
      (lambda ()
        (let* ((m (make-span-loop))
               (v (verify-machine m)))
          (check "the span loop verifies clean" (verification-ok? v))
          (let* ((ref (make-interpreted-machine v))
                 (gen (generated m "counted-span" 'spanloop-parser 'spanloop))
                 (per-lane
                  (map (lambda (cm)
                         (let* ((r (recorder))
                                (p (make-parser cm (list (list 'on-data (car r)) (list 'on-done (cadr r))) 'ctx))
                                (events (caddr r)))
                           ;; An explicit left-to-right loop: `map`'s order of
                           ;; application is unspecified, and this schedule IS
                           ;; the order.
                           (let loop ((cs (string->list "3:abc,")) (out '()))
                             (if (null? cs) (reverse out)
                                 (begin (parser-feed! p (bytes (char->integer (car cs))) 0 1)
                                        (loop (cdr cs) (cons (events) out)))))))
                       (list ref gen))))
            (for-each (lambda (evs lane)
                        (check-equal (string-append lane ": the c feed delivers the last fragment and the completion")
                                     (list-ref evs 4) '((data 1) complete))
                        (check-equal (string-append lane ": the , feed records nothing")
                                     (list-ref evs 5) '())
                        (check-equal (string-append lane ": a and b each flush one fragment at the boundary")
                                     (list (list-ref evs 2) (list-ref evs 3)) '(((data 1)) ((data 1)))))
                      per-lane '("interpreter" "generated"))
            (check-equal "the lanes agree on the whole per-feed trace" (car per-lane) (cadr per-lane))))))))

(harness-finish)
