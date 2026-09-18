# Callback and span lifetime

What a callback receives, how long it may hold it, and what the parser
guarantees about the bytes you feed it.

This is `§27:1694` of
[the implementation plan](../.plans/byte-machine-implementation-plan.md). It is the
first document in this directory, not the first of §27's eleven deliverables to
exist — `:1701`'s changelog predates it by several milestones. Everything below was checked against the
code, not against the plan; where the two would differ, the code is described and
the difference is named.

Applies to byte-machine at Milestone 5. Both executors — the interpreter and a
generated parser — behave identically here except where a difference is called
out.

---

## 1. The one rule

**The input range is valid only for the dynamic extent of the callback that
receives it** (`§13:799`). When your span-data callback returns, the range it was
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
`parser-feed!` returns** (`§13:799`). The parser you hold does not reach the
bytes you fed it. You may reuse or overwrite the buffer immediately.

This is not an aspiration. It is asserted in
[`test/common/retention-tests.sps`](../test/common/retention-tests.sps),
which holds a parser alive across a full collection and checks that a weak
reference to the bytevector it was fed reads `bwp` — in both executors. The same
lane asserts the opposite direction on a fixture that retains on purpose, so the
first assertion is about the runtime rather than about a probe that always
answers "gone".

The structural reason is worth knowing, because it is what keeps the guarantee
from depending on a review: an open span records its position as a **slice
offset**, re-anchored at the start of every feed that finds a span
open (`§14:833`), never as a pointer into a buffer. There is nothing to retain because nothing the parser stores means
anything outside the feed it came from.

### The three exemptions

`§13:799` puts three application-owned carriers **outside** the guarantee:

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

At callback entry both executors expose **identical committed parser state**
(`§13:816`):

- **fields** include every operation completed before the callback, and are
  **read-only** — `parser-field-ref` answers, and there is no setter. Allowing
  callbacks to mutate fields would bypass the closed IR (`§13:801`);
- **stream offset and cursor** include every byte committed before the callback;
- **`parser-state-name`** names the *source* callback or span node, never a
  generated internal continuation (`§13:820`) — with the exception `§13:820`'s
  own second sentence makes: at an **automatic feed-boundary fragment** there is
  no callback or span node to name, and the runtime answers the input node the
  executor stopped on — a **bare symbol**. `§13:820` asks for that node "together
  with the active span name"; the code answers the node only, and the span name
  is reached through `parser-active-span` instead. That divergence is adjudicated in
  the plan's `§9.3:407-411` disposition and recorded in decision `0028`, which
  rejected widening the accessor to a compound value; it is named here rather
  than implied;
- **lifecycle is `busy`** (`§13:821`), so `parser-feed!`, `parser-finish!`,
  `parser-resume!` and `parser-reset!` all raise from inside a callback. Every
  *read* accessor answers normally;
- **a span-data callback sees its span active** (`§13:822`). The plan's same
  sentence adds "with the delivered mark already advanced to the fragment end",
  and **the code does not do that** — `byte-machine-span-fragment-step/v2` reads
  the mark as the fragment's *start* and leaves it alone, with a comment
  recording that the advance was written, measured to fail nothing in either
  lane, and deleted: every path out of a delivery either closes the span or
  crosses a feed boundary, where `§14:833`'s re-anchor overwrites the mark. The
  difference cannot reach you — `parser-span-mark` is not exported, so no
  callback can observe the mark at all — but it is named here rather than
  papered over;
- **a span-complete callback sees that span inactive** (`§13:823`) — the span is
  closed before the completion callback runs, not after;
- **no error is installed** until a callback returns failure (`§13:824`).

`user-context` is yours: the runtime neither copies nor interprets it, and it may
be mutable (`§13:801`).

## 4. What a callback may return

Four outcomes (`§13:803-808`):

| Return | Meaning |
|---|---|
| `callback-continue` | proceed |
| `callback-pause` | pause after this event is committed |
| a declared branch key (symbol) | decision callbacks only |
| `(make-callback-failure code detail)` | explicit failure. Two arguments always — `detail` is optional in the sense that `#f` is a legal value, not in the sense that it may be omitted |

**Span and event callbacks accept only `continue`, `pause`, or failure**
(`§13:812`); the branch keys are for decision callbacks. Anything else is a
contract violation: the parser reports a `callback`-domain error with code
`callback-contract-violation`.

`callback-continue` and `callback-pause` are allocation-free singletons
(`§13:810`) — compare them, do not rebuild them.

## 5. Pausing, and what a pause holds

**A pause happens after the callback's delivered event has been committed, and
resume continues after that event — it is never delivered twice** (`§13:814`).

For a span this has a specific consequence worth stating on its own: a pause
after the data fragment **retains only an internal `completion-pending`
continuation, never the input bytevector** (`§14:841`). A paused parser is not
holding your buffer.

A span-data callback accepts or rejects its **complete** supplied range
atomically (`§13:814`). There is no partial acceptance in v0.1. If you need finer
backpressure, feed smaller slices — you keep ownership of every unconsumed
suffix.

## 6. Fragments are not tokens

A logical span produces **zero or more data fragments followed by exactly one
completion event** (`§14:835`). How the fragments divide is decided by your feed
boundaries and your pauses, not by the grammar:

- ending a span emits `[mark,cursor)` if nonempty (`§14:831`);
- at a feed boundary an open span emits `[mark,end)` if nonempty, stays open, and
  begins its next fragment at the next feed's `start` (`§14:833`);
- **empty fragments are suppressed** (`§14:834`).

**Do not treat fragment boundaries as semantic boundaries** (`§14:836`). Feeding
the same bytes in a different number of calls gives you a different sequence of
fragments carrying the same concatenation, and the test suite asserts exactly
that: identical fragment traces between the two executors on the same schedule,
and *different* raw traces across schedules whose coalesced form is invariant.

On an error, the runtime does **not** flush a final partial fragment and does
**not** synthesize a completion; fragments already emitted at earlier feed
boundaries remain observable (`§14:839`).

A body's ordinary carrier is a counted consume (`§10.6:596`), which commits its
bytes in bulk; that changes nothing above — fragment boundaries are still your
feed boundaries, and when the count and the input run out at the same byte the
completion event arrives in that same feed (`§10.6:603`).

## 7. Escaping, and poisoning

Expected failures use the return value. **If a callback raises, or escapes
non-locally, the parser is poisoned** (`§12.6:749`): the condition propagates out
of `parser-feed!`, and the parser will refuse every further operation with the contract code
`poisoned-parser` — except `parser-reset!`, which is the one operation a poisoned
parser may run (`§12.2:698`).

A reset clears span state, the pause continuation, the stored error, and the stop,
finish and poison state (`§12.5:739`), and the parser is reusable from its entry
node.

## 8. Why the verifier is part of this contract

`§13:826` forbids an explicit pause node, or an event or decision callback
invocation, on any reachable path where a span is active — only the active span's
own data callback may pause before the span closes. **The verifier enforces
this** — diagnostic `span-active-at-pause`; its sibling `span-active-at-exit`
enforces the different rule at `§14:843` (no reachable path reaches a successful
stop or finish with a span active). The plan says in as many words that the `:826`
restriction is "what makes the no-retention contract possible without invoking
unrelated callbacks after a pause request".

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
| pause, escape and poisoning | `test/common/differential-callback-tests.sps` |
