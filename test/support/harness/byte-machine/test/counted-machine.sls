;;; The counted-consume proving machines: a length-prefixed message loop
;;; WITHOUT a span -- `idle` -> `len` -> `:` -> `body` -> `,` -> clear -> `idle`
;;; -- in the shape the HTTP fixture needs (completion resets the message field
;;; and loops to request start), plus the smaller machines the counted-consume
;;; oracles and the reached-declaration walk need, and the same loop with
;;; `body` inside a span, in two variants.
;;;
;;; `idle`'s eof-target is the FINISH, so EOF between messages is `finished`,
;;; and `len`, `body` and `,` route EOF to the truncation error, so EOF after a
;;; partial length, mid-body or before the delimiter is a truncation -- the
;;; idle-versus-partial distinction, which a machine whose entry is the
;;; accumulate node cannot make. The entry reexecutes the first digit into
;;; `len` so the accumulator sees every digit; `len`'s non-digit edge reexecutes
;;; the `:` into a dispatch that consumes it, so the body starts exactly after
;;; the colon. `make-counted-span-machine` (below) wraps `body` in a span and
;;; leaves the other four machines unchanged.
(library (byte-machine test counted-machine)
  (export make-counted-machine make-only-consumer-machine make-entry-zero-machine
          make-big-count-machine make-counted-span-machine)
  (import (rnrs)
          (byte-machine graph))

  (define (decls)
    (list (make-error-declaration 'default-eof 'eof "unexpected end of input" #f)
          (make-error-declaration 'truncated 'eof "truncated message" #f)
          (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f)
          (make-error-declaration 'too-long 'unexpected-byte "length overflow" #f)))

  (define (make-counted-machine)
    (make-machine 'countedm 'idle
                  (list (make-uint-field 'len 32 0 #f))
                  '() '() (decls)
                  (list
                   ;; A digit opens a message and is REEXECUTED into the
                   ;; accumulator; EOF here is a clean end between messages.
                   (make-byte-dispatch-node
                    'idle
                    (list (make-byte-case (make-byte-range-matcher 48 57)
                                          (make-edge 'len 'reexecute) #f))
                    (make-edge 'reject 'reexecute)
                    'fin #f)
                   (make-integer-accumulate-node
                    'len 'len 10 'len
                    (make-edge 'colon 'reexecute)
                    'over 'trunc #f)
                   (make-byte-dispatch-node
                    'colon
                    (list (make-byte-case (make-exact-byte-matcher 58)
                                          (make-edge 'body 'advance) #f))
                    (make-edge 'reject 'reexecute)
                    'trunc #f)
                   (make-counted-consume-node 'body 'len 'comma 'trunc #f)
                   (make-byte-dispatch-node
                    'comma
                    (list (make-byte-case (make-exact-byte-matcher 44)
                                          (make-edge 'clear 'advance) #f))
                    (make-edge 'reject 'reexecute)
                    'trunc #f)
                   ;; Completion resets the message field by an explicit
                   ;; action and loops to request start.
                   (make-field-action-node 'clear 'clear '(len) 'idle #f #f)
                   (make-finish-node 'fin #f)
                   (make-error-node 'trunc 'truncated #f)
                   (make-error-node 'over 'too-long #f)
                   (make-error-node 'reject 'rejected #f))
                  'default-eof #f))

  ;; The machine whose ONLY default-EOF consumer is the counted consume: the
  ;; entry routes EOF to the finish, so nothing but `body` credits the default
  ;; declaration to the emitted errs table, and no error node names it or shares
  ;; its code and reason. compile.sls's reached-declaration walk must credit
  ;; the declaration on exactly this shape.
  (define (make-only-consumer-machine)
    (make-machine 'onlycc 'start
                  (list (make-uint-field 'len 8 2 #f))
                  '() '()
                  (list (make-error-declaration 'default-eof 'eof "unexpected end of input" #f)
                        (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))
                  (list (make-byte-dispatch-node
                         'start
                         (list (make-byte-case (make-exact-byte-matcher 0)
                                               (make-edge 'body 'advance) #f))
                         (make-edge 'reject 'reexecute)
                         'fin #f)
                        (make-counted-consume-node 'body 'len 'done #f #f)
                        (make-stop-node 'done #f)
                        (make-finish-node 'fin #f)
                        (make-error-node 'reject 'rejected #f))
                  'default-eof #f))

  ;; The ENTRY is a counted consume with a zero initial and an error node for
  ;; `next`: the only shape that reaches the finish arm's zero-count route
  ;; (a parser parked by need-input holds a positive count, so only a fresh
  ;; parser arrives there with zero). It verifies clean:
  ;; the entry's walk joins the default EOF error with the error node, tier 0.
  (define (make-entry-zero-machine)
    (make-machine 'entryzero 'body
                  (list (make-uint-field 'len 8 0 #f))
                  '() '()
                  (list (make-error-declaration 'default-eof 'eof "unexpected end of input" #f)
                        (make-error-declaration 'empty 'unexpected-byte "empty body rejected" #f))
                  (list (make-counted-consume-node 'body 'len 'bad #f #f)
                        (make-error-node 'bad 'empty #f))
                  'default-eof #f))

  ;; The same loop with `body` wrapped in a span --
  ;; `:` -> `open` -> `body` -> `close` -> `,` -- the HTTP fixed-body shape.
  ;; TWO variants, because the emitter renders two span-completion arms and only
  ;; one is a call (the completion callback is optional): `complete?`
  ;; declares `on-done` and names it in the span. The machine NAME differs per
  ;; variant so both generated libraries can be resident at once. `body`'s EOF
  ;; route is its OWN truncation node: the shared one is reached with no span
  ;; open, and pass 7 rejects one node carrying both states.
  (define (make-counted-span-machine complete?)
    (make-machine (if complete? 'spanfull 'spanbare) 'idle
                  (list (make-uint-field 'len 32 0 #f))
                  (append (list (make-callback-declaration 'on-data 'span-data #t '() #f #f))
                          (if complete?
                              (list (make-callback-declaration 'on-done 'span-complete #t '() #f #f))
                              '()))
                  (list (make-span-declaration 'sp 'on-data (if complete? 'on-done #f) #f))
                  (decls)
                  (list
                   (make-byte-dispatch-node
                    'idle
                    (list (make-byte-case (make-byte-range-matcher 48 57)
                                          (make-edge 'len 'reexecute) #f))
                    (make-edge 'reject 'reexecute)
                    'fin #f)
                   (make-integer-accumulate-node
                    'len 'len 10 'len
                    (make-edge 'colon 'reexecute)
                    'over 'trunc #f)
                   (make-byte-dispatch-node
                    'colon
                    (list (make-byte-case (make-exact-byte-matcher 58)
                                          (make-edge 'open 'advance) #f))
                    (make-edge 'reject 'reexecute)
                    'trunc #f)
                   (make-span-start-node 'open 'sp 'body #f)
                   (make-counted-consume-node 'body 'len 'close 'trunc2 #f)
                   (make-span-end-node 'close 'sp 'comma #f)
                   (make-byte-dispatch-node
                    'comma
                    (list (make-byte-case (make-exact-byte-matcher 44)
                                          (make-edge 'clear 'advance) #f))
                    (make-edge 'reject 'reexecute)
                    'trunc #f)
                   (make-field-action-node 'clear 'clear '(len) 'idle #f #f)
                   (make-finish-node 'fin #f)
                   (make-error-node 'trunc 'truncated #f)
                   (make-error-node 'trunc2 'truncated #f)
                   (make-error-node 'over 'too-long #f)
                   (make-error-node 'reject 'rejected #f))
                  'default-eof #f))

  ;; A u64 count above the fixnum range: the subtraction is bignum arithmetic
  ;; and both lanes must agree with the expected value, not only
  ;; with each other.
  (define (make-big-count-machine)
    (make-machine 'bigcount 'start
                  (list (make-uint-field 'big 64 9223372036854775808 #f))
                  '() '()
                  (list (make-error-declaration 'default-eof 'eof "unexpected end of input" #f)
                        (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))
                  (list (make-byte-dispatch-node
                         'start
                         (list (make-byte-case (make-exact-byte-matcher 0)
                                               (make-edge 'body 'advance) #f))
                         (make-edge 'reject 'reexecute)
                         #f #f)
                        (make-counted-consume-node 'body 'big 'done #f #f)
                        (make-stop-node 'done #f)
                        (make-error-node 'reject 'rejected #f))
                  'default-eof #f)))
