# Security Policy

## Supported versions

| Version | Supported |
|---|---|
| 0.8.x (latest) | ✅ |
| < 0.8 | ❌ |

## Reporting a vulnerability

Please report suspected vulnerabilities privately via GitHub:
**Security → Report a vulnerability** on this repository. Do not open a
public issue.

You can expect an acknowledgement within 7 days.

byte-machine generates parsers that run on untrusted input, often network
input. Reports are especially welcome on:

- **Agreement with the machine.** A generated parser that accepts, rejects,
  or delivers bytes differently from the verified machine it was generated
  from, or differently from `(byte-machine interpret)` running that machine.
- **Feed splitting.** A result that depends on how the input was split into
  feeds, beyond where span fragments fall (see
  [Fragments](docs/callbacks.md#fragments)). Split-dependent parsing is the
  root of HTTP request smuggling.
- **Resource use.** A verified machine whose parser loops without consuming
  input, allocates per input byte (other than a 64-bit field's value at or
  above 2^60), or keeps a reference to a fed bytevector after the feed
  returns (see [The lifetime rule](docs/callbacks.md#the-lifetime-rule)).
- **Fields and counts.** An overflow that a field's accumulation check
  misses, or a counted read that consumes more or fewer bytes than its count.
- **Spans.** A range handed to a data callback that lies outside the
  bytevector range that was fed.
- **Generation.** A machine or output binding that puts code into the
  emitted library that the machine does not describe.

Please include your platform, Chez Scheme version, the byte-machine version
or commit, the smallest machine that shows the problem, and the input with
the feed split that triggers it.

## What is not a vulnerability

- **A grammar that accepts what its protocol forbids.** The verifier checks
  a machine's structure, such as loops that read nothing, end-of-input paths
  and span state. It does not check that a machine implements a protocol
  correctly. That is the grammar's job; report it to the project that owns
  the grammar. [Testing a grammar](docs/testing.md) shows how to test one.
- **A callback that raises.** Callbacks run your code. A raise poisons the
  parser by design, and only a reset recovers it (see
  [A callback raised](docs/errors.md#a-callback-raised)).
- **Bytes you kept.** A closure bound as a callback, the parser's context,
  and a callback failure's `detail` can hold your bytes for as long as the
  parser lives. The runtime keeps none of them.
