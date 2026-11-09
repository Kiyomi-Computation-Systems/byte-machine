# 0059: A state that loops back to itself reads its run in a loop beside it

Date: 2026-11-09
Status: accepted; not yet released
Milestone: 15, Gate 0 ([milestone-15-design.md](../.plans/milestone-15-design.md))
Builds on: [0048](0048-what-material-improvement-means.md) (the method this is measured by), [0049](0049-a-state-is-a-procedure-not-a-case-arm.md) (a state is a procedure), [0050](0050-a-byte-class-is-a-range.md) (a class is a range), [0055](0055-the-allocation-audit-is-a-census-of-runtime-ops.md) and [0058](0058-the-allocation-audit-is-a-census-of-arm-kinds.md) (the census the loop joins)
Annotates: [0050](0050-a-byte-class-is-a-range.md) (its limits witness, rebuilt again), [0058](0058-the-allocation-audit-is-a-census-of-arm-kinds.md) (what the arm census counts)

## Context

Decided against `main` at `3c56875` (v0.8.0), on `ta6le` (amd64 Linux), Chez
10.4.1.

**The ask.** A consumer brief,
`jsonparse/.plans/2026-11-09-upstream-run-loop-brief.md`, asks that a
`dispatch` state whose transitions advance back to the state itself compile
those transitions into a tight loop, with nothing else changing: no IR,
fingerprint, ABI, runtime, interpreter or verifier change, and no change in
anything a caller can see. Its owner's decision, recorded in the brief, is to
build it as an emitted-code change that keeps the generated-runtime ABI at 9.
The brief prototyped the lowering by hand on jsonparse's generated parser
(P1j) and measured three alternatives beside it (P1, P1c/P1d, P1g).

**What a run costs today.** Since 0049 and 0050 a state is a procedure and a
class is a run of range tests. A state that advances to itself still pays, per
byte of a run, a full tail call into itself: the `(>= pos end)` test, the read,
its clauses in byte order (an HTTP header name's lowercase letter matches the
seventh clause, after eleven comparisons), and generic `+` on both `pos` and
`off`.

**Which states this reaches.** In byte-machine's HTTP fixture, 14 of its 125
dispatch states (217 states in all) advance to themselves on a transition,
none on a fallback (measured: a scratch walk of the normalized IR). The
classes are the token charset (nine runs: method, header name, two
chunk-extension loops, the trailer name), a request target (one run, 33-126),
header and trailer values (three runs) and the optional whitespace states (two
runs, 9 and 32). Measured on their IR the same way, jsonparse has 14, and
chez-httparse's message parser 24 looping on a transition and 3 on a fallback,
27 in all, with 5 more in its url parser.

## Decision

1. **A dispatch state qualifies when its class holds a byte.** Its CLASS is
   every byte a transition names and sends back by advance, and, when the
   fallback advances back, every byte no transition names. A reexecute back
   to the state is a zero-progress cycle the verifier refuses, so only an
   advance counts. Every qualifying state gets a loop. An edge back to the
   state is not enough: a fallback that advances back on a dispatch whose
   cases name all 256 bytes is never taken, so its class is empty. The
   verifier accepts that machine, and a review found the first form of this
   rule, which qualified it on the edge, made `render-machine` raise on it
   where 0.8.0 renders it.

2. **The loop starts after a byte in the class.** Each clause of the state's
   arm that advanced to the state, `(%sN (+ pos 1) N (+ off 1) (quote
   boundary))`, enters `(%rN (fx+ pos 1) pos off)` instead, and so does a
   fallback that advances to the state. A byte outside the class reaches the
   arm exactly as before and pays nothing new.

