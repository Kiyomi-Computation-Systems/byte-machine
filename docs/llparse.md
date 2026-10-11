# Why llparse-style parsers

byte-machine follows the design of [llparse](https://github.com/nodejs/llparse),
the parser generator behind Node.js's HTTP parser. This page explains that
design, how byte-machine maps onto it, and why it suits the parsers a server
needs most: HTTP messages and URIs read straight off a socket.

## llparse and llhttp

llparse was written by Fedor Indutny for Node.js. You describe a parser in
TypeScript as a graph of nodes, and llparse compiles the graph to C. Its
documentation lives at [llparse.org](https://llparse.org/).

Its main user is [llhttp](https://github.com/nodejs/llhttp), the HTTP/1.x
parser in Node.js. llhttp replaced
[http_parser](https://github.com/nodejs/http-parser), a hand-written C state
machine, and became the default in
[Node.js 12](https://www.infoq.com/news/2019/05/nodejs-12-performance-modules/).
http_parser is now archived. The llhttp README gives the reasons for the
rewrite:

- http_parser had become hard to maintain: adding one HTTP method meant
  changes all over the code.
- The llhttp grammar is about 1,400 lines of TypeScript, against roughly
  2,500 lines of C plus headers for http_parser.
- Because the state graph is explicit, llparse can check it: for loops, and
  for spans reported correctly.
- In llhttp's own benchmark it is about 2.5 times as fast as http_parser.

Fedor Indutny's [JSConf EU 2019 talk](https://youtu.be/x3k_5Mi66sY) covers
the motivation.

## The model

An llparse-style parser is a state machine over bytes with three properties.

**The state is small and explicit.** At any moment the parser's whole
state is the node it is at, a few integer fields, and where the open span
began. There is no call stack, no buffer of pending input, no lookahead
queue.

**Each byte is looked at, then consumed or passed on.** A node reads the
current byte and picks an edge. The edge either consumes the byte or hands
the same byte to the next node. There is no backtracking: a parser never
needs a byte it has already consumed.

**Output is positions, not copies.** A span marks where a piece of input
starts and ends. The parser reports ranges into the caller's buffer through
callbacks; it never assembles a string.

Together these make the parser *resumable* at every byte. When a feed runs
out, the parser records the node it is at and returns. The next feed jumps
back to that node and carries on. Splitting the input anywhere, into any
number of pieces, gives the same result as one buffer, and the cost of a
split is one return and one call.

## How byte-machine maps onto it

| llparse                         | byte-machine                                               |
|:--------------------------------|:-----------------------------------------------------------|
| a node                          | a node                                                     |
| `node.match(...)`, `node.select(...)` | byte dispatch, sequence dispatch, keyword table      |
| `node.peek(...)`                | a byte case with a `reexecute` edge                        |
| `node.skipTo(...)`              | an `advance` edge                                          |
| `node.otherwise(...)`           | a byte dispatch's fallback edge                            |
| `span.start()`, `span.end()`    | span-start and span-end nodes                              |
| `p.invoke(...)` with C code     | callback nodes, field actions and branches                 |
| `p.property(...)`               | an unsigned integer field                                  |
| `p.error(...)`                  | an error node                                              |

The differences come from the target and from how much is checked:

- **The output is Scheme.** byte-machine writes an R6RS library that needs
  only `(rnrs)` and a small runtime. Your callbacks are Scheme procedures.
- **Arithmetic is part of the grammar.** Reading a number, counting a body
  and testing flags are node kinds with overflow checks and declared error
  routes, not code you write by hand.
- **Verification is mandatory and broad.** Besides loops and spans, the
  verifier checks overlapping cases, end-of-input routes, field operands and
  callback declarations: [33 codes](verifier.md#every-diagnostic-code).
- **There is a reference interpreter.** An independent implementation runs
  the same machine, so a code-generation bug shows up as a disagreement in
  a [differential test](testing.md).

## Why it suits servers

### Input arrives in pieces

TCP delivers a byte stream, not messages. A read can end anywhere: in the
middle of a header name, between the `\r` and `\n` of a line ending, inside a
chunk-size. A parser has two ways to handle that.

It can keep nothing between reads. [picohttpparser](https://github.com/h2o/picohttpparser),
for example, is stateless: when a request is incomplete the caller keeps the
bytes, reads more, and parses again from the start. That is simple and fast
when headers fit in one read, but every short read means buffering and
rescanning.

Or it can keep its place, as llhttp and byte-machine do. A short read costs
nothing extra: the parser has already handled every byte it was given, and
the next read continues where it stopped. The server never re-reads input
and never has to hold on to bytes the parser has finished with.

### Memory is bounded and owned by the server

A byte-machine parser's state doesn't grow with the input. It allocates
nothing per byte (reading digits into a 64-bit field is the one exception)
and keeps no reference to the buffers you feed it, so a server can reuse one read buffer for every read on a connection.
Spans arrive as ranges into that buffer, and the server decides what to
copy and when.

That makes limits easy to enforce at the right moment. A server can count a
header's bytes as its fragments arrive and refuse it at the limit, before the
header has finished arriving. If an error cuts a span short, the error
reports which bytes of it were never delivered, so the count stays exact
however the input was split.

### One grammar, no ambiguity

HTTP/1.1 framing has well-known traps. RFC 9112 requires a server to reject
whitespace between a header name and its colon (section 5.1), and says a
message with both `Transfer-Encoding` and `Content-Length` "might indicate an
attempt to perform request smuggling" (section 6.3). Request smuggling
([RFC 9112 section 11.2](https://www.rfc-editor.org/rfc/rfc9112#section-11.2);
[PortSwigger's guide](https://portswigger.net/web-security/request-smuggling))
works by finding inputs that two parsers on the same path read differently.

A state machine helps here because the accepted language is exactly the
graph. The verifier rejects cases that overlap, so every byte has one
transition in every state. Leniency, where a server needs it, becomes an
explicit decision: a settable field the application turns on, tested by a
field branch, rather than a side effect of how a loop was written. llhttp
takes the same approach with its lenient flags.

### Errors say exactly where

Every error carries the stream offset, the node, and whether the fault was
at a byte, between bytes, or at end of input. A server can map each code to a
response (`400 Bad Request`, `413 Content Too Large`, `414 URI Too Long`) and
log where in the stream it happened.

### Pausing at a known byte

Some protocols change in the middle of a connection. After an HTTP
`Upgrade` to WebSocket, or a `CONNECT`, the bytes after the headers belong to
a different protocol. A pause stops the parser at an exact byte and returns
control; the server hands the rest of the buffer to the next handler.
Pausing also gives backpressure: a callback can stop the parser until the
application catches up, and resuming loses nothing.

### URIs too

URI syntax ([RFC 3986](https://www.rfc-editor.org/rfc/rfc3986)) is a
sequence of components (scheme, authority, path, query, fragment)
separated by specific delimiter bytes, with fixed character classes inside
each. That is a natural fit for byte dispatch and spans: each component is a
span, each character class a matcher. A request target arrives as part of
the request line and can be split across reads like anything else, so a
resumable URI parser can run on the same bytes as the HTTP parser, without
copying them first.

## Two parsers built this way

- [chez-httparse](https://github.com/Kiyomi-Computation-Systems/chez-httparse)
  is an HTTP/1.x parser built with byte-machine. It replays llhttp's recorded
  conformance traces byte for byte, at every chunk size.
- [uriparse](https://github.com/Kiyomi-Computation-Systems/uriparse) is an RFC
  3986 URI parser that reads bytevectors, accepts input in any number of
  chunks, and gives the same result however the input was split.

## When it doesn't fit

The model reads each byte once, with no backtracking and no stack. That
covers most wire formats: line-based protocols, length-prefixed framing,
fixed headers, and grammars whose nesting has a fixed limit you can count in
a field. It does not cover grammars that need unbounded nesting, such as
arbitrarily deep JSON, or that need to look far ahead before deciding. Those
need a parser with a stack.

If your input always arrives whole and is small, a simpler parser over a
string may be all you need. The generator adds a build step, and pays off
when the input is a stream.

## Further reading

- llparse: [source](https://github.com/nodejs/llparse) and
  [documentation](https://llparse.org/)
- llhttp: [source and README](https://github.com/nodejs/llhttp)
- Fedor Indutny, [llhttp talk at JSConf EU 2019](https://youtu.be/x3k_5Mi66sY)
- [http_parser](https://github.com/nodejs/http-parser), llhttp's
  predecessor
- [picohttpparser](https://github.com/h2o/picohttpparser), a stateless
  HTTP parser
- [RFC 9112](https://www.rfc-editor.org/rfc/rfc9112): HTTP/1.1 message
  syntax
- [RFC 9110](https://www.rfc-editor.org/rfc/rfc9110): HTTP semantics,
  including status codes
- [RFC 3986](https://www.rfc-editor.org/rfc/rfc3986): URI syntax
- PortSwigger, [HTTP request smuggling](https://portswigger.net/web-security/request-smuggling)
