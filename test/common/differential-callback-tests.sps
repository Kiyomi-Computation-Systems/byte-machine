;;; interpreter ≡ generated over the callback-invocation node.
;;;
;;; This fixture's machine CALLS OUT, so it is a place the two lanes can
;;; disagree about something the application supplied rather than something
;;; the IR fixed. What is compared is the whole differential tuple -- status,
;;; next, consumed, stream offset, the projected error and the lifecycle -- for
;;; every callback outcome, in both directions of the seam:
;;;
;;;   continue, a declared branch key, an explicit callback failure, a pause,
;;;   and a return outside the declared outcomes (the runtime's
;;;   `callback-contract-violation` code).
;;;
;;; Plus the three properties that are not a single feed's tuple: a resumed
;;; callback pause continues at the DECLARED continuation and delivers nothing
;;; twice, an unbound OPTIONAL callback's slot short-circuits to the declared
;;; default without the closure being called, and a callback reached on the EOF
;;; chain runs there too.
;;;
;;; The interpreter is the reference. A disagreement here is a real defect in
;;; the callback lowering, the emitted arm, or the shared outcome vocabulary.
(import (rnrs) (rnrs eval) (only (chezscheme) load)
        (byte-machine test harness)
        (byte-machine test error-projection)
        ;; The contract-condition accessors, to assert the three lifecycle
        ;; contract codes apart. The house convention is to compare who and code, never text.
        (byte-machine private conditions)
        (byte-machine graph) (byte-machine verify)
        (byte-machine interpret) (byte-machine compile) (byte-machine runtime))

(harness-begin "differential.callback")

