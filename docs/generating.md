# Generated code

byte-machine turns a machine into Scheme source: an ordinary R6RS library you
save, import and ship. This page covers what it writes and how to live with
it.

## From machine to file

Everything here is in `(byte-machine compile)`.

```scheme
(define compilation (compile-machine machine '()))
```

`compile-machine` verifies the machine and prepares it for code generation.
The second argument is reserved for options and must be `'()`. It does no
I/O and runs no code.

```scheme
(compilation-ok? compilation)          ; #t if the machine verified
(compilation-diagnostics compilation)  ; the verifier's diagnostics otherwise
```

Then render it, either to a bytevector or straight to a port:

```scheme
(render-machine compilation 'words-parser)        ; => a bytevector of UTF-8 source
(emit-machine compilation 'words-parser port)     ; writes the same bytes to a binary port
```

Both raise if the compilation failed verification, so a broken machine can't
reach a file. `emit-machine` returns a metadata value describing what it wrote.

## What the library looks like

```scheme
(library (generated words)
  (export words-parser)
  (import (rnrs) (byte-machine runtime))
  (define errs (quote #(...)))
  (define (exec state offset bv start end finish? fieldv psr cbv)
    (define (%s0 pos st off pk) ...)
    ...)
  (define words-parser
    (byte-machine-make-compiled-machine 9 98211950071450726 0 exec (quote #(...)))))
```

- **The name** is `(generated <machine-name>)`, taken from `make-machine`'s
  first argument.
- **The export** is one binding, the name you pass to `render-machine` or
  `emit-machine`. Its value is a compiled machine: pass it to `make-parser`.
- **The imports** are `(rnrs)` and `(byte-machine runtime)`, nothing else.
- **The body** has one procedure per state. Each reads a byte, tests it, and
  calls the next state's procedure directly. A byte class compiles to one
  range comparison per run of bytes, not a test per byte. Nothing is
  allocated per byte, with one exception: reading digits into a 64-bit field
  allocates about 32 bytes per digit, because its overflow check uses bignum
  arithmetic. 8-, 16- and 32-bit fields allocate nothing.

The binding name follows the same rule as other names (lowercase letters,
digits, hyphens). The generator refuses the core keywords (`define`,
`lambda`, `if` and the like), the runtime's exports, and names the generated
body uses internally, such as `exec`. It does **not** refuse every name
`(rnrs)` exports: a binding such as `list` or `guard` renders a library that
then fails to load. Pick a distinctive name, like `words-parser`.

## Where to put it

A library named `(generated words)` lives at `generated/words.sls` under a
folder on the library path. Then any program can write:

```scheme
(import (generated words) (byte-machine runtime))
```

You can also `load` the file and reach the binding with `eval`, which is
handy in tests. In an application, prefer the static `import`.

## Commit it, or generate it in the build

The same machine always renders to the same bytes, on every platform. That
gives you a choice:

- **Commit the generated file.** Changes to the grammar show up in review as
  a diff of the parser. Add a check to your test suite that renders the
  machine again and compares it with the committed file, byte for byte, so
  the two can't drift.
- **Generate it as a build step.** Nothing generated lives in your
  repository, and your build needs byte-machine's compiler.

[chez-httparse](https://github.com/Kiyomi-Computation-Systems/chez-httparse)
commits its parsers and checks them with exactly that kind of test.

## Versions

The generated library calls into `(byte-machine runtime)` through a small,
versioned interface. The version is written into the library (the `9` in
`byte-machine-make-compiled-machine 9 ...` above) and checked first thing when
the library loads. If you upgrade byte-machine and the interface changed, an
old generated library fails at once with `generated-runtime ABI mismatch`.
Regenerate it.

The interface version is not the release version, and most releases don't
change it. The [changelog](../CHANGELOG.md) says when one does.

## Source or compiled

Chez can run the generated library from source, or compile it ahead of time
into a native object. Both work, and byte-machine's test suite runs its
programs both ways.

Compiled objects are specific to the Chez version, operating system and
architecture that built them. Treat them as build output; don't commit them.
Chez also prefers a compiled object over its source, so after regenerating,
recompile or delete stale objects. The version check above catches the worst
case, a stale object meeting a newer runtime, but only when the interface
changed.