3. **The loop, `(define (%rN n pos off) ...)`, rendered beside its state.**
   `n` is the cursor; `pos` and `off` are where the run began. While
   `(fx<? n end)` it reads a byte and tests it:
   - **no test** when the class is every byte;
   - **one comparison** when it is one byte, **two** when it is one run;
   - **a 256-entry bytevector** otherwise, `%c<k>` at library level beside
     `errs`: one per DISTINCT class, numbered in the order states first need
     them, shared by every state with that class.

   A byte in the class steps on with `(fx+ n 1)`. A byte outside it binds
   `pos` to `n` and `off` to `(+ off (fx- n pos))` and is dispatched over the
   state's own clauses but those that loop back, then the state's fallback,
   unless the fallback is the loop. At the end of the feed the loop calls the
   state itself, `(%sN n N (+ off (fx- n pos)) (quote boundary))`, whose code
   handles need-input and `finish?` as before. `off` keeps generic `+`, since a
   stream offset may outgrow a fixnum; positions within a feed index `bv`, so
   they are fixnums.

4. **No new reserved name.** The loop's parameters are spelled with names
   `reserved-member-3` already holds. The brief's `p`, `pos0` and `off0` would
   have had to join it, and `render-machine` would then refuse three output
   bindings 0.8.0 accepts. `%r<id>` and `%c<k>` carry the unforgeable `%`
   prefix, as `%s<id>` and `%dispatch` do (0049 item 3).

5. **Only the emitted text changes.** No source or normalized IR, no
   fingerprint, no runtime, interpreter or verifier code. The ABI literal
   stays 9 and the emitted library stays `(rnrs)` and `(byte-machine
   runtime)` only, with no unsafe operation. A parser generated by 0.8.0
   loads and runs on this runtime unchanged, without the loop.

6. **The allocation audit counts loops.** A loop is inline code on the
   per-byte path that no state arm's census covers: entering a state is not
   entering its loop. So the counting twin also counts `%rN` entries; a loop's
   arm is `(run-loop . test)`, its test `every`, `byte`, `range` or `table`,
   read from the loop's form, each its own inline code; the tests are derived
   as the labels of `render-run-loop`'s `case` on `kind`, as 0058 derives
   state kinds. The census then asks, in each audited machine, for each loop
   arm it renders to be entered; across machines, for each test the emitter
   can render to be entered; and for each audited machine, that its
   instrumented loops are exactly the states its IR says loop. One witness
   measures what 40000 more bytes of a run cost, per test, as one value; one
   compares 1000 feeds that each end inside a run with 1000 that read nothing,
   for the way out at the end of a feed, which runs once per feed and so is
   invisible to any slope over a run's length; and the op census also counts
   calls against the bytes a non-looping arm reads, since a state that does
   not loop still reads every byte through its arm.

## What it measured

