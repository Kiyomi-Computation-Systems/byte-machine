# Testing a grammar

A grammar is code, and it needs tests like any other. byte-machine gives you
two things that make those tests stronger than usual: a second
implementation to compare against, and a property every correct parser has,
that splitting the input differently changes nothing that matters.

## Two implementations

`(byte-machine interpret)` runs a machine directly, without generating code:

```scheme
(import (byte-machine verify) (byte-machine interpret))

(define interpreted (make-interpreted-machine (verify-machine words)))
(make-parser interpreted callbacks context)    ; the same API as a generated parser
```

`make-interpreted-machine` takes a verification result and refuses one that
failed. What it returns works everywhere a generated machine does: the same
`make-parser`, the same results, the same callbacks, the same errors (all but
`parser-error-state-id`, which is internal to each).

The interpreter and the code generator are written separately, on purpose.
Feed both the same input and compare. A bug in code generation shows up as a
disagreement. The interpreter is much slower; it is for tests, not
production.

## Compare everything, under every split

A useful test runs one input through both parsers, cut into feeds at
different places, and compares everything observable: each callback, in
order, and each result.

```scheme
;; A copy of [from, to) of bv.
(define (bytevector-slice bv from to)
  (let ((out (make-bytevector (- to from))))
    (bytevector-copy! bv from out 0 (- to from))
    out))

;; Feed `input` cut at `cuts`, and record every callback and every result.
(define (trace compiled-machine input cuts)
  (let* ((events '())
         (note! (lambda (e) (set! events (cons e events))))
         (parser
          (make-parser compiled-machine
            (list (list 'on-word
                        (lambda (p c bv from to)
                          (note! (list 'word (utf8->string (bytevector-slice bv from to))))
                          callback-continue))
                  (list 'on-word-end
                        (lambda (p c) (note! '(end)) callback-continue)))
            #f)))
    (let loop ((start 0) (cuts cuts))
      (let* ((end (if (null? cuts) (bytevector-length input) (car cuts)))
             (r (parser-feed! parser input start end)))
        (note! (list (parser-result-status r) (parser-result-stream-offset r)))
        (unless (null? cuts) (loop end (cdr cuts)))))
    (reverse events)))

(define input (string->utf8 "hello world\n"))

;; Every way to split the input into two feeds: both parsers must agree.
(do ((cut 0 (+ cut 1))) ((> cut (bytevector-length input)))
  (assert (equal? (trace words-parser input (list cut))
                  (trace interpreted input (list cut)))))
```

A trace looks like this, for cuts at 3 and 8:

```scheme
((word "hel") (need-input 3) (word "lo") (end)
 (word "wo") (need-input 8) (word "rld") (end) (stopped 12))
```

Compare the copied bytes, never the `(bv from to)` triples: the range is only
valid inside the callback.

Feed the bytes in a fixed order with a loop or `for-each`. R6RS doesn't
say what order `map` calls its procedure in, and a schedule fed out of order
makes both parsers agree on nonsense.

## Check the values, not just the agreement

Two implementations that agree can still both be wrong. Assert what the
answer should be, too: the joined word bytes, the final status, the error
code and offset for bad input.

A good property: for every split of the same input, the fragments joined per
span are identical, and so is the final result. Fragment boundaries move with
the feeds; the content mustn't.

## Test the bad inputs

Most parser bugs live on the error paths. For each error your grammar can
produce, feed an input that reaches it and assert the code, the offset and
the position kind. Feed truncated input and call `parser-finish!`. If your
grammar pauses, resume it at `parser-result-next` and check it carries on
correctly.

## Pin the generated file

If you commit the generated library, add a test that renders the machine
again and compares the bytes:

```scheme
(bytevector=? (render-machine (compile-machine words '()) 'words-parser)
              (call-with-port (open-file-input-port "generated/words.sls")
                get-bytevector-all))
```

A grammar change without a regenerated file then fails your suite instead of
shipping a stale parser.

## How byte-machine tests itself

byte-machine's own suite uses these ideas at scale: differential tests on
hand-written machines and on an HTTP grammar under every feed schedule,
randomly generated machines compared across both implementations, and
mutation testing that breaks the library on purpose to prove the tests
notice. Its harness lives in `test/support/` and is not a public API, but the
programs in [`test/common/`](../test/common/) are good models. See
[Building](building.md).
