;;; interpreter ≡ generated over the span an error abandons.
;;;
;;; An error neither flushes a final partial fragment nor synthesizes a
;;; completion. So the bytes a span took in the feed that failed are never
;;; handed to the application, and an embedder that counts a span's bytes as
;;; they are delivered -- a size limit on a request target, say -- would get an
;;; answer that depends on where the network split the input. The error
;;; therefore records the span it abandoned and the stream offset where its
;;; withheld bytes begin:
;;;
;;;   parser-error-span        -- the span active when the error stopped the parser
;;;   parser-error-span-offset -- where its withheld bytes begin
;;;
;;; so `[span-offset, error-offset)` is exactly what the error withheld, and every
;;; byte the span took before `span-offset` went out in an earlier fragment.
;;;
;;; THE PROPERTY THIS LANE EXISTS FOR is the last group: under every schedule of
;;; one input, the delivered fragments followed by the withheld range are the
;;; span's bytes up to the error, in both lanes. The groups above it pin each
;;; path to that property separately, with expected values, so a defect names
;;; the path it is on rather than only the schedule that happened to reach it.
(import (rnrs) (rnrs eval) (only (chezscheme) load)
        (byte-machine test harness)
        (byte-machine test error-projection)
        (byte-machine graph) (byte-machine verify)
        (byte-machine interpret) (byte-machine compile) (byte-machine runtime))

(harness-begin "differential.abandoned-span")

