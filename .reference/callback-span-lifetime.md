# Callback and span lifetime

What a callback receives, how long it may hold it, and what the parser
guarantees about the bytes you feed it.

Both executors — the interpreter and a generated parser — behave identically
here except where a difference is called out.

---

## 1. The one rule

**The input range is valid only for the dynamic extent of the callback that
receives it**. When your span-data callback returns, the range it was
handed is no longer yours to read.

If you want the bytes afterwards, **copy them inside the callback**. There is no
later opportunity, and no accessor that will give them back.

```scheme
;; What the tests do, and what you should do.
(lambda (parser user-context bv from to)
  (let ((mine (make-bytevector (- to from))))
    (let loop ((i from))
      (if (>= i to)
          (begin (remember! mine) callback-continue)
          (begin (bytevector-u8-set! mine (- i from) (bytevector-u8-ref bv i))
                 (loop (+ i 1)))))))
```

Keeping `bv`, or a `(bv from to)` triple, is keeping a reference to storage the
runtime is about to stop guaranteeing anything about. The triple is the subtler
mistake: it looks like a description and is a retention.

## 2. What the runtime guarantees back

**The byte-machine runtime stores no feed bytevector or slice after
`parser-feed!` returns**. The parser you hold does not reach the
bytes you fed it. You may reuse or overwrite the buffer immediately.

This is not an aspiration. It is asserted in
[`test/common/retention-tests.sps`](../test/common/retention-tests.sps),
which holds a parser alive across a full collection and checks that a weak
reference to the bytevector it was fed reads `bwp` — in both executors. The same
test asserts the opposite direction on a fixture that retains on purpose, so the
first assertion is about the runtime rather than about a probe that always
answers "gone".

The structural reason is worth knowing, because it is what keeps the guarantee
from depending on a review: an open span records its position as a **slice
offset**, re-anchored at the start of every feed that finds a span
open, never as a pointer into a buffer. There is nothing to retain because nothing the parser stores means
anything outside the feed it came from.

### The three exemptions

Three application-owned carriers are **outside** the guarantee:

| Carrier | How it retains | Whose choice |
|---|---|---|
| **Callback closures** | your callback captured it | yours |
| **User context** | you passed it to `make-parser` | yours |
| **Callback error detail** | your callback returned it in `make-callback-failure` | yours |

If a bytevector reaches one of these, it stays reachable for as long as the
parser does, and that is correct behaviour rather than a leak. The third is the
one that surprises people: an explicit callback failure whose detail holds the
slice the callback was looking at leaves the parser's stored error holding your
input until the next `parser-reset!`.

If you do not want that, put a copy in the detail — the same rule as §1.

## 3. What a callback sees

A span-data callback is called as `(callback parser user-context bv from to)`; a
span-complete or event callback as `(callback parser user-context)`.

At callback entry both executors expose **identical committed parser state**:

- **fields** include every operation completed before the callback, and are
  **read-only** — `parser-field-ref` answers, and there is no setter. Allowing
  callbacks to mutate fields would bypass the closed IR;
- **stream offset and cursor** include every byte committed before the callback;
- **`parser-state-name`** names the *source* callback or span node, never a
  generated internal continuation — with one exception: at an **automatic
  feed-boundary fragment** there is no callback or span node to name, and the
  runtime answers the input node the executor stopped on. The answer is always
  a **bare symbol**; the span being flushed is reached through
  `parser-active-span`, not folded into the state name;
- **lifecycle is `busy`**, so `parser-feed!`, `parser-finish!`,
  `parser-resume!` and `parser-reset!` all raise from inside a callback. Every
  *read* accessor answers normally;
- **a span-data callback sees its span active**, **with the delivered mark
  already advanced to the fragment end**. The mark itself is not exported; its
  one public reader is `parser-error-span-offset` (§6), which is why the advance
  matters: a data callback that *fails* leaves the span open, and the error
  must not report the bytes that callback was just handed as withheld;
- **a span-complete callback sees that span inactive** — the span is
  closed before the completion callback runs, not after;
- **no error is installed** until a callback returns failure.

`user-context` is yours: the runtime neither copies nor interprets it, and it may
be mutable.

## 4. What a callback may return

Four outcomes:

| Return | Meaning |
|---|---|
| `callback-continue` | proceed |
| `callback-pause` | pause after this event is committed |
| a declared branch key (symbol) | decision callbacks only |
| `(make-callback-failure code detail)` | explicit failure. Two arguments always — `detail` is optional in the sense that `#f` is a legal value, not in the sense that it may be omitted |

**Span and event callbacks accept only `continue`, `pause`, or failure**;
the branch keys are for decision callbacks. Anything else is a
contract violation: the parser reports a `callback`-domain error with code
`callback-contract-violation`.

