# Usage

This page builds the words parser from the home page, one step at a time.
It assumes the libraries already import; if they don't, start with
[Installing](installing.md).

## The five steps

1. **Build** a machine: a value describing states and the bytes that move
   between them.
2. **Verify** it. The verifier finds machines that could loop forever, get
   stuck, or end in the wrong place.
3. **Compile** it into a generated library: a plain `.sls` file.
4. **Make a parser** from the generated library, once per input stream.
5. **Feed** it bytes as they arrive, and **finish** it when the input ends.

Steps 1 to 3 happen once, at build time. Steps 4 and 5 happen in your
application, which needs only the generated library and
`(byte-machine runtime)`.

The complete, runnable program is in
[`examples/words/`](../examples/words/): `words.sls` is step 1,
`generate.sps` is steps 2 and 3, and `run.sps` is steps 4 and 5.

## 1. Build the machine

A machine is a graph. Each *node* is a state the parser can be in, and
*edges* say which node comes next. The parser starts at the *entry* node.

The words parser has three reading states:

- `between`: before a word. A letter starts a word; a space is skipped; a
  newline ends the line.
- `in-word`: inside a word. A letter extends it; anything else ends it.
- `after-word`: just after a word. A space goes back to `between`; a newline
  ends the line.

And four that don't read anything: `open` and `close` mark where a word
starts and ends, `done` stops the parser, and `reject` reports an error.

First, the three byte classes, as *matchers*:

```scheme
(define (byte c) (char->integer c))
(define is-letter (make-byte-range-matcher (byte #\a) (byte #\z)))
(define is-space (make-exact-byte-matcher (byte #\space)))
(define is-newline (make-exact-byte-matcher (byte #\newline)))
```

Then the machine:

```scheme
(define words
  (make-machine 'words 'between                ; name, entry node
    '()                                         ; fields: none
    (list (make-callback-declaration 'on-word 'span-data #t '() #f #f)
          (make-callback-declaration 'on-word-end 'span-complete #t '() #f #f))
    (list (make-span-declaration 'word 'on-word 'on-word-end #f))
    (list (make-error-declaration 'bad 'unexpected-byte
            "expected a letter, a space or a newline" #f)
          (make-error-declaration 'eof 'unexpected-eof
            "input ended before the newline" #f))
    (list
     (make-byte-dispatch-node 'between
       (list (make-byte-case is-letter (make-edge 'open 'reexecute) #f)
             (make-byte-case is-space (make-edge 'between 'advance) #f)
             (make-byte-case is-newline (make-edge 'done 'advance) #f))
       (make-edge 'reject 'reexecute) #f #f)
     (make-span-start-node 'open 'word 'in-word #f)
     (make-byte-dispatch-node 'in-word
       (list (make-byte-case is-letter (make-edge 'in-word 'advance) #f))
       (make-edge 'close 'reexecute) #f #f)
     (make-span-end-node 'close 'word 'after-word #f)
     (make-byte-dispatch-node 'after-word
       (list (make-byte-case is-space (make-edge 'between 'advance) #f)
             (make-byte-case is-newline (make-edge 'done 'advance) #f))
       (make-edge 'reject 'reexecute) #f #f)
     (make-stop-node 'done #f)
     (make-error-node 'reject 'bad #f))
    'eof                                        ; the error for end of input
    #f))                                        ; label
```

`make-machine` takes, in order: a name, the entry node, fields, callbacks,
spans, errors, nodes, the default end-of-input error, and a label. Most
constructors end with a *label*: a symbol or string of your own, carried into
diagnostics so you can find the source of a problem. `#f` means none.

Three ideas carry most of the weight:

**Edges have a mode.** `advance` consumes the byte and moves on. `reexecute`
moves to the target *without* consuming, so the target sees the same byte.
That is how `between` hands a letter to `open` and on to `in-word`: the
letter is looked at twice and consumed once.

**A byte dispatch has cases and a fallback.** At most one case matches a
given byte: the verifier rejects cases that overlap. If none matches, the
fallback edge is taken: here, `reject` or `close`.

**Spans mark ranges.** `open` starts the span `word` and `close` ends it.
Every byte consumed in between belongs to the word, and reaches the span's
data callback, `on-word`. When the span ends, `on-word-end` runs.

What about end of input? Each reading node takes an *EOF target*: the fourth
argument of `make-byte-dispatch-node`, `#f` here. `#f` means "use the
machine's default", which is the error `eof`. So input that stops before the
newline is an error. [Building machines](machines.md) covers every node kind.