(define tmpdir (or (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")
                   (assertion-violation 'differential-callback "no tmpdir" #f)))

(define eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
(define rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))

;; `decide` is REQUIRED, so its slot always holds a caller procedure; `note` is
;; an OPTIONAL EVENT callback, so it defaults to `continue` and its unbound
;; slot holds the unbound-optional sentinel.
;;
;; The shape of the graph is forced by two verifier rules:
;;
;;   - a callback node's PAUSE CONTINUATION may not be a stop terminal, because
;;     a parser parked at a callback resumes on exactly that edge and the
;;     verifier forbids an EOF path reaching a stop. `after` is a dispatch node
;;     whose own EOF route terminates in `fin`.
;;   - `fin` may not be reached by a BYTE edge from a byte-reachable node, so
;;     the finish terminal sits on the EOF side only. `eofcb` is
;;     reachable ONLY as the entry's eof-target, which is what lets its continue
;;     target be `fin`.
;; One field, declared and never written: every field is among the values a
;; refused operation must not move, and a
;; machine with no fields cannot witness that half at all.
(define (callback-machine)
  (make-machine 'callbackm 'start (list (make-uint-field 'n 8 7 #f))
    (list (make-callback-declaration 'decide 'decision #t '(keep skip) #f #f)
          (make-callback-declaration 'note 'event #f '() #f #f))
    '()
    (list eof-decl rej-decl)
    (list (make-byte-dispatch-node 'start
            (list (make-byte-case (make-exact-byte-matcher 65)
                                  (make-edge 'inv 'advance) #f)
                  (make-byte-case (make-exact-byte-matcher 66)
                                  (make-edge 'opt 'advance) #f))
            (make-edge 'reject 'reexecute) 'eofcb #f)
          (make-callback-node 'inv 'decide 'done
                              '((keep done) (skip reject)) 'after #f)
          (make-callback-node 'opt 'note 'done '() 'after #f)
          ;; Reached only on the EOF chain, which is why its continue target may
          ;; be the finish terminal.
          (make-callback-node 'eofcb 'decide 'fin
                              '((keep fin) (skip reject)) 'after #f)
          (make-byte-dispatch-node 'after
            (list (make-byte-case (make-exact-byte-matcher 67)
                                  (make-edge 'done 'advance) #f))
            (make-edge 'reject 'reexecute) 'fin #f)
          (make-stop-node 'done #f)
          (make-finish-node 'fin #f)
          (make-error-node 'reject 'rejected #f))
    'default-eof #f))

(define m (callback-machine))
(define v (verify-machine m))
(define cm-ref (make-interpreted-machine v))
(define genfile (string-append tmpdir "/generated-callback.sls"))
(call-with-port (open-file-output-port genfile (file-options no-fail))
  (lambda (p) (emit-machine (compile-machine m '()) 'callback-parser p)))
(load genfile)
(define cm-gen (eval 'callback-parser (environment '(generated callbackm))))

;; The differential's comparison surface, one owner. `project-error` is the
;; shared error projection; `parser-error-detail` is deliberately NOT in it --
;; the cross-lane comparison does not compare detail -- so the explicit-failure
;; case asserts it per lane below.
;; `bytevector` is a Chez extension, not R6RS; a one-byte slice is what every
;; case here feeds.
(define (bv1 b) (make-bytevector 1 b))

(define (rfields r p)
  (list (parser-result-status r) (parser-result-next r) (parser-result-consumed r)
        (parser-result-stream-offset r) (project-error (parser-result-error r))
        (parser-lifecycle p)))

(define (bindings-for outcome recorder)
  (list (list 'decide (lambda (ps ux) (recorder 'decide) outcome))))

;; A fresh parser per lane per case: a callback outcome is sticky through the
;; lifecycle, so reusing one would make every later case observe the first.
(define (drive cm outcome bytes)
  (let* ((calls '())
         (p (make-parser cm (bindings-for outcome (lambda (w) (set! calls (cons w calls))))
                         'the-context))
         (r (parser-feed! p bytes 0 (bytevector-length bytes))))
    (list (rfields r p) (length calls) p r)))

(harness-group "every callback outcome agrees across the lanes (§13:803-808)"
  (lambda ()
    (harness-case "the machine verifies clean"
      (lambda ()
        ;; Stated first: every comparison below is vacuous on a machine the
        ;; verifier rejects, because neither lane would have been built.
        (check-equal "no diagnostics"
                     (map diagnostic-code (verification-diagnostics v)) '())))
    (harness-case "all six outcomes produce the identical tuple in both lanes"
      (lambda ()
        ;; A sentinel over the outcomes DRIVEN, read from the loop rather than
        ;; from the list's length, and a record of the first disagreement rather
        ;; than a bare boolean.
        (let ((driven 0) (bad '()))
          (for-each
           (lambda (row)
             (set! driven (+ driven 1))
             (let* ((nm (car row)) (outcome (cadr row))
                    (a (drive cm-ref outcome (bv1 65)))
                    (b (drive cm-gen outcome (bv1 65))))
               (unless (equal? (car a) (car b))
                 (set! bad (cons (list nm (car a) (car b)) bad)))
               ;; Each invocation is delivered exactly once, and a count is
               ;; the only thing that can see a lane invoking twice.
               (unless (= (cadr a) 1 (cadr b))
                 (set! bad (cons (list nm 'calls (cadr a) (cadr b)) bad)))))
           (list (list 'continue callback-continue)
                 (list 'branch-keep 'keep)
                 (list 'branch-skip 'skip)
                 (list 'pause callback-pause)
                 (list 'failure (make-callback-failure 'app-said-no 'the-detail))
                 (list 'out-of-contract 'not-a-declared-key)))
          (check-equal "six outcomes driven" driven 6)
          (check-equal "and every one agrees" bad '()))))
    (harness-case "the outcomes are not all the same tuple"
      (lambda ()
        ;; Without this the comparison above would pass on a lane pair that
        ;; answered identically and WRONGLY for every outcome -- the shape of
        ;; agreement bought by making the difference unobservable.
        (let ((tuples (map (lambda (o) (car (drive cm-ref o (bv1 65))))
                           (list callback-continue 'skip callback-pause
                                 (make-callback-failure 'app-said-no #f)))))
          (check-equal "four outcomes, four distinct results"
                       (length tuples) 4)
          (check "continue stops, skip errors"
                 (not (equal? (car tuples) (cadr tuples))))
          (check "skip's machine error differs from the callback failure"
                 (not (equal? (cadr tuples) (cadddr tuples))))
          (check "and the pause is neither"
                 (and (not (equal? (caddr tuples) (car tuples)))
                      (not (equal? (caddr tuples) (cadr tuples))))))))
    (harness-case "the callback-domain error carries decision 0024's two codes"
      (lambda ()
        ;; The projection compares domain, code, reason, node name, offset and
        ;; position kind. Asserted here as VALUES, not only as agreement: two
        ;; lanes agreeing on a wrong domain would satisfy the loop above.
        (let ((f (car (drive cm-ref (make-callback-failure 'app-said-no 'the-detail)
                             (bv1 65))))
              (c (car (drive cm-ref 'not-a-declared-key (bv1 65)))))
          (check-equal "the explicit failure's application code"
                       (list-ref f 4)
                       '(callback app-said-no "callback failure" inv 1 boundary #f #f))
          (check-equal "and the minted out-of-contract code"
                       (list-ref c 4)
                       '(callback callback-contract-violation "callback failure"
                                  inv 1 boundary #f #f)))))
    (harness-case "the explicit failure's detail passes through in BOTH lanes"
      (lambda ()
        ;; Per lane rather than through the projection: the projection does
        ;; not compare detail, and detail must be the application's on this
        ;; path and #f on the other.
        (let ((a (cadddr (drive cm-ref (make-callback-failure 'app-said-no 'the-detail)
                                (bv1 65))))
              (b (cadddr (drive cm-gen (make-callback-failure 'app-said-no 'the-detail)
                                (bv1 65))))
              (c (cadddr (drive cm-ref 'not-a-declared-key (bv1 65))))
              (d (cadddr (drive cm-gen 'not-a-declared-key (bv1 65)))))
          (check-equal "interpreted detail" (parser-error-detail (parser-result-error a))
                       'the-detail)
          (check-equal "generated detail" (parser-error-detail (parser-result-error b))
                       'the-detail)
          (check-equal "interpreted out-of-contract detail"
                       (parser-error-detail (parser-result-error c)) #f)
          (check-equal "generated out-of-contract detail"
                       (parser-error-detail (parser-result-error d)) #f))))
    (harness-case "both lanes report a state id, which the projection omits"
      (lambda ()
        ;; The projection excludes the id from the comparison, and both lanes
        ;; must still report one. Positive, so the omission is not invisible.
        (let ((a (cadddr (drive cm-ref 'not-a-declared-key (bv1 65))))
              (b (cadddr (drive cm-gen 'not-a-declared-key (bv1 65)))))
          (check "interpreted" (integer? (error-state-id (parser-result-error a))))
          (check "generated" (integer? (error-state-id (parser-result-error b)))))))))

(harness-group "a resumed callback pause continues where the node declared"
  (lambda ()
    (harness-case "resume then feed agrees, and the callback is not re-delivered"
      (lambda ()
        ;; A callback-requested pause occurs after the callback's delivered
        ;; event has been committed; resume continues after that event, and
        ;; the event is never delivered twice. The oracle is the recording
        ;; SEQUENCE across the resume, not a count taken afterwards: a count
        ;; alone cannot tell "delivered twice" from "delivered once and
        ;; something else appended".
        (let ((seq-of
               (lambda (cm)
                 (let* ((calls '())
                        (p (make-parser cm
                                        (list (list 'decide
                                                    (lambda (ps ux)
                                                      (set! calls (cons 'decide calls))
                                                      callback-pause)))
                                        'the-context))
                        (r1 (parser-feed! p (bv1 65) 0 1))
                        (after-feed (reverse calls))
                        (ack (parser-resume! p))
                        (after-resume (reverse calls))
                        (r2 (parser-feed! p (bv1 67) 0 1)))
                   (list (rfields r1 p) after-feed ack after-resume
                         (rfields r2 p) (reverse calls))))))
          (let ((a (seq-of cm-ref)) (b (seq-of cm-gen)))
            (check-equal "the two lanes agree on the whole walk" a b)
            (check-equal "one delivery at the pause" (cadr a) '(decide))
            ;; resume invokes no callback and consumes no input.
            (check-equal "resume delivers nothing" (cadddr a) '(decide))
            (check-equal "and the resumed feed delivers nothing either"
                         (list-ref a 5) '(decide))
            (check-equal "the ack is feed-ready" (caddr a) 'feed-ready)))))))

(harness-group "an unbound optional callback short-circuits to its default"
  (lambda ()
    (harness-case "both lanes take the default with no closure called"
      (lambda ()
        ;; The read side of the unbound-optional sentinel: `note` is an
        ;; OPTIONAL EVENT callback, so it defaults to `continue` -- lowered to the node's continue target, which is the stop
        ;; terminal. The parser is built with no binding for it at all.
        (let ((go (lambda (cm)
                    (let* ((p (make-parser cm (list (list 'decide
                                                          (lambda (ps ux) callback-continue)))
                                           'the-context))
                           (r (parser-feed! p (bv1 66) 0 1)))
                      (rfields r p)))))
          (check-equal "the lanes agree" (go cm-ref) (go cm-gen))
          (check-equal "and it is the continue target's stop"
                       (car (go cm-ref)) 'stopped))))
    (harness-case "a missing REQUIRED binding is still refused at construction"
      (lambda ()
        ;; The construction-time rejection, re-asserted beside the case above
        ;; where an unbound slot is READ: an optional one short-circuits and a
        ;; required one must never get that far.
        (let ((raises? (lambda (th)
                         (call/cc (lambda (k)
                                    (with-exception-handler (lambda (e) (k #t))
                                      (lambda () (th) #f)))))))
          (check "interpreted" (raises? (lambda () (make-parser cm-ref '() #f))))
          (check "generated" (raises? (lambda () (make-parser cm-gen '() #f)))))))))

(harness-group "a callback on the EOF chain runs there too (§12.4:729)"
  (lambda ()
    (harness-case "finish reaching a callback agrees across the lanes"
      (lambda ()
        ;; `eofcb` is reachable ONLY as the entry's eof-target, so this is the
        ;; `classify` flow-through case: EOF processing invokes the callback and
        ;; every outcome is live there, which is why its continue target may be
        ;; the finish terminal a byte edge could not reach.
        (let ((go (lambda (cm outcome)
                    (let* ((calls 0)
                           (p (make-parser cm
                                           (list (list 'decide
                                                       (lambda (ps ux)
                                                         (set! calls (+ calls 1))
                                                         outcome)))
                                           'the-context))
                           (r (parser-finish! p)))
                      (list (rfields r p) calls))))
              (driven 0) (bad '()))
          (for-each
           (lambda (row)
             (set! driven (+ driven 1))
             (let ((a (go cm-ref (cadr row))) (b (go cm-gen (cadr row))))
               (unless (equal? a b) (set! bad (cons (list (car row) a b) bad)))))
           (list (list 'continue callback-continue)
                 (list 'branch-keep 'keep)
                 (list 'branch-skip 'skip)
                 (list 'pause callback-pause)
                 (list 'failure (make-callback-failure 'app-said-no #f))))
          (check-equal "five EOF outcomes driven" driven 5)
          (check-equal "and every one agrees" bad '())
          (check-equal "continue at EOF finishes"
                       (car (car (go cm-ref callback-continue))) 'finished)
          ;; A pause during EOF produces `paused-finish`.
          (check-equal "and a pause at EOF is paused-finish"
                       (list-ref (car (go cm-ref callback-pause)) 5)
                       'paused-finish))))))

;; --- the committed state, from inside a callback ----------------------------
;;
;; At callback entry, the interpreter and generated executor expose identical
;; committed parser state. In the generated lane this needs a commit before the
;; invocation: `exec` owns its own pos/off/st locals and writes the parser's
;; slots only on RETURN, so without that commit `parser-stream-offset` answers
;; the offset the feed started at and `parser-state-name` answers the state it
;; started in.
(harness-group "what a callback sees is committed, and identical in both lanes"
  (lambda ()
    (harness-case "the accessors answer the same values from inside both lanes"
      (lambda ()
        ;; The whole committed-state tuple, recorded FROM INSIDE the callback rather
        ;; than after it: only a recording closure can see the state at entry,
        ;; and only comparing the two recordings can show the lanes agree there.
        (let ((seen-in
               (lambda (cm)
                 (let* ((seen '())
                        (p (make-parser cm
                                        (list (list 'decide
                                                    (lambda (ps ux)
                                                      (set! seen
                                                            (list (parser-state-name ps)
                                                                  (parser-stream-offset ps)
                                                                  (parser-lifecycle ps)
                                                                  (parser-active-span ps)
                                                                  ux))
                                                      callback-continue)))
                                        'the-context)))
                   (parser-feed! p (bv1 65) 0 1)
                   seen))))
          (let ((a (seen-in cm-ref)) (b (seen-in cm-gen)))
            (check-equal "the two lanes agree on every committed value" a b)
            ;; And by VALUE, not only by agreement: two lanes agreeing on the
            ;; wrong offset would satisfy the comparison above.
            (check-equal "the state name is the callback NODE's" (car a) 'inv)
            ;; The stream offset and cursor include every byte committed before
            ;; the callback. One byte was consumed reaching `inv`.
            (check-equal "the offset includes the consumed byte" (cadr a) 1)
            (check-equal "no span is active" (cadddr a) #f)
            (check-equal "and the user context is the one make-parser was given"
                         (list-ref a 4) 'the-context)))))
    (harness-case "the offset a callback sees is not the offset the feed began at"
      (lambda ()
        ;; The check that makes the case above non-vacuous: a lane that never
        ;; committed would report 0, which is also a plausible answer, so the
        ;; assertion is only meaningful because the two differ.
        (let ((p (make-parser cm-ref
                              (list (list 'decide (lambda (ps ux) callback-continue)))
                              'the-context)))
          (check-equal "before the feed" (parser-stream-offset p) 0))))
    (harness-case "parser-state-name agrees at every position outside a callback too"
      (lambda ()
        ;; The accessor at the positions a caller can reach
        ;; without a callback: fresh, stopped, errored, and parked on a callback
        ;; pause continuation.
        (let ((walk
               (lambda (cm outcome bytes)
                 (let ((p (make-parser cm
                                       (list (list 'decide (lambda (ps ux) outcome)))
                                       'the-context)))
                   (let ((before (parser-state-name p)))
                     (parser-feed! p bytes 0 (bytevector-length bytes))
                     (list before (parser-state-name p) (parser-lifecycle p)))))))
          (check-equal "fresh then stopped"
                       (walk cm-ref callback-continue (bv1 65))
                       (walk cm-gen callback-continue (bv1 65)))
          (check-equal "and it is entry then the continue target"
                       (walk cm-ref callback-continue (bv1 65))
                       '(start done stopped))
          (check-equal "fresh then parked on the pause continuation"
                       (walk cm-ref callback-pause (bv1 65))
                       (walk cm-gen callback-pause (bv1 65)))
          (check-equal "and it is entry then `after`"
                       (walk cm-ref callback-pause (bv1 65))
                       '(start after paused-feed))
          (check-equal "fresh then the error node"
                       (walk cm-ref 'skip (bv1 65))
                       (walk cm-gen 'skip (bv1 65)))
          (check-equal "and it is entry then the error node"
                       (walk cm-ref 'skip (bv1 65))
                       '(start reject error)))))))

;; --- `busy`, `poisoned`, and the ordering clause -----------------------------
;;
;; The `busy` and `poisoned` lifecycle rows. Reaching either state needs a
;; callback: `busy` needs something running inside the parser, and `poisoned`
;; needs a callback to escape from one. A lifecycle `case` whose `else` meant
;; "ready" would silently execute input in either state, so these cases are
;; what witness the explicit arms.
(define (contract? who code)
  (lambda (e)
    (and (byte-machine-contract-condition? e)
         (eq? (byte-machine-contract-condition-who e) who)
         (eq? (byte-machine-contract-condition-code e) code))))

;; The wrapper the poisoned-parser oracle needs, and it is NOT "compare the two results":
;; on an escape neither lane returns one. What is compared is that the SAME
;; condition escaped `parser-feed!` in both lanes AND that both parsers are
;; poisoned afterwards.
(define (escaping thunk)
  (call/cc (lambda (k)
             (with-exception-handler (lambda (e) (k (list 'raised e)))
               (lambda () (list 'returned (thunk)))))))

(harness-group "a callback runs with the parser BUSY, and cannot re-enter it"
  (lambda ()
    (harness-case "all four mutating operations raise reentrancy from inside a callback"
      (lambda ()
        ;; The whole `busy` row -- feed, finish, resume AND reset, which is the
        ;; one operation whose `busy` cell differs from its `poisoned` cell.
        ;; Driven from inside the callback, which is the only place the state
        ;; exists.
        ;; *** The probe runs ONCE, and the guard is not tidiness. *** Under a
        ;; mutant that stops marking the parser busy, the inner `parser-feed!`
        ;; finds a `ready` parser, runs the executor, reaches this same callback
        ;; and feeds again -- unbounded recursion, which runs until the mutation
        ;; runner's per-command timeout kills it rather than failing a
        ;; comparison. With the guard the mutant records
        ;; `returned` where the baseline records `raised`, which is a failed
        ;; comparison and the catch this row is for.
        (let ((from-inside
               (lambda (cm)
                 (let* ((seen '())
                        (probed #f)
                        (p (make-parser cm
                                        (list (list 'decide
                                                    (lambda (ps ux)
                                                      (unless probed
                                                        (set! probed #t)
                                                        (set! seen
                                                              (list
                                                               (parser-lifecycle ps)
                                                               (escaping (lambda () (parser-feed! ps (bv1 65) 0 1)))
                                                               (escaping (lambda () (parser-finish! ps)))
                                                               (escaping (lambda () (parser-resume! ps)))
                                                               (escaping (lambda () (parser-reset! ps))))))
                                                      callback-continue)))
                                        'the-context)))
                   (parser-feed! p (bv1 65) 0 1)
                   ;; Only the OUTCOME KIND of each attempt is compared across
                   ;; lanes -- `raised` or `returned`. The conditions themselves
                   ;; are values with no cross-lane equality, and the case below
                   ;; is what asserts which condition each one is.
                   (list (car seen) (map car (cdr seen)))))))
          (let ((a (from-inside cm-ref)) (b (from-inside cm-gen)))
            (check-equal "the lanes agree" a b)
            ;; Inside a callback the lifecycle is `busy`, so parser operations are rejected.
            (check-equal "the callback sees busy" (car a) 'busy)
            (check-equal "and all four raised" (cadr a) '(raised raised raised raised))))))
    (harness-case "each of the four raises the REENTRANCY code, not lifecycle-violation"
      (lambda ()
        ;; Lifecycle violation, reentrancy, and poisoned parser are three
        ;; distinct codes. Asserted per operation, by who AND code: a
        ;; single predicate over the family would pass on all three.
        ;; Probed once, for the reason the case above records: an unguarded
        ;; inner feed recurses without bound under the busy-marking mutant.
        (let ((codes '()) (probed #f))
          (let ((p (make-parser cm-ref
                                (list (list 'decide
                                            (lambda (ps ux)
                                              (unless probed
                                               (set! probed #t)
                                               (set! codes
                                                    (map (lambda (pair)
                                                           (let ((r (escaping (cdr pair))))
                                                             (list (car pair)
                                                                   (and (eq? (car r) 'raised)
                                                                        ((contract? (car pair) 'reentrancy)
                                                                         (cadr r))))))
                                                         (list (cons 'parser-feed! (lambda () (parser-feed! ps (bv1 65) 0 1)))
                                                               (cons 'parser-finish! (lambda () (parser-finish! ps)))
                                                               (cons 'parser-resume! (lambda () (parser-resume! ps)))
                                                               (cons 'parser-reset! (lambda () (parser-reset! ps)))))))
                                              callback-continue)))
                                'the-context)))
            (parser-feed! p (bv1 65) 0 1))
          (check-equal "four operations, each with its own who and the reentrancy code"
                       codes
                       '((parser-feed! #t) (parser-finish! #t)
                         (parser-resume! #t) (parser-reset! #t))))))
    (harness-case "every read accessor answers during busy (decision 0028 item 1)"
      (lambda ()
        ;; "Parser operations are rejected" scopes to the four MUTATING
        ;; operations, and every read accessor answers
        ;; normally. Six of them, named individually -- a count would pass if
        ;; one were swapped for another.
        (let ((seen 'unset))
          (let ((p (make-parser cm-ref
                                (list (list 'decide
                                            (lambda (ps ux)
                                              (set! seen (list (parser-lifecycle ps)
                                                               (parser-state-name ps)
                                                               (parser-stream-offset ps)
                                                               (parser-field-ref ps 'n)
                                                               (parser-user-context ps)
                                                               (parser-active-span ps)))
                                              callback-continue)))
                                'the-context)))
            (parser-feed! p (bv1 65) 0 1))
          (check-equal "all six answered" seen '(busy inv 1 7 the-context #f)))))))

(harness-group "a callback that escapes poisons the parser (§12.6:749)"
  (lambda ()
    (harness-case "a raised condition propagates and both lanes end poisoned"
      (lambda ()
        ;; *** A differential written as "compare the two results" cannot see
        ;; this case at all, because neither lane returns one. *** What is
        ;; compared is that the same condition escaped `parser-feed!` and that
        ;; both parsers are poisoned.
        (let ((go (lambda (cm)
                    (let ((p (make-parser cm
                                          (list (list 'decide
                                                      (lambda (ps ux) (raise 'boom))))
                                          'the-context)))
                      (list (escaping (lambda () (parser-feed! p (bv1 65) 0 1)))
                            (parser-lifecycle p))))))
          (check-equal "the lanes agree on the escape and the state"
                       (go cm-ref) (go cm-gen))
          (check-equal "and it is the callback's own condition, propagated"
                       (go cm-ref) '((raised boom) poisoned)))))
    (harness-case "a nonlocal escape poisons too, with nothing raised"
      (lambda ()
        ;; Poisoning has TWO antecedents -- the callback raises an unexpected
        ;; condition or performs a nonlocal escape -- and only the second has no condition to
        ;; observe. `dynamic-wind`'s after thunk is what covers both.
        (let ((go (lambda (cm)
                    (let ((held #f))
                      (let ((out (call/cc
                                  (lambda (k)
                                    (let ((p (make-parser cm
                                                          (list (list 'decide
                                                                      (lambda (ps ux) (k 'escaped))))
                                                          'the-context)))
                                      (set! held p)
                                      (parser-feed! p (bv1 65) 0 1)
                                      'no-escape)))))
                        (list out (parser-lifecycle held)))))))
          (check-equal "the lanes agree" (go cm-ref) (go cm-gen))
          (check-equal "the escape reached the caller and the parser is poisoned"
                       (go cm-ref) '(escaped poisoned)))))
    (harness-case "a poisoned parser raises parser-poisoned, and only reset reuses it"
      (lambda ()
        ;; The `poisoned` lifecycle row. The code is distinct from both
        ;; `lifecycle-violation` and `reentrancy`.
        (let ((poisoned-parser
               (lambda (cm)
                 (let ((p (make-parser cm
                                       (list (list 'decide (lambda (ps ux) (raise 'boom))))
                                       'the-context)))
                   (escaping (lambda () (parser-feed! p (bv1 65) 0 1)))
                   p))))
          (let ((p (poisoned-parser cm-ref)) (q (poisoned-parser cm-gen)))
            (check-equal "poisoned in both lanes"
                         (list (parser-lifecycle p)) (list (parser-lifecycle q)))
            (check-raises "feed" (contract? 'parser-feed! 'poisoned-parser)
                          (lambda () (parser-feed! p (bv1 65) 0 1)))
            (check-raises "finish" (contract? 'parser-finish! 'poisoned-parser)
                          (lambda () (parser-finish! p)))
            (check-raises "resume" (contract? 'parser-resume! 'poisoned-parser)
                          (lambda () (parser-resume! p)))
            ;; Reset is permitted on a poisoned parser -- "only full reset may
            ;; reuse it" is a permission, not a prohibition -- and the reset one
            ;; runs.
            (parser-reset! p)
            (check-equal "reset returns it to ready" (parser-lifecycle p) 'ready)
            (check-equal "and it parses again"
                         (parser-result-status
                          (parser-feed! (let ((r (make-parser cm-ref
                                                              (list (list 'decide (lambda (ps ux) callback-continue)))
                                                              'the-context)))
                                          r)
                                        (bv1 65) 0 1))
                         'stopped)))))
    (harness-case "a refused operation moves NOTHING (§12.6:747)"
      (lambda ()
        ;; "Prohibited lifecycle operations and reentrant parser operations
        ;; raise API-contract conditions BEFORE further mutation." Testable and
        ;; therefore tested: the whole observable state is sampled before and
        ;; after each refusal and compared. A test that only checked the raise
        ;; could not see a guard that mutates first.
        (let* ((snapshot (lambda (p)
                           (list (parser-lifecycle p) (parser-stream-offset p)
                                 (parser-field-ref p 'n) (parser-state-name p)
                                 (parser-active-span p) (parser-user-context p))))
               (p (make-parser cm-ref
                               (list (list 'decide (lambda (ps ux) (raise 'boom))))
                               'the-context)))
          (escaping (lambda () (parser-feed! p (bv1 65) 0 1)))
          (let ((before (snapshot p)))
            (for-each (lambda (th) (escaping th))
                      (list (lambda () (parser-feed! p (bv1 65) 0 1))
                            (lambda () (parser-finish! p))
                            (lambda () (parser-resume! p))))
            (check-equal "nothing moved" (snapshot p) before)
            (check-equal "and it is still poisoned" (car before) 'poisoned)))))))

;; --- the callback ORDER ------------------------------------------------------
;;
;; Callback order and results are among the values the two lanes must agree
;; on. Compared here over the feed-schedule list below.
;;
;; *** ONE RECORDING CLOSURE PER LANE. *** One closure passed as the binding to
;; both parsers has one accumulator, so it produces ONE list -- and there is
;; nothing to compare it to. Worse, the both-lanes drivers alternate the two
;; parsers inside a single expression, so a shared accumulator yields an
;; interleaved sequence in which a lane-swap defect is invisible. Each lane
;; therefore gets its own closure and accumulator, compared per schedule.
(define (order-machine)
  (make-machine 'orderm 's0 '()
    (list (make-callback-declaration 'note 'event #t '() #f #f)
          (make-callback-declaration 'pick 'decision #t '(go halt) #f #f))
    '()
    (list eof-decl rej-decl)
    (list (make-byte-dispatch-node 's0
            (list (make-byte-case (make-exact-byte-matcher 97)
                                  (make-edge 'n1 'advance) #f)
                  (make-byte-case (make-exact-byte-matcher 98)
                                  (make-edge 'n2 'advance) #f))
            (make-edge 'reject 'reexecute) 'fin #f)
          ;; Both callbacks continue back to the dispatch, so the invocation
          ;; count is the byte count and the ORDER is what the input spells.
          (make-callback-node 'n1 'note 's0 '() 's0 #f)
          (make-callback-node 'n2 'pick 's0 '((go s0) (halt done)) 's0 #f)
          (make-stop-node 'done #f)
          (make-finish-node 'fin #f)
          (make-error-node 'reject 'rejected #f))
    'default-eof #f))

(define om (order-machine))
(define ov (verify-machine om))
(define om-ref (make-interpreted-machine ov))
(define orderfile (string-append tmpdir "/generated-order.sls"))
(call-with-port (open-file-output-port orderfile (file-options no-fail))
  (lambda (p) (emit-machine (compile-machine om '()) 'order-parser p)))
(load orderfile)
(define om-gen (eval 'order-parser (environment '(generated orderm))))

;; The recorded entry is the callback's NAME and what it could see, so the
;; comparison is of order AND results rather than order alone.
(define (record-order cm slices)
  (let* ((trace '())
         (note! (lambda (nm)
                  (lambda (ps ux)
                    (set! trace (cons (list nm (parser-state-name ps)
                                            (parser-stream-offset ps))
                                      trace))
                    callback-continue)))
         (p (make-parser cm (list (list 'note (note! 'note))
                                  (list 'pick (note! 'pick)))
                         'the-context)))
    (for-each (lambda (sl) (parser-feed! p (car sl) (cadr sl) (caddr sl))) slices)
    (let ((r (parser-finish! p)))
      (list (reverse trace) (parser-result-status r) (parser-lifecycle p)))))

(define order-bytes (u8-list->bytevector '(97 98 97 98)))
(define padded-bytes (u8-list->bytevector '(200 201 97 98 97 98 202)))
(define empty-bytes (make-bytevector 0))

;; The feed-schedule list, each entry a slice schedule over the SAME four
;; logical bytes.
(define (split-schedules)
  (let loop ((k 0) (acc '()))
    (if (> k 4) (reverse acc)
        (loop (+ k 1)
              (cons (list (list order-bytes 0 k) (list order-bytes k 4)) acc)))))
(define (pair-schedules)
  (let outer ((i 0) (acc '()))
    (if (> i 4) (reverse acc)
        (outer (+ i 1)
               (let inner ((j i) (a acc))
                 (if (> j 4) a
                     (inner (+ j 1)
                            (cons (list (list order-bytes 0 i)
                                        (list order-bytes i j)
                                        (list order-bytes j 4))
                                  a))))))))
(define other-schedules
  (list
   ;; whole, in one feed
   (list (list order-bytes 0 4))
   ;; leading, intermediate and trailing EMPTY feeds
   (list (list empty-bytes 0 0) (list order-bytes 0 4))
   (list (list order-bytes 0 2) (list empty-bytes 0 0) (list order-bytes 2 4))
   (list (list order-bytes 0 4) (list empty-bytes 0 0))
   ;; an empty slice taken from the MIDDLE of the real bytevector, which is a
   ;; different shape from a zero-length bytevector
   (list (list order-bytes 0 2) (list order-bytes 2 2) (list order-bytes 2 4))
   ;; nonzero start/end into a larger bytevector carrying unrelated prefix and
   ;; suffix bytes -- the schedule that would catch a lane
   ;; reading from index 0 regardless of `start`
   (list (list padded-bytes 2 6))
   (list (list padded-bytes 2 4) (list padded-bytes 4 6))
   ;; deterministic multi-split schedules, written out rather than generated:
   ;; determinism here is about reproducibility, and a literal list is the most
   ;; reproducible form there is.
   (list (list order-bytes 0 1) (list order-bytes 1 2)
         (list order-bytes 2 3) (list order-bytes 3 4))
   (list (list order-bytes 0 3) (list order-bytes 3 3) (list order-bytes 3 4))
   (list (list order-bytes 0 0) (list order-bytes 0 2)
         (list empty-bytes 0 0) (list order-bytes 2 2) (list order-bytes 2 4))))

(harness-group "the callback order agrees across lanes, and across schedules"
  (lambda ()
    (harness-case "the order machine verifies clean"
      (lambda ()
        (check-equal "no diagnostics"
                     (map diagnostic-code (verification-diagnostics ov)) '())))
    (harness-case "every schedule produces the same order in both lanes"
      (lambda ()
        ;; A sentinel over the schedules DRIVEN, read from the loop, and the
        ;; disagreeing schedule recorded rather than a bare boolean.
        (let ((driven 0) (bad '())
              (schedules (append (split-schedules) (pair-schedules) other-schedules)))
          (for-each
           (lambda (sl)
             (set! driven (+ driven 1))
             (let ((a (record-order om-ref sl)) (b (record-order om-gen sl)))
               (unless (equal? a b) (set! bad (cons (list driven a b) bad)))))
           schedules)
          ;; 5 single splits + 15 pairs + 10 others. Counted from the loop and
          ;; ALSO compared against a total computed separately: the literal
          ;; catches a schedule list that silently shrank, the derived total
          ;; catches a loop that stopped early, and neither catches the other.
          (check-equal "thirty schedules driven" driven 30)
          (check-equal "and the length agrees" driven (length (append (split-schedules)
                                                                     (pair-schedules)
                                                                     other-schedules)))
          (check-equal "every schedule agrees across the lanes" bad '()))))
    (harness-case "and the order is the same under EVERY schedule"
      (lambda ()
        ;; Across feed schedules, the normalized semantic trace must agree. A
        ;; callback invocation has no fragment to coalesce -- only spans do --
        ;; so for this machine the normalized
        ;; trace IS the raw one, and it must be schedule-independent.
        (let ((baseline (record-order om-ref (list (list order-bytes 0 4))))
              (differing '()))
          (for-each
           (lambda (sl)
             (unless (equal? (record-order om-ref sl) baseline)
               (set! differing (cons sl differing))))
           (append (split-schedules) (pair-schedules) other-schedules))
          (check-equal "no schedule changes the trace" differing '())
          ;; And by VALUE, so the invariance above is not invariance around the
          ;; wrong sequence: two `note`/`pick` pairs, each seeing its own node
          ;; and the offset of the byte that reached it.
          (check-equal "the trace is what the input spells"
                       (car baseline)
                       '((note n1 1) (pick n2 2) (note n1 3) (pick n2 4)))
          (check-equal "and EOF finishes" (cdr baseline) '(finished finished)))))
    (harness-case "a decision that halts is ordered and stops there"
      (lambda ()
        ;; The results half of "order and results": the same input with a different
        ;; RETURN produces a different trace, so the comparison above is not
        ;; measuring a constant.
        (let ((halting
               (lambda (cm)
                 (let* ((trace '())
                        (p (make-parser cm
                                        (list (list 'note (lambda (ps ux)
                                                            (set! trace (cons 'note trace))
                                                            callback-continue))
                                              (list 'pick (lambda (ps ux)
                                                            (set! trace (cons 'pick trace))
                                                            'halt)))
                                        'the-context))
                        (r (parser-feed! p order-bytes 0 4)))
                   (list (reverse trace) (parser-result-status r)
                         (parser-result-consumed r))))))
          (check-equal "the lanes agree" (halting om-ref) (halting om-gen))
          (check-equal "and it halts at the first decision"
                       (halting om-ref) '((note pick) stopped 2)))))))

(harness-finish)