`callback-continue` and `callback-pause` are allocation-free singletons —
compare them, do not rebuild them.

## 5. Pausing, and what a pause holds

**A pause happens after the callback's delivered event has been committed, and
resume continues after that event — it is never delivered twice**.

For a span this has a specific consequence worth stating on its own: a pause
after the data fragment **retains only an internal `completion-pending`
continuation, never the input bytevector**. A paused parser is not
holding your buffer.

A span-data callback accepts or rejects its **complete** supplied range
atomically. There is no partial acceptance. If you need finer
backpressure, feed smaller slices — you keep ownership of every unconsumed
suffix.

## 6. Fragments are not tokens

A logical span produces **zero or more data fragments followed by exactly one
completion event**. How the fragments divide is decided by your feed
boundaries and your pauses, not by the grammar:

- ending a span emits `[mark,cursor)` if nonempty — and a span that
  ends having delivered nothing at all emits one *empty* fragment, so an empty
  span is observable;
- at a feed boundary an open span emits `[mark,end)` if nonempty, stays open, and
  begins its next fragment at the next feed's `start`;
- **every other empty fragment is suppressed**: a flush that finds
  nothing new, and the empty tail of a span whose bytes already went out.

**Do not treat fragment boundaries as semantic boundaries**. Feeding
the same bytes in a different number of calls gives you a different sequence of
fragments carrying the same concatenation, and the test suite asserts exactly
that: identical fragment traces between the two executors on the same schedule,
and *different* raw traces across schedules whose coalesced form is invariant.

On an error, the runtime does **not** flush a final partial fragment and does
**not** synthesize a completion; fragments already emitted at earlier feed
boundaries remain observable.

What the error withheld is reported on the error instead.
`(parser-error-span e)` names the span the error abandoned, and
`(parser-error-span-offset e)` is the stream offset where its withheld bytes
begin; both are `#f` when no span was open. The bytes from there to
`(parser-error-offset e)` are exactly the ones the span took and you were never
handed, and every byte it took before that offset reached your data callback in
an earlier fragment, if you bound one. So, with the data callback bound, the
fragments you received followed by that range are the span's bytes up to the
error, whichever way the input was split into feeds: a size limit counted that
way does not depend on where the network split the bytes. The test that checks
this runs every schedule of up to three feeds over three machines, in both
executors.

The range is empty whenever the span took nothing since its last fragment:
always at `parser-finish!`, where the last feed's boundary flush already handed
over everything the span took; when a data callback returns a failure, because
it was handed its fragment; and when a byte is refused before the span takes
any in that feed. Whether the range's last byte belongs to the
token is your grammar's question: when the error node was entered over an
`advance` edge, that byte is the one whose transition led to the error.

A body's ordinary carrier is a counted consume, which commits its
bytes in bulk; that changes nothing above — fragment boundaries are still your
feed boundaries, and when the count and the input run out at the same byte the
completion event arrives in that same feed.

## 7. Escaping, and poisoning

Expected failures use the return value. **If a callback raises, or escapes
non-locally, the parser is poisoned**: the condition propagates out
of `parser-feed!`, and the parser will refuse every further operation with the contract code
`poisoned-parser` — except `parser-reset!`, which is the one operation a poisoned
parser may run.

A reset clears span state, the pause continuation, the stored error, and the stop,
finish and poison state, and the parser is reusable from its entry
node.

## 8. Why the verifier is part of this contract

No reachable path may run an explicit pause node, or an event or decision
callback invocation, while a span is active — only the active span's own data
callback may pause before the span closes. **The verifier enforces this** —
diagnostic `span-active-at-pause`; its sibling `span-active-at-exit` enforces a
different rule (no reachable path reaches a successful stop or finish with a
span active). The restriction is what makes the no-retention guarantee possible
without invoking unrelated callbacks after a pause request.

So §2's guarantee is not independent of verification. A machine that reached this
document without passing `verify-machine` has not earned it.

---

## Where this is checked

| Claim | Checked by |
|---|---|
| no bytevector survives the return | `test/common/retention-tests.sps`, layer 1 |
| the oracle can see retention at all | same file, layer 2 (the negative control) |
| all three exemptions really carry | same file, layer 3 — user context, a callback closure, and callback error detail |
| the weak-reference instrument discriminates | `test/common/liveness-probe-tests.sps` |
| fragment rules, in both executors | `test/common/differential-span-tests.sps` |
| an error reports the span it abandoned and where its withheld bytes begin, under every schedule of up to three feeds | `test/common/differential-abandoned-span-tests.sps` |
| pause, escape and poisoning | `test/common/differential-callback-tests.sps` |