(define tmpdir (or (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")
                   (assertion-violation 'differential-abandoned-span "no tmpdir" #f)))

;; `A` opens a token span, `Z` ends it, and two bytes refuse it from inside:
;;
;;   `!` REEXECUTES into the error, so the error sits AT the refused byte
;;       (position kind `byte`) and the byte is not taken;
;;   `#` ADVANCES into it, so the parser takes the byte and the error sits
;;       after it (`boundary`) -- the byte is inside the withheld range.
;;
;; After a token, `Z` (the reexecuted delimiter) leads to `next`, where `A` opens
;; another token and `.` stops. A second token is what lets a span OPEN in the
;; middle of a feed whose stream offset is not 0, the one shape in which a slice
;; offset, a stream offset and the feed's own start all differ.
;;
;; *** THE COMPLETION CALLBACK IS DECLARED FIRST *** so the data callback's slot
;; is 1, the same defence differential-span-tests.sps carries: a lane resolving
;; "the data slot" to the constant 0 would invoke the completion callback here.
(define abm
  (make-machine 'abm 'start '()
    (list (make-callback-declaration 'ondone 'span-complete #f '() #f #f)
          (make-callback-declaration 'ondata 'span-data #t '() #f #f))
    (list (make-span-declaration 'tok 'ondata 'ondone #f))
    (list (make-error-declaration 'default-eof 'eof "unexpected end of input" #f)
          (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f)
          (make-error-declaration 'refused 'bad-token-byte "refused token byte" #f)
          (make-error-declaration 'truncated 'eof "token truncated" #f))
    (list (make-byte-dispatch-node 'start
            (list (make-byte-case (make-exact-byte-matcher 65) (make-edge 'open 'advance) #f))
            (make-edge 'reject 'reexecute) 'fin #f)
          (make-span-start-node 'open 'tok 'body #f)
          (make-byte-dispatch-node 'body
            (list (make-byte-case (make-exact-byte-matcher 90) (make-edge 'close 'reexecute) #f)
                  (make-byte-case (make-exact-byte-matcher 33) (make-edge 'bad 'reexecute) #f)
                  (make-byte-case (make-exact-byte-matcher 35) (make-edge 'bad 'advance) #f))
            (make-edge 'body 'advance) 'trunc #f)
          (make-span-end-node 'close 'tok 'after #f)
          (make-byte-dispatch-node 'after
            (list (make-byte-case (make-exact-byte-matcher 90) (make-edge 'next 'advance) #f))
            (make-edge 'reject 'reexecute) 'fin #f)
          (make-byte-dispatch-node 'next
            (list (make-byte-case (make-exact-byte-matcher 65) (make-edge 'open 'advance) #f)
                  (make-byte-case (make-exact-byte-matcher 46) (make-edge 'done 'advance) #f))
            (make-edge 'reject 'reexecute) 'fin #f)
          (make-stop-node 'done #f)
          (make-finish-node 'fin #f)
          (make-error-node 'bad 'refused #f)
          (make-error-node 'trunc 'truncated #f)
          (make-error-node 'reject 'rejected #f))
    'default-eof #f))

(define v-abm (verify-machine abm))

(define cm-ref (make-interpreted-machine v-abm))
(define cm-gen
  (let ((f (string-append tmpdir "/generated-abandoned-span.sls")))
    (call-with-port (open-file-output-port f (file-options no-fail))
      (lambda (p) (emit-machine (compile-machine abm '()) 'abm-parser p)))
    (load f)
    (eval 'abm-parser (environment '(generated abm)))))

(define (b s) (string->utf8 s))
(define (slice bv from to)
  (let ((out (make-bytevector (- to from))))
    (bytevector-copy! bv from out 0 (- to from))
    out))

;; One recorder per lane. The data callback COPIES its range inside its own
;; dynamic extent and then answers from `answers`, one per data invocation,
;; continuing once the list is spent; the completion callback answers
;; `done-answer` every time.
(define (make-lane cm answers done-answer)
  (let* ((trace '()) (pending answers)
         (p (make-parser cm
                         (list (list 'ondata
                                     (lambda (ps ux bv from to)
                                       (set! trace (cons (slice bv from to) trace))
                                       (if (null? pending) callback-continue
                                           (let ((a (car pending)))
                                             (set! pending (cdr pending)) a))))
                               (list 'ondone
                                     (lambda (ps ux)
                                       (set! trace (cons 'complete trace))
                                       done-answer)))
                         'ctx)))
    (list p (lambda () (reverse trace)))))

;; The compared tuple. `project-error` carries the two span members, so every
;; tuple below compares the abandoned span across the lanes too.
(define (rfields r p)
  (list (parser-result-status r) (parser-result-next r) (parser-result-consumed r)
        (parser-result-stream-offset r) (project-error (parser-result-error r))
        (parser-lifecycle p)))

;; A script of steps: `(feed BV)`, `(feed-slice BV START END)`, `(finish)`,
;; `(resume)`, `(reset)`. Answers the result tuples, the fragment trace, and the
;; raw error records -- the last so a case can read the two accessors directly
;; rather than only through the projection.
(define (run lane script)
  (let ((p (car lane)) (trace-of (cadr lane)))
    (let loop ((ss script) (out '()) (errs '()))
      (if (null? ss)
          (list (reverse out) (trace-of) (reverse errs))
          (let* ((s (car ss))
                 (r (case (car s)
                      ((feed) (parser-feed! p (cadr s) 0 (bytevector-length (cadr s))))
                      ((feed-slice) (parser-feed! p (cadr s) (caddr s) (cadddr s)))
                      ((finish) (parser-finish! p))
                      ((resume) (parser-resume! p) #f)
                      ((reset) (parser-reset! p) #f)
                      (else (assertion-violation 'run "unknown step" s)))))
            (if r
                (loop (cdr ss) (cons (rfields r p) out)
                      (cons (parser-result-error r) errs))
                (loop (cdr ss) out errs)))))))

(define (both script answers done-answer)
  (let ((a (run (make-lane cm-ref answers done-answer) script))
        (g (run (make-lane cm-gen answers done-answer) script)))
    (list a g (equal? (list (car a) (cadr a)) (list (car g) (cadr g))))))

;; The step's tuple, the trace, and the step's raw error, from lane `which`.
(define (tuple-at r which n) (list-ref (car (which r)) n))
(define (trace-of r which) (cadr (which r)))
(define (error-at r which n) (list-ref (caddr (which r)) n))
(define (ref r) (car r))
(define (gen r) (cadr r))

(define too-long (make-callback-failure 'too-long 'the-detail))

(harness-group "the fixture verifies clean"
  (lambda ()
    (harness-case "no diagnostics"
      (lambda ()
        ;; Stated first: a machine the verifier refused would make every case
        ;; below vacuous rather than red.
        (check-equal "no diagnostics"
                     (map diagnostic-code (verification-diagnostics v-abm)) '())))))

(harness-group "an error with no span open records none"
  (lambda ()
    (harness-case "a refusal before any span opens"
      (lambda ()
        (let ((r (both (list (list 'feed (b "!"))) '() callback-continue)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "the error records no span"
                       (tuple-at r ref 0)
                       '(error 0 0 0 (machine unexpected-byte "unexpected byte" reject 0 byte
                                      #f #f)
                         error)))))
    (harness-case "a span that closed before the error leaves nothing behind"
      (lambda ()
        ;; `x` is delivered and the span completes at `Z`; `!` is then refused at
        ;; `next`. The span state was cleared by the completion substep, and the
        ;; error must not read a span that is no longer open.
        (let ((r (both (list (list 'feed (b "AxZ!"))) '() callback-continue)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "delivered and completed" (trace-of r ref) (list (b "x") 'complete))
          (check-equal "the error records no span"
                       (tuple-at r ref 0)
                       '(error 3 3 3 (machine unexpected-byte "unexpected byte" reject 3 byte
                                      #f #f)
                         error))
          (check-equal "both accessors answer #f, in both lanes"
                       (map (lambda (e) (list (parser-error-span e) (parser-error-span-offset e)))
                            (list (error-at r ref 0) (error-at r gen 0)))
                       '((#f #f) (#f #f))))))
    (harness-case "and in a later feed, where an offset computed anyway would not be 0"
      (lambda ()
        ;; The span closed in the first feed and the refusal comes in the
        ;; second, at stream offset 3. An offset computed for an error with no
        ;; span open would read 3 here, not the 0 a first feed gives -- which is
        ;; what separates that defect from a constructor building 0.
        (let ((r (both (list (list 'feed (b "AxZ")) (list 'feed (b "!")))
                       '() callback-continue)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "the error records no span"
                       (tuple-at r ref 1)
                       '(error 0 0 3 (machine unexpected-byte "unexpected byte" reject 3 byte
                                      #f #f)
                         error)))))))

(harness-group "a machine error abandons the span it cut off"
  (lambda ()
    (harness-case "refused AT the byte: the withheld bytes are the span's own"
      (lambda ()
        ;; The span opens at offset 1 and nothing has been delivered when `!` is
        ;; refused at offset 3, so the withheld range is the whole span: [1,3).
        (let ((r (both (list (list 'feed (b "Axy!"))) '() callback-continue)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "nothing was delivered" (trace-of r ref) '())
          (check-equal "the error names the span and where its bytes begin"
                       (tuple-at r ref 0)
                       '(error 3 3 3 (machine bad-token-byte "refused token byte" bad 3 byte
                                      tok 1)
                         error))
          (check-equal "read through the accessors, in both lanes"
                       (map (lambda (e) (list (parser-error-span e) (parser-error-span-offset e)))
                            (list (error-at r ref 0) (error-at r gen 0)))
                       '((tok 1) (tok 1))))))
    (harness-case "refused before the span takes a byte: nothing is withheld"
      (lambda ()
        ;; The span opens at offset 1 and `!` is refused at 1, so the error
        ;; abandons the span with an empty range, [1,1). Empty is not "no span".
        (let ((r (both (list (list 'feed (b "A!"))) '() callback-continue)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "the error"
                       (tuple-at r ref 0)
                       '(error 1 1 1 (machine bad-token-byte "refused token byte" bad 1 byte
                                      tok 1)
                         error)))))
    (harness-case "refused AFTER taking the byte: the refused byte is withheld too"
      (lambda ()
        ;; `#` advances into the error, so the parser took it: the error is at 4
        ;; (`boundary`) and the withheld range [1,4) ends with the refused byte.
        ;; Whether that byte belongs to the token is the grammar's question; the
        ;; record says only what the parser took.
        (let ((r (both (list (list 'feed (b "Axy#"))) '() callback-continue)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "the error names the span and where its bytes begin"
                       (tuple-at r ref 0)
                       '(error 4 4 4 (machine bad-token-byte "refused token byte" bad 4 boundary
                                      tok 1)
                         error)))))
    (harness-case "a span carried across a feed: withheld from the failing feed's start"
      (lambda ()
        ;; The first feed's boundary flush delivers `xy`; the second feed begins
        ;; at stream offset 3, so that is where the withheld bytes `zw` begin.
        (let ((r (both (list (list 'feed (b "Axy")) (list 'feed (b "zw!")))
                       '() callback-continue)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "the flush delivered the first feed's bytes" (trace-of r ref) (list (b "xy")))
          (check-equal "the error"
                       (tuple-at r ref 1)
                       '(error 2 2 5 (machine bad-token-byte "refused token byte" bad 5 byte
                                      tok 3)
                         error)))))
    (harness-case "a span opened inside a sub-slice: the slice offset becomes a stream offset"
      (lambda ()
        ;; The second feed is `..Ayz!` from slice index 2, at stream offset 3.
        ;; The span opens at slice index 3, which is stream offset 4 -- and 4 is
        ;; none of the slice offset (3), the feed's stream offset (3), the offset
        ;; relative to the slice start (1), or the two added (6).
        (let ((r (both (list (list 'feed (b "AxZ"))
                             (list 'feed-slice (b "..Ayz!") 2 6))
                       '() callback-continue)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "the first token was delivered and completed"
                       (trace-of r ref) (list (b "x") 'complete))
          (check-equal "the error"
                       (tuple-at r ref 1)
                       '(error 5 3 6 (machine bad-token-byte "refused token byte" bad 6 byte
                                      tok 4)
                         error)))))))

(harness-group "a data callback that fails was handed its bytes: nothing is withheld"
  (lambda ()
    (harness-case "failing at the span end"
      (lambda ()
        ;; The span end hands `xy` to the data callback, which fails. The span is
        ;; still open -- its completion never runs -- so the error records it,
        ;; but the bytes went out: the withheld range is empty, [3,3). A mark
        ;; left at the fragment's start would report [1,3), the very bytes the
        ;; callback was just handed.
        (let ((r (both (list (list 'feed (b "AxyZ."))) (list too-long) callback-continue)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "the callback saw the fragment" (trace-of r ref) (list (b "xy")))
          (check-equal "the error"
                       (tuple-at r ref 0)
                       '(error 3 3 3 (callback too-long "callback failure" close 3 boundary
                                      tok 3)
                         error))
          (check-equal "the application's detail passes through, in both lanes"
                       (map parser-error-detail (list (error-at r ref 0) (error-at r gen 0)))
                       '(the-detail the-detail)))))
    (harness-case "failing at a feed-boundary flush"
      (lambda ()
        ;; The flush is not a machine step, so its error names the node the
        ;; parser is parked on and carries the data callback's slot as its state
        ;; id. The bytes went out here too.
        (let ((r (both (list (list 'feed (b "Axy"))) (list too-long) callback-continue)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "the callback saw the fragment" (trace-of r ref) (list (b "xy")))
          (check-equal "the error"
                       (tuple-at r ref 0)
                       '(error 3 3 3 (callback too-long "callback failure" body 3 boundary
                                      tok 3)
                         error))
          (check-equal "its state id is the data callback's slot, in both lanes"
                       (map error-state-id (list (error-at r ref 0) (error-at r gen 0)))
                       '(1 1)))))
    (harness-case "failing at a later flush, in a sub-slice"
      (lambda ()
        ;; `x` goes out at the first boundary; the second feed is `..yz` from
        ;; slice index 2 at stream offset 2, and its flush hands `yz` to a
        ;; callback that fails. Nothing is withheld: [4,4).
        (let ((r (both (list (list 'feed (b "Ax")) (list 'feed-slice (b "..yz") 2 4))
                       (list callback-continue too-long) callback-continue)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "both fragments went out" (trace-of r ref) (list (b "x") (b "yz")))
          (check-equal "the error"
                       (tuple-at r ref 1)
                       '(error 4 2 4 (callback too-long "callback failure" body 4 boundary
                                      tok 4)
                         error)))))
    (harness-case "a completion callback that fails finds the span already closed"
      (lambda ()
        ;; The span is made inactive BEFORE its completion callback runs, so a
        ;; failure there abandons nothing.
        (let ((r (both (list (list 'feed (b "AxZ."))) '() too-long)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "the fragment, then the completion" (trace-of r ref) (list (b "x") 'complete))
          (check-equal "the error records no span"
                       (tuple-at r ref 0)
                       '(error 2 2 2 (callback too-long "callback failure" close 2 boundary
                                      #f #f)
                         error)))))
    (harness-case "a completion callback failing in a later feed"
      (lambda ()
        ;; The same, where an offset computed anyway would not be 0.
        ;; `x` went out at the first boundary; the second feed's span end has
        ;; nothing new to deliver, so the next callback is the completion, and
        ;; it fails at stream offset 2 with the span already closed.
        (let ((r (both (list (list 'feed (b "Ax")) (list 'feed (b "Z."))) '() too-long)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "the fragment, then the completion" (trace-of r ref) (list (b "x") 'complete))
          (check-equal "the error records no span"
                       (tuple-at r ref 1)
                       '(error 0 0 2 (callback too-long "callback failure" close 2 boundary
                                      #f #f)
                         error)))))))

(harness-group "at finish, the flush already handed over every byte the span took"
  (lambda ()
    (harness-case "a span truncated at EOF"
      (lambda ()
        ;; The feed ended in `need-input`, so its boundary flush delivered `xy`.
        ;; The EOF error abandons the span with nothing withheld: [3,3).
        (let ((r (both (list (list 'feed (b "Axy")) (list 'finish)) '() callback-continue)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "the flush delivered" (trace-of r ref) (list (b "xy")))
          (check-equal "the finish is the truncation error"
                       (tuple-at r ref 1)
                       '(error 3 0 3 (machine eof "token truncated" trunc 3 eof
                                      tok 3)
                         error)))))
    (harness-case "after a sub-slice: a stream offset, not a slice offset"
      (lambda ()
        ;; The feed is `..Axy` from slice index 2; finish runs over no slice at
        ;; all, at stream offset 3.
        (let ((r (both (list (list 'feed-slice (b "..Axy") 2 5) (list 'finish))
                       '() callback-continue)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "the finish is the truncation error"
                       (tuple-at r ref 1)
                       '(error 3 0 3 (machine eof "token truncated" trunc 3 eof
                                      tok 3)
                         error)))))))

(harness-group "the stored error is the one reported"
  (lambda ()
    (harness-case "a repeated feed and finish after a feed error report the same span"
      (lambda ()
        ;; The two sticky rows hand back the error the parser stored, so they
        ;; must have stored the record that carries the span.
        (let ((r (both (list (list 'feed (b "Axy!")) (list 'feed (b "Z")) (list 'finish))
                       '() callback-continue)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "every report carries the abandoned span"
                       (map (lambda (e) (list (parser-error-span e) (parser-error-span-offset e)))
                            (caddr (ref r)))
                       '((tok 1) (tok 1) (tok 1))))))
    (harness-case "a repeated finish after a finish error reports the same span"
      (lambda ()
        (let ((r (both (list (list 'feed (b "Axy")) (list 'finish) (list 'finish))
                       '() callback-continue)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "both finishes carry the abandoned span"
                       (map (lambda (e) (and e (list (parser-error-span e)
                                                     (parser-error-span-offset e))))
                            (caddr (ref r)))
                       '(#f (tok 3) (tok 3))))))
    (harness-case "after a reset the next error records no span"
      (lambda ()
        (let ((r (both (list (list 'feed (b "Axy!")) (list 'reset) (list 'feed (b "!")))
                       '() callback-continue)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "the first error abandoned the span, the second none"
                       (map (lambda (e) (list (parser-error-span e) (parser-error-span-offset e)))
                            (caddr (ref r)))
                       '((tok 1) (#f #f))))))))

(harness-group "a pause is not an error and abandons nothing"
  (lambda ()
    (harness-case "a flush that pauses, then an error after resume"
      (lambda ()
        ;; The paused result carries no error and no pause reason -- a data
        ;; callback's pause declares none -- and the span stays open. After
        ;; resume, the next feed's refusal abandons it with the bytes of THAT
        ;; feed withheld: `xy` went out before the pause.
        (let ((r (both (list (list 'feed (b "Axy")) (list 'resume) (list 'feed (b "z!")))
                       (list callback-pause) callback-continue)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "the pause"
                       (tuple-at r ref 0) '(paused 3 3 3 #f paused-feed))
          (check-equal "the flush delivered before it paused" (trace-of r ref) (list (b "xy")))
          (check-equal "and the error after it"
                       (tuple-at r ref 1)
                       '(error 1 1 4 (machine bad-token-byte "refused token byte" bad 4 byte
                                      tok 3)
                         error)))))))

;; --- the property ------------------------------------------------------------
;;
;; Every way to feed one input in up to three contiguous slices, then finish.
;; Each slice is COPIED into its own bytevector behind a different amount of
;; padding, so no feed's slice index is its stream offset: a record that carried
;; a slice offset where a stream offset belongs fails here, not only in the
;; sub-slice cases above. For each schedule, in each lane: the first error names
;; the span, and the delivered fragments followed by the withheld range
;; `[span-offset, error-offset)` are exactly the bytes the span took before the
;; error. Without the two accessors the delivered bytes alone depend on the
;; schedule.
;;
;; Three machines, because the bytes inside a span reach the parser through
;; different arms: `abm`'s byte dispatch, a keyword table that parks a matched
;; prefix across feeds (how a request method is matched downstream), and a
;; counted consume that commits a body in bulk.
(define (decl-callbacks)
  (list (make-callback-declaration 'ondone 'span-complete #f '() #f #f)
        (make-callback-declaration 'ondata 'span-data #t '() #f #f)))

;; The span opens at the entry, before any byte, and closes on the keyword's
;; delimiter, which a keyword table leaves unread. `GEX` is refused at `X` after
;; `GE` was taken as a prefix of `GET` -- the prefix a split feed parks.
(define kwm
  (make-machine 'kwm 'start '()
    (decl-callbacks)
    (list (make-span-declaration 'meth 'ondata 'ondone #f))
    (list (make-error-declaration 'default-eof 'eof "unexpected end of input" #f)
          (make-error-declaration 'unknown 'bad-method "unknown method" #f)
          (make-error-declaration 'truncated 'eof "method truncated" #f)
          (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))
    (list (make-span-start-node 'start 'meth 'kw #f)
          (make-keyword-table-node 'kw
            (list (make-keyword-entry (bytevector->u8-list (b "GET")) 'close #f)
                  (make-keyword-entry (bytevector->u8-list (b "POST")) 'close #f))
            (make-edge 'unknown 'reexecute) 'trunc #f #f)
          (make-span-end-node 'close 'meth 'sp #f)
          (make-byte-dispatch-node 'sp
            (list (make-byte-case (make-exact-byte-matcher 32) (make-edge 'done 'advance) #f))
            (make-edge 'reject 'reexecute) 'fin #f)
          (make-stop-node 'done #f)
          (make-finish-node 'fin #f)
          (make-error-node 'unknown 'unknown #f)
          (make-error-node 'trunc 'truncated #f)
          (make-error-node 'reject 'rejected #f))
    'default-eof #f))

;; `B` opens a body span over a counted consume of three bytes; the byte after
;; the body must be `;`. `Babc!` is refused at `!` with the whole body withheld
;; or flushed, depending on the schedule.
(define cbm
  (make-machine 'cbm 'start (list (make-uint-field 'n 8 3 #f))
    (decl-callbacks)
    (list (make-span-declaration 'body 'ondata 'ondone #f))
    (list (make-error-declaration 'default-eof 'eof "unexpected end of input" #f)
          (make-error-declaration 'unterminated 'bad-body "body not terminated" #f)
          (make-error-declaration 'truncated 'eof "body truncated" #f)
          (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))
    (list (make-byte-dispatch-node 'start
            (list (make-byte-case (make-exact-byte-matcher 66) (make-edge 'open 'advance) #f))
            (make-edge 'reject 'reexecute) 'fin #f)
          (make-span-start-node 'open 'body 'count #f)
          (make-counted-consume-node 'count 'n 'term 'trunc #f)
          (make-byte-dispatch-node 'term
            (list (make-byte-case (make-exact-byte-matcher 59) (make-edge 'close 'reexecute) #f))
            (make-edge 'unterminated 'reexecute) 'trunc #f)
          (make-span-end-node 'close 'body 'after #f)
          (make-byte-dispatch-node 'after
            (list (make-byte-case (make-exact-byte-matcher 59) (make-edge 'done 'advance) #f))
            (make-edge 'reject 'reexecute) 'fin #f)
          (make-stop-node 'done #f)
          (make-finish-node 'fin #f)
          (make-error-node 'unterminated 'unterminated #f)
          (make-error-node 'trunc 'truncated #f)
          (make-error-node 'reject 'rejected #f))
    'default-eof #f))

(define (lanes-of m name)
  (let ((f (string-append tmpdir "/generated-abandoned-span-" (symbol->string name) ".sls"))
        (binding (string->symbol (string-append (symbol->string name) "-parser"))))
    (call-with-port (open-file-output-port f (file-options no-fail))
      (lambda (p) (emit-machine (compile-machine m '()) binding p)))
    (load f)
    (list (make-interpreted-machine (verify-machine m))
          (eval binding (environment (list 'generated name))))))

(define kw-lanes (lanes-of kwm 'kwm))
(define cb-lanes (lanes-of cbm 'cbm))

(define (schedules n)
  (let iloop ((i 0) (acc '()))
    (if (> i n) (reverse acc)
        (iloop (+ i 1)
               (let jloop ((j i) (acc acc))
                 (if (> j n) acc (jloop (+ j 1) (cons (list i j) acc))))))))

(define (first-error errs) (find (lambda (e) e) errs))

;; `bv[i,j)` copied behind `pad` filler bytes the parser must never read, fed as
;; the slice `[pad, pad + (j - i))`.
(define (padded-feed bv i j pad)
  (let ((out (make-bytevector (+ pad (- j i)) #xEE)))
    (bytevector-copy! bv i out pad (- j i))
    (list 'feed-slice out pad (+ pad (- j i)))))

;; Answers, per schedule, `(span error-offset position-kind ok? span-offset
;; delivered)`. `from` is the stream offset of the span's first byte. The last
;; two are there for the cross-lane comparison: two lanes that split fragments
;; differently with compensating offsets would agree on the first four.
(define (schedule-check cm bv answers from ij)
  (let* ((n (bytevector-length bv)) (i (car ij)) (j (cadr ij))
         (out (run (make-lane cm answers callback-continue)
                   (list (padded-feed bv 0 i 2) (padded-feed bv i j 3)
                         (padded-feed bv j n 5) (list 'finish))))
         (e (first-error (caddr out)))
         (delivered (apply append (map bytevector->u8-list
                                       (filter bytevector? (cadr out))))))
    ;; An offset that is not an integer, or a withheld range that runs
    ;; backwards or starts before the span, is a failed property, not a raise:
    ;; it is what a wrong span offset looks like, and it must be reported by the
    ;; check below rather than abort the lane.
    (if (and e (integer? (parser-error-span-offset e))
             (<= from (parser-error-span-offset e) (parser-error-offset e)))
        (let ((withheld (bytevector->u8-list
                         (slice bv (parser-error-span-offset e) (parser-error-offset e)))))
          (list (parser-error-span e) (parser-error-offset e)
                (parser-error-position-kind e)
                (equal? (append delivered withheld)
                        (bytevector->u8-list (slice bv from (parser-error-offset e))))
                (parser-error-span-offset e) delivered))
        (list (and e (parser-error-span e)) (and e (parser-error-offset e))
              (and e (parser-error-position-kind e)) #f
              (and e (parser-error-span-offset e)) delivered))))

(define (property-rows lanes bv answers from)
  (map (lambda (cm) (map (lambda (ij) (schedule-check cm bv answers from ij))
                         (schedules (bytevector-length bv))))
       lanes))

;; How many rows' cases actually ran: the sentinel for the loop over the rows.
(define rows-run 0)

(harness-group "under every schedule, delivered then withheld is the span's bytes"
  (lambda ()
    (harness-case "the keyword-table and counted fixtures verify clean"
      (lambda ()
        (check-equal "no diagnostics"
                     (map (lambda (m) (map diagnostic-code
                                           (verification-diagnostics (verify-machine m))))
                          (list kwm cbm))
                     '(() ()))))
    (for-each
     (lambda (row)
       (let* ((label (list-ref row 0)) (lanes (list-ref row 1)) (bv (list-ref row 2))
              (answers (list-ref row 3)) (span (list-ref row 4)) (from (list-ref row 5))
              (fixed (list-ref row 6)) (expected-count (list-ref row 7)))
         (harness-case label
           (lambda ()
             ;; The rows are computed INSIDE the case, so a lane that raises is
             ;; reported against this case rather than aborting the program.
             (define rows (property-rows lanes bv answers from))
             (set! rows-run (+ rows-run 1))
             ;; Sentinel on the OBSERVED rows against a count written down
             ;; independently -- (n+1)(n+2)/2 schedules for an n-byte input --
             ;; so a schedule generator that came back short fails here instead
             ;; of passing every check below over nothing.
             (check-equal "every schedule ran, in both lanes"
                          (map length rows) (list expected-count expected-count))
             (check-equal "the lanes agree on every schedule" (car rows) (cadr rows))
             (check-equal "every schedule abandons the span with delivered ++ withheld intact"
                          (filter (lambda (x) (not (and (eq? (car x) span) (cadddr x))))
                                  (car rows))
                          '())
             (when fixed
               (check-equal "and the error itself does not depend on the schedule"
                            (filter (lambda (x) (not (equal? (list (cadr x) (caddr x)) fixed)))
                                    (car rows))
                            '()))))))
     ;; label, lanes, input, data answers, span, its first byte's offset, the
     ;; schedule-independent (offset kind) or #f, and how many schedules.
     (list (list "a refusal at the byte" (list cm-ref cm-gen) (b "Awxyz!") '() 'tok 1
                 '(5 byte) 28)
           (list "a refusal after taking the byte" (list cm-ref cm-gen) (b "Awxyz#") '() 'tok 1
                 '(6 boundary) 28)
           (list "truncation at EOF" (list cm-ref cm-gen) (b "Awxyz") '() 'tok 1 '(5 eof) 21)
           ;; The first delivery fails, so WHERE the error lands depends on the
           ;; schedule -- a flush or the span end -- and only the property holds.
           (list "a data callback failing on its first fragment" (list cm-ref cm-gen)
                 (b "AwxyzZ.") (list too-long) 'tok 1 #f 36)
           (list "a keyword prefix refused" kw-lanes (b "GEX ") '() 'meth 0 '(2 byte) 15)
           (list "a longer keyword prefix refused" kw-lanes (b "POSX") '() 'meth 0 '(3 byte) 15)
           (list "a counted body refused at its terminator" cb-lanes (b "Babc!") '() 'body 1
                 '(4 byte) 21)
           (list "a counted body truncated at EOF" cb-lanes (b "Bab") '() 'body 1 '(3 eof) 10)))
    (harness-case "every row above ran"
      (lambda ()
        ;; The loop over the rows needs its own sentinel: a row dropped from the
        ;; list would shrink the group and leave it green.
        (check-equal "eight rows" rows-run 8)))))

(harness-finish)
