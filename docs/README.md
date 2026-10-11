# byte-machine

byte-machine builds fast, resumable byte parsers for Chez Scheme, in the
manner of [llparse](https://github.com/nodejs/llparse).

You describe a parser as a state machine over bytes, using ordinary Scheme
procedures. byte-machine checks the machine and writes it out as a plain R6RS
library. That library parses input in pieces: feed it bytes as they arrive,
split anywhere, and it calls your functions to say what it found.

The generated library needs only `(rnrs)` and one small runtime library,
`(byte-machine runtime)`. Your application does not load the builder, the
checker or the code generator.

💡 These pages were generated from [Markdown](../docs) with
[chez-cmark-gfm](https://github.com/Kiyomi-Computation-Systems/chez-cmark-gfm).

## A taste

A machine that reads lowercase words separated by spaces, ending at a
newline. Each word is a *span*: its bytes are handed to a callback as they
arrive.

```scheme
(define words
  (make-machine 'words 'between '()
    (list (make-callback-declaration 'on-word 'span-data #t '() #f #f)
          (make-callback-declaration 'on-word-end 'span-complete #t '() #f #f))
    (list (make-span-declaration 'word 'on-word 'on-word-end #f))
    (list (make-error-declaration 'bad 'unexpected-byte "expected a letter, a space or a newline" #f)
          (make-error-declaration 'eof 'unexpected-eof "input ended before the newline" #f))
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
    'eof #f))
```

(`is-letter`, `is-space` and `is-newline` are byte matchers, defined in the
full program.) Generate it once, at build time. Then feed it one line split
across two reads, in the middle of a word:

```scheme
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

The parser kept no copy of `"hello wor"`. It remembered only that it was
inside a word, and carried on from there when `"ld\n"` arrived.

The complete program is in [`examples/words/`](../examples/words/), and
[Usage](usage.md) walks through it line by line.

## What you get

- **Resumable parsing.** Every state survives a feed boundary, so a token
  split across any number of feeds parses exactly as it does in one buffer.
- **No input buffering.** Spans arrive as ranges into the bytevector you fed.
  The runtime keeps no reference to it once the feed returns, and the
  generated per-byte path allocates nothing, except when reading digits into
  a 64-bit field.
- **The pieces protocol parsers need.** Byte dispatch, byte classes, fixed
  sequences, keyword tables, unsigned integer fields with overflow checks,
  counted reads ("the next N bytes are the body"), callbacks that can pause
  the parser, and spans.
- **Precise errors.** An error names its code, the node it happened at, the
  stream offset, and whether the fault was at a byte, between two bytes, or
  at the end of input.
- **A checked machine.** Every machine passes a verifier before any code is
  written. It rejects unreachable states, loops that make no progress, and
  ends of input that land in the wrong place.
- **A second implementation to test against.** A reference interpreter runs
  the same machine. Run both on the same input and compare: a code-generator
  bug shows up as a disagreement.

## Contents

- [Installing](installing.md): what you need, and how to put the libraries on
  Chez's path.
- [Usage](usage.md): build, check, generate and run the words parser, step by
  step.
- [Building machines](machines.md): every node kind, matcher and edge.
- [Fields and counts](fields.md): numbers in the machine, read from the input
  or set by your application.
- [Callbacks and spans](callbacks.md): what your functions receive, and how
  long they may keep it.
- [Running a parser](running.md): feeding, finishing, pausing, resetting,
  and what each result means.
- [Errors](errors.md): input errors, callback failures, and programming
  mistakes.
- [The verifier](verifier.md): what it checks, and every diagnostic code.
- [Generated code](generating.md): what the generator writes, and how to ship
  it.
- [Testing a grammar](testing.md): compare the generated parser with the
  interpreter.
- [Why llparse-style parsers](llparse.md): where the design comes from, and
  why it suits HTTP and URI parsing in servers.
- [API reference](reference.md): every exported binding.
- [Building](building.md): build and test byte-machine itself, and this site.
