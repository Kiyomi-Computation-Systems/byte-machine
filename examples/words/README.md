# Example: words

The parser the [documentation](../../docs/README.md) builds: lowercase words
separated by spaces, ended by a newline. Each word is a span, so its bytes
reach the `on-word` callback as they arrive, however the input is split.

Unlike [`generate-simple-machine`](../generate-simple-machine/), generating
and running are two programs, the way an application uses byte-machine:

- `words.sls` defines the machine, as the library `(words)`.
- `generate.sps` runs at build time. It verifies the machine and writes
  `generated/words.sls`, the library `(generated words)`.
- `run.sps` runs at run time. It imports `(generated words)` and
  `(byte-machine runtime)`, and nothing else from byte-machine.

## Run it

From this directory:

```sh
chez --libdirs ../../src:. --program generate.sps
chez --libdirs ../../src:. --program run.sps
```

`chez` is your Chez Scheme executable (`scheme` on some installations).
`generated/` is build output and is git-ignored.

## Expected output

```text
wrote generated/words.sls
on-word "hello"
on-word-end
on-word "wor"
feed "hello wor" -> need-input, consumed 9
on-word "ld"
on-word-end
feed "ld\n" -> stopped, consumed 3
```

The line `hello world` arrives in two feeds, split inside `world`. The
parser delivers the part it has (`"wor"`), returns `need-input`, and carries
on with `"ld"` when the next feed arrives. [Usage](../../docs/usage.md) walks
through every line.