`bench/runner/benchmark.sps`, `BYTE_MACHINE_BENCH_EXECUTORS=generated`, seven
rounds of 80000 iterations, run through the source launcher with
`taskset -c 7` (one performance core of a hybrid CPU), `ta6le`, Chez 10.4.1,
nothing else running. Four trees took turns, five turns each: A, `main` (a
`git worktree` at `3c56875`); B, this record; C, B with a class of several
runs tested by `or`ed range tests and no table (the brief's P1d); D, B with a
byte outside the class leaving through the state, which reads and dispatches
it again (P1g). Every figure below was computed by a script from the twenty
artefacts. "Worst span" is the largest (max − min) / median over a run's
seven rounds, worst of five turns; "turn spread" is the range of the five
turns' medians over their median. Changes are of the median of the five turn
medians; "per turn" is each turn's ratio, smallest to largest.

### The dispersion on this cell

0048 item 4 says its thresholds belong to `tarm64osx` and are re-derived per
cell. On `ta6le`, at this iteration count, A's dispersion is:

| workload | median (ms) | worst span | turn spread |
|---|--:|--:|--:|
| `long-method-target-header-spans` | 307 | 6.0% | 3.6% |
| `long-exact-sequence-matching` | 282 | 4.3% | 1.1% |
| `many-small-headers` | 243 | 4.5% | 1.2% |
| `dense-byte-dispatch` | 242 | 4.1% | 1.7% |
| `byte-at-a-time-fragmentation` | 158 | 3.8% | 2.5% |
| `pipelined-requests` | 87 | 2.3% | 1.1% |
| `chunked-bodies` | 61 | 11.5% | 1.6% |
| `fixed-length-bodies` | 35 | 17.1% | 2.9% |
| `sparse-byte-dispatch` | 35 | 20.0% | 5.7% |
| `short-normal-requests` | 31 | 6.7% | 3.2% |
| `late-error` | 25 | 8.0% | 0.0% |
| `early-error` | 13 | 7.7% | 0.0% |

At and above 87 ms every span is at most 6.0%; below, they reach 20%. The
noise below is not the clock's 1 ms, as on `tarm64osx`: the wide spans are one
round in seven running 5-7 ms slow, an absolute cost that is a larger fraction
of a smaller median. By 0048's method, then, on this cell: a workload is
admissible at a median of 80 ms or more (six; `many-small-headers` and
`dense-byte-dispatch` are one input, since the runner defines one as the
other), material improvement is about five times the worst admissible span,
30%, and significant regression about twice it, 12%.

### B against A

| workload | A (ms) | B (ms) | change | per turn |
|---|--:|--:|--:|--:|
| `long-method-target-header-spans` | 307 | 286 | -6.8% | -12.3% to +0.0% |
| `long-exact-sequence-matching` | 282 | 286 | +1.4% | -1.1% to +4.3% |
| `many-small-headers` | 243 | 203 | -16.5% | -17.7% to -16.0% |
| `dense-byte-dispatch` | 242 | 203 | -16.1% | -16.7% to -15.8% |
| `byte-at-a-time-fragmentation` | 158 | 162 | +2.5% | +1.3% to +3.2% |
| `pipelined-requests` | 87 | 87 | +0.0% | -3.4% to +2.3% |
| `chunked-bodies` | 61 | 61 | +0.0% | -1.7% to +4.9% |
| `fixed-length-bodies` | 35 | 35 | +0.0% | -2.9% to +5.9% |
| `sparse-byte-dispatch` | 35 | 35 | +0.0% | +0.0% to +6.1% |
| `short-normal-requests` | 31 | 30 | -3.2% | -6.5% to +0.0% |
| `late-error` | 25 | 24 | -4.0% | -4.0% to +0.0% |
| `early-error` | 13 | 13 | +0.0% | -7.7% to +0.0% |

Every change here is in time taken. Header names and values take 16.5% less
time. The 2000-byte target's -6.8% is not established: B's five turns were
271, 283, 286, 307 and 293 ms, a 12.6% spread with one turn at +0.0% against
A, where this cell's worst span is 6.0%. `byte-at-a-time-fragmentation` takes
2.5% more time in every turn, which is what the loop adds there: fed one byte
per call, each byte that enters a loop finds the feed's end at once and calls
its state back. `long-exact-sequence-matching` moves +1.4%; A's turns spread
1.1% there and B's 5.6%, drifting up across the turns (278 to 294 ms).
`pipelined-requests` does not move.

### The alternatives the brief measured, against B

C, range tests for a class of several runs:

| workload | B (ms) | C (ms) | change | per turn |
|---|--:|--:|--:|--:|
| `many-small-headers` | 203 | 221 | +8.9% | +7.5% to +8.9% |
| `dense-byte-dispatch` | 203 | 221 | +8.9% | +6.4% to +9.9% |
| `long-method-target-header-spans` | 286 | 294 | +2.8% | -4.2% to +3.1% |
| `long-exact-sequence-matching` | 286 | 288 | +0.7% | -2.4% to +1.1% |

D, leaving through the state:

| workload | B (ms) | D (ms) | change | per turn |
|---|--:|--:|--:|--:|
| `many-small-headers` | 203 | 222 | +9.4% | +8.8% to +10.4% |
| `dense-byte-dispatch` | 203 | 222 | +9.4% | +5.9% to +9.9% |
| `long-method-target-header-spans` | 286 | 308 | +7.7% | +0.3% to +9.9% |
| `long-exact-sequence-matching` | 286 | 306 | +7.0% | +3.1% to +9.0% |
| `pipelined-requests` | 87 | 92 | +5.7% | +1.1% to +9.5% |

The admissible workloads not shown move 0.0% against B in C and +1.9% in D;
the inadmissible ones move between -7.7% and +4.2% in C and up to +8.3% in D.
Byte-machine's workloads can tell both alternatives apart from B: on header
names and values, neither one's five turn medians overlap B's. A table beats
range tests for a class of several runs, the reverse of 0050's finding for one
dispatch (a membership bytevector at 1.75 ns against two comparisons at 1.25
ns): the loop tests every byte, and the token class is nine runs. Dispatching
the byte that ends a run in the loop beats leaving through the state, which
reads and tests it twice. That cost is paid once per run, so it shows on every
workload made of short runs: header names and values (+9.4%), the sequence
workload (+7.0%), pipelined requests (+5.7%). The brief's third alternative,
testing the class on entry to the state (P1), was not built here; its cost is
in the consumer's text: 8-9% more time on a file that is 87% multibyte and
re-enters the state every few bytes, which byte-machine's workloads, all
ASCII, cannot show.

The consumer's figures for the hand-made prototype, P1j against its `main`,
two turns each on the same host (the brief's table, % of time per byte):
`gsoc-2018` -41% and -41%, `twitter` -7% and -12%, `poet` -1% and -3%, and
the other five files within its 4% noise.

### Downstream, with this emitter

Recorded from the coordinator's measurements, not taken here; the file
facts and the timing figures were re-read or recomputed from the artefacts.
The four parsers below were generated with this branch's emitter before the
review's fix to the qualifying rule (decision 1); a reviewer regenerated all
four with the fixed emitter and got byte-identical files, since none of them
has a state whose looping fallback no byte reaches.

- **jsonparse**, its grammar regenerated with this branch: 102,006 bytes
  (from 92,635, +10.1%), 14 loops and two tables; its fingerprint
  `8628246217050196640` and ABI 9 unchanged. Its conformance, fuzz, parser,
  machine, property, allocation, tree, easy and sequence suites pass. Timed
  against its `main`, three turns each, pinned to CPU 7, `events` lane, % of
  time per byte against the mean of `main`'s turns (artefacts
  `jsonparse/build/probe14/r6/`, computed by
  `jsonparse/build/probe14/analyze.py`): `gsoc-2018` -41% three times,
  `twitter` -11%, -7%, -8%, `poet` -6%, -4%, -5%, `escaped-string` -3% three
  times, `citm` 0%, +4%, +4%, `canada` -8%, +1%, +1%, `ints-40k` -1%, +3%,
  +2%, `records-2k` 0%, -1%, -5%. `main`'s own three turns moved by up to
  5.8% (`ints-40k`), as (max − min) / min of their medians.
- **chez-httparse and uriparse**, regenerated in scratch clones with this
  branch's `src/`: chez-httparse's `make test` passes 101 of 101 and
  uriparse's 91 of 91, the counts they pass with 0.8.0, whose regeneration
  reproduced the checked-in files byte for byte. Every fingerprint and ABI
  line is unchanged.
- **chez-httparse's throughput**, its lane
  `httparse.benchmark.throughput-reuse.chez.aot` run from each clone's dev
  build, one built from 0.8.0's emitter and one from this branch's, pinned
  with `taskset -c 7`, ten turns, the old then the new each turn
  (`jsonparse/build/downstream/tp.sh`, raw lines in `tp.out`). Medians in
  msg/s, with the range over the ten turns, and the change in time:

  | case | 0.8.0 | this | time |
  |:--|--:|--:|--:|
  | `request/whole` (308 B) | 497,133 (465,454–501,960) | 501,960 (501,960–512,000) | -1.0% |
  | `response/whole` (1166 B) | 875,277 (867,796–882,758) | 898,245 (882,758–914,285) | -2.6% |
  | `request/1-byte-feeds` | 51,612 (47,058–53,333) | 51,612 (47,058–53,333) | 0% |

  These are small, and at the lane's resolution: it times each case once
  over about 50-60 ms with a whole-millisecond clock, so it cannot resolve
  much under 2%. Its messages are short, and their runs shorter. uriparse's
  throughput was not measured.

  | parser | 0.8.0 (bytes) | this (bytes) | loops | tables |
  |:--|--:|--:|--:|--:|
  | `httparse-message.sls` | 227,108 | 245,562 | 27 | 12 |
  | `httparse-url.sls` | 36,712 | 42,268 | 5 | 4 |
  | `uri-scanner.sls` | 28,766 | 34,098 | 7 | 4 |

### Against 0048's rules

- **Rule 2, material improvement, is not met.** One input improves by 16%;
  no workload by 20% (0048's figure) or by this cell's 30%. As with 0053, this
  is recorded as an exception and not resolved by widening the rule. The
  owner, told on 2026-11-09 that rule 2 was not met, admitted the change on
  the consumer's evidence: `§23.3`'s first criterion reads "a repeatable
  material improvement on representative workloads or remedying a
  demonstrated performance problem", and the consumer's long strings
  (`gsoc-2018`, -41% in both turns) are that problem.
  Byte-machine's own benchmark has no input like them; its longest run is a
  2000-byte target, already a single range clause.
- **Rule 3, significant regression: none was found.** The worst admissible
  change is +2.5%, below 0048's 10% and this cell's 12%.
- **`§23.3` criterion 2 (both execution lanes) is not addressed.** The runner
  loads the libraries from source and recorded mode `unknown`; no run used
  the AOT lane.
- **`§23.3` criterion 3 (another platform cell) is not discharged.** One cell,
  `ta6le`, as for 0049 and 0050 on `tarm64osx`.

### Size, against `§28`

The HTTP grammar's emitted source goes from 129,438 to 135,473 bytes
(+4.7%), its compiled object from 72,615 (72,616 in some of `main`'s runs) to
74,307 (+2.3%), from the runner's artefacts. jsonparse's grammar, regenerated
with this emitter, grows 10.1% (92,635 to 102,006), and chez-httparse's and
uriparse's parsers between 8.1% and 18.5% (the table above).
The limits witness, rebuilt below as the loop's worst case, renders 41,518
bytes where the same machine rendered 21,663 with `main`'s emitter.

## Consequences

- **One golden moves, and no fingerprint does.** `generated-http.golden.sls`
  is re-baselined: 195 lines in, 64 out, its 14 loops and three tables. Its
  constructor line, `(byte-machine-make-compiled-machine 9
  12865529106868080404 ...`, is unchanged, as is every other golden's
  (compared line for line with `main`). The new loop machine fingerprints
  `10385804887554373253` under both `main`'s normalizer and this one. This is
  0044 item 4's backward oracle: only the emitted text moved.
- **A new fixture, golden and two lane pairs.** `loop-machine.sls` has one of
  every shape the lowering makes: a class of one byte, of one run, of several
  runs, two states sharing a table, a fallback that loops with a named byte
  that loops too, a class of every byte, an exit through each kind of clause
  (an advance to another state, a reexecute, an error state, the fallback)
  and three spans, each open across one loop. A second machine names all 256
  bytes in a state whose looping fallback is never taken.
  `byte-machine.differential.loop` and
  `byte-machine.determinism.loop` run it; the second's golden is
  `generated-loop.golden.sls`.
- **The property generator now runs loops.** Measured at the committed seed
  before this change: 3 of the 41 accepted machines rendered a loop, and with
  every loop's entry made to raise, the property lane stayed green, so no
  trial entered one. The coverage segment's last stage, `covx9`, now loops on
  every byte but 0-15 and 128 (a table, on its fallback). Measured after: an
  `off` one too many when a loop leaves through a clause makes 12 of the 41
  machines disagree; at the end of a feed, 33.
- **The census found a loop no witness ran.** 0058's field machine's `loop`
  state advances back to itself on its fallback, so it renders a table loop,
  and its rows feed only named bytes. The lane now feeds it 44 and 40044
  unnamed bytes.
- **The limits witness was measuring the old worst case.** 0050 rebuilt it as
  256 bytes alternating between two destinations. The loop's worst case is a
  state that loops on a few bytes among 256 singleton runs, so its exit
  dispatch renders the others again: bytes 0 and 2 of the witness's 256 now
  loop, which renders 256 clauses in the arm, 254 in the exit and a 256-entry
  table, and the lane checks the loop and the table are there.
- **A shipped mutation lost its witness, and has a new one.** "The dispatch
  arm enters a runtime op for every byte it reads" went uncaught (measured:
  exit 0): a header value's bytes after the first now go through the loop, so
  the header-value slope no longer moves the arm's count. A twin of it sits on
  the loop's read, with that slope as witness. The arm still reads every byte
  of a state that does not loop, so the shipped mutation stays on the arm,
  witnessed by the field machine's named bytes, each read by `loop`'s arm.

## What this does not cover

- **chez-httparse's throughput is measured only at its lane's resolution**
  (above), and uriparse's not at all. A run of each with more iterations per
  case would say whether their short runs gain anything.
- **The table against ranges for one run.** Byte-machine's one-run loop (the
  target) was not measured with a table; the consumer measured its digits'
  and found the table no better.
- **Callbacks inlined into the loop** are not this record: they reach into
  the parser's slots and need ABI 10 (the brief, "Not asked").

## Witnesses

- `byte-machine.differential.loop` (53 cases): the emitted loops read back
  as data (one per qualifying state, derived from the IR; each tests the
  class the fixture declares by hand; one table per distinct class, shared);
  every two-way feed split of eight inputs, each feed behind its own padding
  and in front of bytes of every class; each input a byte at a time; two
  parsers interleaved; `finish?` inside each of seven loops; the bytes either
  side of every class edge, read by the state's arm and by its loop; each
  input's whole trace asserted by value in both lanes; the first callback
  after a loop exit pausing, resumed, and failing; one cut of the input at
  every byte with that callback pausing, which pauses after the loop's exit
  for a cut outside the run and at the end-of-feed flush for a cut inside it,
  each asserted where it lands; each loop's exit on a byte its clauses do not
  name, with the generated run guarded so a raise is a value compared; and
  the machine whose looping fallback no byte reaches, rendered, with no loop
  for that state, against the interpreter on every byte.
- `byte-machine.determinism.loop`: the golden, the loops' shapes read back as
  one value, and four walks through long runs.
- `byte-machine.unit.allocation-audit`: loop entries counted; three rows
  (each looping state's loop counted, each loop test entered, and its
  recogniser's control); one witness of four slopes, 40044 newlines through a
  one-byte loop (byte), a 40044-byte request target (range), 40044 unnamed
  bytes through the field machine's loop (table), and the same small machine's
  loop on every byte (every); a feed-count witness for the leave at the end of
  a feed; and the op census's count over the bytes a non-looping arm reads,
  with both feeds read back to their end first.
- `byte-machine.unit.member3-drift` and `byte-machine.unit.compile`: the
  emitter-private names now have four shapes, and each fixture renders a loop
  and a table.
- `byte-machine.unit.compile-limits`: the loop's worst case, above.
- The mutation lane goes from 79 passes / 711 mutations to 81 / 752. Pass 80
  (the loop lane) has 21 mutations and Pass 81 (the golden lane) 5; Pass 77
  gains 13, Pass 39 one (proving the drawn machines reach a loop's exit) and
  the member-3 pass one. Three are re-anchored: the two truncations of a
  branching state's clauses (Pass 48), onto the arm's new call, and the
  shipped per-byte op, onto the loop's read; one of Pass 77's new mutations
  puts it back on the arm's read, with its own witness. Two of Pass 77's
  shipped pins gained
  their measured `got`: an allocating loop also makes the bytes before an
  error cost more, so both error-record pins matched the new loop-allocation
  mutants. Every pin in Passes 39, 48, 77, 80, 81 and the member-3 pass was
  judged against every other mutant of its pass, in both directions, through
  the real launcher on a staged copy: each resolves exactly once in its own
  mutant's output and in no other's. Ten mutants are equivalent in outcome,
  each pinned by a census of the emitted shape: five by the golden lane's
  shape value (Pass 81's header names them); a class's table duplicated and a
  one-run class tested through a table, by the loop lane's census of loops and
  tables; and a loop no clause enters, or no fallback, and a one-byte class
  tested by two comparisons, by the allocation lane's census rows. A fallback
  that loops adding no byte to the class is not among them: comment then has
  no loop, which is equivalent, but text keeps a loop of its one named byte,
  whose exit has no `else`, so its unnamed bytes fall off the exit's `cond`
  and the runtime raises. The loop lane's guarded exit case compares that, and
  is its pin; the census of loops sees the comment half.