## 2. Verify it

```scheme
(import (byte-machine verify))

(define v (verify-machine words))
(verification-ok? v)   ; => #t
```

`verify-machine` never raises on a bad machine. It returns a result, and
`verification-diagnostics` lists what is wrong. Here is a real one. An
earlier draft of this machine had no `after-word` node: `close` went straight
back to `between`. The verifier's first diagnostic said:

```scheme
(diagnostic-code d)   ; => zero-progress-cycle
(diagnostic-path d)   ; => (between open in-word close between)
```

Every edge on that path is a `reexecute` or a step that reads nothing, so
nothing stops the parser from going round it forever. A human can see that
`in-word` only reaches `close` on a non-letter and `between` only reaches
`open` on a letter, so it never actually loops. The verifier doesn't reason
about bytes on a cycle; it insists that every cycle consume one. Adding
`after-word`, which consumes the space or newline, settles it.

See [The verifier](verifier.md) for every code it can report.

## 3. Compile and generate

```scheme
(import (byte-machine compile))

(define compilation (compile-machine words '()))
(compilation-ok? compilation)   ; => #t

(call-with-port (open-file-output-port "generated/words.sls")
  (lambda (port) (emit-machine compilation 'words-parser port)))
```

`compile-machine` verifies the machine again itself, so you can't skip
verification by accident. `emit-machine` writes a complete library:

```scheme
(library (generated words)
  (export words-parser)
  (import (rnrs) (byte-machine runtime))
  ...)
```

The library is named after the machine, `(generated words)`. It exports one
binding, the name you passed to `emit-machine`. Save it as
`generated/words.sls` under a folder on the library path, and any program can
import it. Generation is deterministic: the same machine gives the same bytes
every time, so you can commit the file and review changes as a diff.
[Generated code](generating.md) has the details.

## 4. Make a parser

```scheme
(import (rnrs) (generated words) (byte-machine runtime))

;; The bytes in [from, to) are yours only while the callback runs: copy them.
(define (text bv from to)
  (let ((copy (make-bytevector (- to from))))
    (bytevector-copy! bv from copy 0 (- to from))
    (utf8->string copy)))

(define parser
  (make-parser words-parser
    (list (list 'on-word
                (lambda (parser context bv from to)
                  (display "on-word ") (write (text bv from to)) (newline)
                  callback-continue))
          (list 'on-word-end
                (lambda (parser context)
                  (display "on-word-end\n")
                  callback-continue)))
    #f))
```

`make-parser` takes the generated machine, a list of `(name procedure)`
bindings, and a *context*: any value you want handed to every callback. Here
it is `#f`.

A span data callback receives the parser, the context, a bytevector and a
range `[from, to)`. That range points into the bytevector **you** fed; it is
not a copy. Copy what you need before returning. Every callback returns an
*outcome*: `callback-continue` to carry on. [Callbacks and
spans](callbacks.md) lists the others.

A parser holds the state of one input stream. Make one per connection, file
or message source.

## 5. Feed it

```scheme
(define (feed! string)
  (let* ((bv (string->utf8 string))
         (result (parser-feed! parser bv 0 (bytevector-length bv))))
    (display "feed ") (write string)
    (display " -> ") (display (parser-result-status result))
    (display ", consumed ") (display (parser-result-consumed result))
    (newline)))

(feed! "hello wor")
(feed! "ld\n")
```

```text
on-word "hello"
on-word-end
on-word "wor"
feed "hello wor" -> need-input, consumed 9
on-word "ld"
on-word-end
feed "ld\n" -> stopped, consumed 3
```

`parser-feed!` takes a bytevector and a range `[start, end)`, so you can feed
part of a larger buffer without copying it. It returns a *result*:

- `need-input`: every byte was used and the parser wants more. `"hello wor"`
  ends mid-word, so the parser handed over the part of the word it had
  (`"wor"`) and stopped, remembering it is inside a word.
- `stopped`: the parser reached a stop node, `done`.

The word `world` arrived as two fragments, `"wor"` and `"ld"`. How a span is
cut into fragments depends only on where your feeds begin and end. Join them
up if you need the whole word.

When the input ends, call `parser-finish!`. For this machine that is always an
error unless it already stopped, because the default end-of-input route is
the `eof` error. [Running a parser](running.md) covers every status, pausing
and resetting.
