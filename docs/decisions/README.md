# Architecture decisions

One file per decision, numbered in the order they were taken. A decision record
states what was decided, what it rules out, and what evidence it rests on.

Decisions that only restate the implementation plan do not need a record. These
exist for choices a reader of the plan would otherwise have to reverse-engineer
from the code.

## When a later decision reaches back

A record is evidence, so it is never rewritten to agree with a later decision —
AGENTS.md, *"Correct a stale instruction in place; annotate a stale record"*.
The correction goes in a **dated note**, appended at the foot of the file (or
inline beside the paragraph it corrects), and the text above it is left exactly
as decided.

That rule says where a correction goes. It does not, on its own, get the
correction *read*: a reader who arrives at a numbered item by citation — which
is how a record is usually reached — never scrolls to the foot. Decision 0010
item 4 read "the seam … extends by a `/v2` constructor" while the note replacing
that mechanism sat forty-seven lines below, as the fourth such note in the file,
with nothing at the top of the record saying so. The two rules below close that.

### 1. The top of the record says what reached back into it

**Whole record replaced** — a `Superseded:` line in the `Status:` block, naming
the replacement and what survives. See
[0002](./0002-shared-body-include-mechanism.md) and
[0003](./0003-cross-library-identity.md).

**Part of the record amended** — a blockquote immediately after the `Status:`
block, before `## Context`, with **one bullet per amendment, in the order the
notes appear**. See [0010](./0010-direct-executor-abi.md).

```markdown
> **Amendments** — later notes at the foot of this file reach back into the text
> above them. Nothing above a note is rewritten.
>
> - **2026-08-31 (Milestone 4)** — **amends item 4**:
>   [decision 0018](./0018-unversioned-generated-abi-constructor.md) replaces the
>   `/v2`-constructor extension mechanism.
```

Each bullet opens with the note's own heading prefix verbatim (`2026-08-31
(Milestone 4)`), so it locates the note by `rg` without a fragile anchor, and
says which verb applies:

| verb | meaning |
| --- | --- |
| **amends** | a sentence above the note is now false. Name the item or bullet. |
| **annotates** | the note adds or records something; nothing above it became false. |

A note whose whole content is short enough may live in the bullet itself, with
nothing at the foot to point at (see
[0004](./0004-content-fingerprint-and-provenance.md)'s 2026-08-18 entry). So
bullets may outnumber notes, never the reverse. The invariant, in the direction
that is checkable:

**Every dated note in a record is named by a bullet in that record's header
block.**

```bash
for f in docs/decisions/0*.md; do head=$(sed -n '/^> /p' "$f"); for d in $(rg -o '^## .*?(20[0-9]{2}-[0-9]{2}-[0-9]{2})' -r '$1' "$f" | sort -u); do case "$head" in *"$d"*) ;; *) echo "$f: dated note $d has no bullet in the header block";; esac; done; done
```

Silence is a pass. It fails on the two ways this drifts: appending a note and
forgetting the bullet, and deleting a bullet — both measured against this tree
on 2026-08-31, each reported by exactly that line.

### 2. Text a note makes false carries a marker at the site

An **amends** bullet also puts a one-line blockquote directly under the item or
bullet it names, at that item's indentation, followed by a blank line:

```markdown
4. The runtime↔generated seam … extends by a `/v2` constructor rather than an
   arity break.

   > **Amended 2026-08-31 (Milestone 4)** by
   > [decision 0018](./0018-unversioned-generated-abi-constructor.md) — the
   > `/v2`-constructor mechanism named here is replaced. See the dated note
   > below; the sentence above is left as decided.
```

An **annotates** bullet may use one where the item would otherwise read as
current, and does not need one otherwise.

### The line a pointer must not cross

A pointer **routes; it never restates**. It names what is amended, who amended
it, and where the note is — and stops. A pointer that summarises the correction
starts doing the note's job at the top of the file, and a reader who stops there
gets the later decision's conclusion without the evidence and the measurement
the note carries. That is the rewrite AGENTS.md forbids, arriving through the
back door.

The header block and the site marker are **additions**. They change no word of
what was decided, which is why they are not the rewrite: the record still reads
as what was believed, and against which tree, on the day it was written.

### Two mechanics that are easy to get wrong

- **A blockquote inside a list item needs a blank line after it.** Without one,
  the next item (`2.`, `3.`, …) is absorbed into the blockquote as lazy
  continuation, because an ordered list can only interrupt a paragraph when it
  starts at `1`.
- **Adding a header shifts every line in the file.** Before committing, `rg` the
  tree for `NNNN…\.md:[0-9]` and `NNNN:[0-9]` citations into the record and
  repair them — preferably by replacing the line number with the quoted
  sentence, which cannot go stale again. Nothing else catches this: a link
  checker sees a valid file, and a grep sees a valid number. The sweep that
  added these headers moved one such citation —
  `milestone-0-close-out-implementation-plan.md`'s pointer at
  `0001-toolchain-discovery.md:86`, repaired to the quoted sentence.
