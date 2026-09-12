# Generated-code integration for Chez

How a verified machine becomes an importable `.sls`, and how a consumer runs the
parser it defines.

This is `§27:1697` of
[the implementation plan](../plans/byte-machine-implementation-plan.md) (the
"generated-code integration guide for Chez"), and it carries `§26:1681`'s release
criterion — that "public libraries and generated-runtime dependency boundaries
are documented". Everything below was checked against the code
(`src/byte-machine/compile.sls`, `src/byte-machine/runtime.sls`) and the
end-to-end example lane (`test/common/example-one-byte-tests.sps`).

Applies to byte-machine at v0.1. A generated parser and the reference interpreter
(`(byte-machine interpret)`) share the same runtime API and contracts; this guide
is written for the generated lane.

---

## 1. The dependency boundary rule

Construction, verification, and compilation live in
`(byte-machine graph)`, `(byte-machine verify)`, `(byte-machine compile)`, and
`(byte-machine interpret)`. **A generated parser depends on `(byte-machine
runtime)` alone at run time — on none of those four.** This is `§7.2`'s dependency
direction: `runtime` sits below `graph`/`verify`/`compile` and depends on nothing
above it, and the runtime library is, in the plan's words, "the only byte-machine
library required by emitted parsers".

The rule is enforced by construction, not by convention. The library
`render-machine` emits opens with exactly:

```scheme
(library (generated <machine-name>)
  (export <binding>)
  (import (rnrs) (byte-machine runtime))
  ...)
```

Its only imports are `(rnrs)` and `(byte-machine runtime)`. It calls only the
small runtime surface (`byte-machine-make-compiled-machine`, the feed-outcome and
error constructors, the callback/span step helpers) and never builder, verifier,
normalizer, interpreter, or emitter code (`§19.3`). Because the emitter emits a
*complete* importable library, no file includes another: the consumer reaches the
parser **by `import`, never by `include`** (`§9.6` item 5).

So a deployed application ships the generated `.sls` plus `(byte-machine
runtime)`; it does not ship, or need to load, the compiler.

---

## 2. The generation flow

Three procedures in `(byte-machine compile)`, in order:

- **`(compile-machine machine options)`** — verifies `machine` internally (it
  calls `verify-machine`; you do not verify separately) and, on success,
  normalizes it. Returns a *compilation* value. v0.1 accepts only `'()` for
  `options` and raises on anything else.
- **`(compilation-ok? compilation)`** — `#t` when verification passed; on `#f`,
  `(compilation-diagnostics compilation)` returns the diagnostics and the
  compilation cannot be rendered.
- **`(render-machine compilation binding)`** — returns the complete generated
  library as a canonical UTF-8/LF **bytevector**. `binding` is the symbol the
  library will export (the caller's chosen name for the compiled machine),
  rejected if it collides with R6RS syntax, a runtime export, or an emitted
  internal identifier (`§20`).
- **`(emit-machine compilation binding port)`** — renders as above, writes the
  bytes to the supplied **binary output** `port`, and returns emission metadata
  (IR fingerprint and byte length). This is the only procedure here that does
  I/O; `compile-machine` and `render-machine` are pure.

`compile-machine` performs no Scheme compilation, no `eval`, and no file write
(`§9.2`). Verification cannot be bypassed: `render-machine` raises on a
compilation whose `compilation-ok?` is `#f`.

Generation is deterministic: the same verified machine, options, and binding
produce byte-identical source on every platform cell (`§20`).

---

## 3. Consuming the parser

The consumer imports the generated library and `(byte-machine runtime)`, then
uses the runtime API on the compiled-machine value the library exports.

- **`(make-parser compiled-machine callback-bindings user-context)`** —
  `callback-bindings` is a proper list of two-element lists `(list (list 'name
  proc) ...)`, or `'()` when the machine declares no callbacks; `user-context` is
  opaque application data (or `#f`).
- **`(parser-feed! parser bv start end)`** — runs the parser over the slice
  `[start, end)` of bytevector `bv` (absolute indices; `0 <= start <= end <=
  (bytevector-length bv)`). Returns a *parser-result*.
- **`(parser-finish! parser)`** — signals end of input. Returns a parser-result.
- **`(parser-resume! parser)`** and **`(parser-reset! parser)`** — resume after a
  pause and full reset, respectively.

Read a parser-result with `parser-result-status`, `parser-result-next`,
`parser-result-consumed`, `parser-result-stream-offset`, and
`parser-result-error`. Feed statuses are `need-input`, `stopped`, `error`,
`finished`, and `paused`; for a feed, `next` is the absolute index past the last
consumed byte and `consumed` is `next - start`. On `error`,
`parser-result-error` holds a parser-error read with `parser-error-code`,
`-reason`, `-node-name`, `-offset`, `-position-kind`, and the rest of that family.
Other live accessors: `parser-field-ref`, `parser-state-name`,
`parser-stream-offset`, `parser-active-span`, `parser-user-context`,
`parser-lifecycle`. Callback outcomes are the runtime singletons
`callback-continue` / `callback-pause` and `(make-callback-failure code detail)`.

---

## 4. Source and AOT execution

The same generated `.sls` and the same `(byte-machine runtime)` serve both Chez
execution modes (`§7.3`, `§24.2`):

- **Source mode** loads the `.sls` directly.
- **AOT mode** compiles the library to a native object ahead of time and links
  it; `§24.3` keeps those objects per version/OS/architecture and never commits
  them.

The compiled machine carries an ABI version (currently `5`), and
`byte-machine-make-compiled-machine` checks it as its first action, raising
`"generated-runtime ABI mismatch"` on a mismatch. This guard is load-bearing in
the AOT lane: Chez prefers a compiled object over source and staleness is
transitive across imports, so a stale generated object can meet a newer runtime —
the check turns that into a clean assertion rather than a silent wrong answer.

---

## 5. A worked example

Mirrors `test/common/example-one-byte-tests.sps`. **The generator** — a build-time
program that imports the compiler:

```scheme
(import (rnrs) (byte-machine graph) (byte-machine compile))

;; `one-byte` is a machine built only through (byte-machine graph),
;; with machine-name `one-byte`.
(let ((comp (compile-machine one-byte '())))
  (unless (compilation-ok? comp)
    (assertion-violation 'build "verification failed"
                         (compilation-diagnostics comp)))
  (call-with-port (open-file-output-port "one-byte.sls" (file-options no-fail))
    (lambda (p)
      ;; writes (library (generated one-byte) (export one-byte-parser) ...)
      (emit-machine comp 'one-byte-parser p))))
```

**The consumer** — imports the generated library by `import` and nothing from the
compiler:

```scheme
(import (generated one-byte)      ; the generated library
        (byte-machine runtime))   ; the ONLY byte-machine library it needs

(let* ((parser (make-parser one-byte-parser '() #f))
       (r      (parser-feed! parser (make-bytevector 1 0) 0 1)))
  (parser-result-status r)    ; => stopped
  (parser-result-consumed r)) ; => 1
```

`one-byte-parser` is the exported binding (the symbol handed to `emit-machine`);
`(generated one-byte)` is the library name derived from the machine's name. The
example lane reaches the same boundary dynamically — `(load "one-byte.sls")` then
`(eval 'one-byte-parser (environment '(generated one-byte)))` — where a deployed
consumer uses the static `import` above.
