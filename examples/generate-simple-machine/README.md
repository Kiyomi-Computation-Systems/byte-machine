# Example: generate a simple machine

A minimal, end-to-end demonstration of the byte-machine v0.1 flow, using **only**
the public procedural API (`(byte-machine graph)` for construction — never the
private tagged-vector constructors, per §27:1703).

The machine accepts exactly one byte, ASCII `'A'` (`0x41`), then stops. Any other
first byte is rejected with `unexpected-byte`; end of input before the byte is
`unexpected-eof`.

## Run it

From a clean checkout, at the repository root (nothing needs to be built first):

```
chez --libdirs src --program examples/generate-simple-machine/generate.sps
```

`chez` is your Chez Scheme executable (`scheme` on most installations; the
repository's build layer also accepts `-DBYTE_MACHINE_CHEZ_EXECUTABLE`). The
program writes the generated library to `example-simple.generated.sls` in the
current directory (git-ignored) and prints each step.

## Expected output

```
1. constructed and verified: simple
2. emitted generated library to example-simple.generated.sls
3. loaded the generated parser (depends only on (byte-machine runtime))
4. results:
   feed 'A' (0x41)  -> stopped, consumed 1
   feed 'B' (0x42)  -> error, code unexpected-byte at offset 0
done.
```

Set `BYTE_MACHINE_EXAMPLE_OUT` to write the generated library somewhere else.

## What it shows

1. **Construct** a machine through `(byte-machine graph)` — `make-machine`,
   `make-byte-dispatch-node`, `make-byte-case`, `make-exact-byte-matcher`,
   `make-edge`, `make-stop-node`, `make-error-node`, `make-error-declaration`.
2. **Compile** it with `compile-machine`; verification is mandatory and cannot be
   bypassed (`compilation-ok?` reports the result).
3. **Emit** the generated Scheme library with `emit-machine`.
4. **Load** it — the generated library imports only `(rnrs)` and
   `(byte-machine runtime)` (the dependency boundary of §26:1681; see
   [the integration guide](../../.reference/generated-code-integration-chez.md)).
5. **Run** it: `make-parser`, `parser-feed!`, and read `parser-result-status`,
   `parser-result-consumed`, and the `parser-error` fields.

See [`.reference/`](../../.reference/) for the full builder, runtime, and
field references.
