# Milestone 2 Slice ① — Incremental Execution Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove the parser executes correctly across arbitrary, incrementally-fed slices of a multi-byte machine — every split point, empty feeds, nonzero-offset slices, all 256 values at each position — matching between the reference interpreter and generated code, and extend the §9.6 example to a nonzero-offset slice.

**Architecture:** This slice adds **no `src/` code.** The 2026-08-28 design audit (`.superpowers/sdd/m2-design-audit-report.md`) confirmed `parser-feed!` already implements §11 for *fresh and resume* feeds (only the sticky-*repeat* case is broken, and that is Slice ②'s to fix — so this slice never re-feeds a terminal parser). The work is a new **four-byte accept-sequence** proving machine (the first machine with multiple *dispatch* nodes to go through both executors — new lowering coverage the one-byte and single-dispatch property machines never exercised), a differential + incremental test program over it, and a one-case extension to the §9.6 example. If any test goes **red**, that is a real engine/emitter bug: STOP and use superpowers:systematic-debugging — do not weaken the assertion to make it pass.

**Tech Stack:** Chez Scheme 10.4.1 (R6RS `.sls` libraries, `.sps` programs), CMake ≥3.26 + presets, the in-tree dependency-free test harness `(byte-machine test harness)`.

## Global Constraints

- Chez floor **10.4.1**, threaded; CMake floor **3.26**. No new dependencies (no SRFI-64, no package manager).
- Libraries are inline R6RS `.sls`, programs `.sps`; **no Scheme file may `include` another** (decision 0006). Within one lane's `SOURCES` manifest, basenames must be unique.
- The `no-scheme` preset must stay green at **8/8** (this slice registers only `chez` lanes, no `cmake.direct` lane, so it is unaffected).
- Every new lane is registered through `byte_machine_add_scheme_lane` in `test/CMakeLists.txt` — never by editing a build artifact. `BYTE_MACHINE_TEST_TMPDIR` is provided to every lane automatically (`cmake/ByteMachineTesting.cmake:250`); do not set it.
- A lane's labels are derived from its dotted `NAME` (layer = the segment after `byte-machine.`). Use layer **`differential`** so the lane runs under the `pr` preset (its filter is `^(harness|unit|verify|differential|property|determinism|portability|example)$`).
- This slice changes no `src/` file, so it adds **no mutation** and no new exit path (mutation discipline applies to decisions/engine changes; there are none here). It DOES add lanes, so the `release` lane count rises — **re-measure** `release`/`pr` totals before writing any count into a record; the Scheme mutation total (37/104) and `no-scheme` (8/8) are unchanged.
- This slice must **never re-feed a parser that has reached a terminal** (`stopped`/`error`) — that is the §12.2 sticky-repeat path Slice ② fixes; relying on it here would bake in the current bug.
- Conventional Commits. Run `make test` before every commit; fix failures before proceeding.

---

## Task 1: The four-byte proving machine + whole-input & all-256-per-position differential

**Files:**
- Create: `test/support/harness/byte-machine/test/sequence-machine.sls`
- Create: `test/common/differential-sequence-tests.sps`
- Modify: `test/CMakeLists.txt` (register two lanes after the example lanes, ~line 903)

**Interfaces:**
- Produces: `(byte-machine test sequence-machine)` exporting `make-sequence-machine` (a verified-valid 4-byte accept machine) and `sequence-bytes` (the list `(1 2 3 4)`). Tasks 2–3 extend `differential-sequence-tests.sps`; they consume `make-sequence-machine`, `sequence-bytes`, and the program's `cm-ref`/`cm-gen`/`run-slices`/`u8`/`drive` helpers defined here.

- [ ] **Step 1: Create the proving-machine fixture**

Create `test/support/harness/byte-machine/test/sequence-machine.sls`:

```scheme
;;; A four-byte accept-sequence proving machine for Milestone 2 Slice ①
;;; (incremental execution): s0 reads 1 -> s1 reads 2 -> s2 reads 3 -> s3 reads
;;; 4 -> stop; every fallback REEXECUTES into the reject error, so a wrong byte's
;;; `next` points AT the offending byte (parent §11.5). Built only through
;;; (byte-machine graph). Four dispatch nodes give three interior split points,
;;; so §22.5 split-point pairs and multi-split schedules are satisfiable, and it
;;; is the first machine with MULTIPLE dispatch nodes to go through both
;;; executors (new lowering coverage vs the one-byte and single-dispatch property
;;; machines).
(library (byte-machine test sequence-machine)
  (export make-sequence-machine sequence-bytes)
  (import (rnrs) (byte-machine graph))
  (define sequence-bytes '(1 2 3 4))
  (define (make-sequence-machine)
    (let ((eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
          (rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f)))
      (make-machine 'seq 's0 '() '() '() (list eof-decl rej-decl)
        (list (make-byte-dispatch-node 's0
                (list (make-byte-case (make-exact-byte-matcher 1) (make-edge 's1 'advance) #f))
                (make-edge 'reject 'reexecute) #f #f)
              (make-byte-dispatch-node 's1
                (list (make-byte-case (make-exact-byte-matcher 2) (make-edge 's2 'advance) #f))
                (make-edge 'reject 'reexecute) #f #f)
              (make-byte-dispatch-node 's2
                (list (make-byte-case (make-exact-byte-matcher 3) (make-edge 's3 'advance) #f))
                (make-edge 'reject 'reexecute) #f #f)
              (make-byte-dispatch-node 's3
                (list (make-byte-case (make-exact-byte-matcher 4) (make-edge 'stop 'advance) #f))
                (make-edge 'reject 'reexecute) #f #f)
              (make-stop-node 'stop #f)
              (make-error-node 'reject 'rejected #f))
        'default-eof #f))))
```

- [ ] **Step 2: Create the differential program (whole-input + all-256-per-position)**

Create `test/common/differential-sequence-tests.sps`. This mirrors `differential-one-byte-tests.sps` (emit → load → compare) but over the multi-dispatch-node machine:

```scheme
;;; interpreter ≡ generated over the four-byte accept-sequence machine (parent
;;; §22.4, §22.7). Whole-input accept/reject, and all 256 byte values at each of
;;; the four sequence positions. Tasks 2 and 3 extend this program with
;;; fragmentation schedules and nonzero-offset slices. The generated library is
;;; emitted at run time, loaded, and compared field-for-field. This slice never
;;; re-feeds a terminal parser (the §12.2 sticky-repeat path is Milestone 2
;;; Slice ②).
(import (rnrs) (rnrs eval)
        (only (chezscheme) load)
        (byte-machine test harness)
        (byte-machine test sequence-machine)
        (byte-machine graph)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime)
        (byte-machine compile))

(harness-begin "differential.sequence")

(define tmpdir
  (let ((d (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")))
    (if (and d (not (string=? d ""))) d
        (assertion-violation 'differential-sequence "BYTE_MACHINE_TEST_TMPDIR is unset" d))))
(define genfile (string-append tmpdir "/generated-sequence.sls"))

(define seq (make-sequence-machine))
(define cm-ref (make-interpreted-machine (verify-machine seq)))
(call-with-port (open-file-output-port genfile (file-options no-fail))
  (lambda (p) (emit-machine (compile-machine seq '()) 'seq-parser p)))
(load genfile)
(define cm-gen (eval 'seq-parser (environment '(generated seq))))

;; A one-byte bytevector holding b.
(define (u8 b) (make-bytevector 1 b))
;; A bytevector literal from bytes. NOTE: u8-list->bytevector is a STANDARD
;; (rnrs) procedure — do not redefine it (that is a "multiple definitions" error).
(define (u8v . bs) (u8-list->bytevector bs))
;; The first n elements of a list.
(define (list-head-n lst n)
  (if (= n 0) '() (cons (car lst) (list-head-n (cdr lst) (- n 1)))))

;; Feed a list of (bv start end) slices through ONE fresh parser; return the
;; final parser-result as the field list (status next consumed stream-offset
;; error). Schedules here never continue past a terminal.
(define (run-slices cm slices)
  (let ((p (make-parser cm '() #f)))
    (let loop ((ss slices) (last #f))
      (if (null? ss) last
          (let ((r (parser-feed! p (car (car ss)) (cadr (car ss)) (caddr (car ss)))))
            (loop (cdr ss)
                  (list (parser-result-status r) (parser-result-next r)
                        (parser-result-consumed r) (parser-result-stream-offset r)
                        (parser-result-error r))))))))

;; Feed each byte of `prefix` (as its own [0,1) slice) then the test byte `b`.
(define (drive cm prefix b)
  (run-slices cm (append (map (lambda (x) (list (u8 x) 0 1)) prefix)
                         (list (list (u8 b) 0 1)))))

(harness-group "whole-input accept and per-position reject agree in both lanes"
  (lambda ()
    (harness-case "the full sequence 1 2 3 4 stops after four bytes in both"
      (lambda ()
        (check-equal "interpreter" (run-slices cm-ref (list (list (u8v 1 2 3 4) 0 4)))
                     '(stopped 4 4 4 #f))
        (check-equal "generated"   (run-slices cm-gen (list (list (u8v 1 2 3 4) 0 4)))
                     '(stopped 4 4 4 #f))))
    (harness-case "a wrong byte at each position errors at that between-byte offset in both"
      (lambda ()
        (for-each
         (lambda (k)                       ; k = number of correct bytes already fed
           (let ((prefix (list-head-n sequence-bytes k))
                 (expect (list 'error 0 0 k 'unexpected-byte)))
             (check-equal (string-append "interpreter pos " (number->string k))
                          (drive cm-ref prefix 200) expect)
             (check-equal (string-append "generated pos " (number->string k))
                          (drive cm-gen prefix 200) expect)))
         '(0 1 2 3))))))

(harness-group "interpreter and generated agree on all 256 bytes at every position"
  (lambda ()
    (harness-case "256 x 4 positions match"
      (lambda ()
        (let ((bad 'none))
          (for-each
           (lambda (k)
             (let ((prefix (list-head-n sequence-bytes k)))
               (let loop ((b 0))
                 (when (< b 256)
                   (unless (equal? (drive cm-ref prefix b) (drive cm-gen prefix b))
                     (when (eq? bad 'none) (set! bad (cons k b))))
                   (loop (+ b 1))))))
           '(0 1 2 3))
          (check-equal "no (position . byte) disagreed" bad 'none))))))

(harness-finish)
```

(The chosen wrong byte `200` is not in `{1,2,3,4}`, so it takes the reexecute fallback at every position: `next = 0`, `consumed = 0`, `stream-offset = k`, error code `unexpected-byte`.)

- [ ] **Step 3: Register the two lanes**

In `test/CMakeLists.txt`, immediately after the `byte-machine.example.one-byte.chez.aot` lane (the block ending at ~line 903), add:

```cmake
# --- Milestone 2 Slice 1: incremental execution over a multi-byte sequence ----
byte_machine_add_scheme_lane(
  NAME byte-machine.differential.sequence.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-sequence-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/prng.sls"
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/sequence-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/differential-sequence-tests.sps"
  TIMEOUT 180)

byte_machine_add_scheme_lane(
  NAME byte-machine.differential.sequence.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-sequence-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/prng.sls"
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/sequence-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/differential-sequence-tests.sps"
  TIMEOUT 180)
```

(`prng.sls` is listed now — Task 2 uses it for the multi-split schedule; listing it in Task 1 keeps the two-lane block final. `BYTE_MACHINE_CORE_EMIT` is the shared emitter manifest defined at ~line 860.)

- [ ] **Step 4: Configure, build, and run the new lanes**

Run:
```bash
make build
ctest --preset pr -R 'byte-machine\.differential\.sequence' --output-on-failure
```
Expected: both `...chez.source` and `...chez.aot` **PASS**. If a byte disagrees (the `bad` check fails printing a `(position . byte)` pair) or the AOT lane fails to load, that is a real multi-dispatch-node lowering bug — STOP and use superpowers:systematic-debugging; do not edit the assertion.

- [ ] **Step 5: Confirm the whole suite is green, then commit**

Run:
```bash
make test
```
Expected: PASS (the two new lanes are included by the `pr` filter's `differential` label; the M1 lanes are unchanged).

```bash
git add test/support/harness/byte-machine/test/sequence-machine.sls \
        test/common/differential-sequence-tests.sps test/CMakeLists.txt
git commit -m "test: M2 slice 1 — four-byte sequence machine, whole-input + all-256-per-position differential"
```

---

## Task 2: Fragmentation — every split, split-point pairs, a multi-split schedule, and empty feeds

**Files:**
- Modify: `test/common/differential-sequence-tests.sps` (add one `harness-group`; add `(byte-machine test prng)` to the imports)

**Interfaces:**
- Consumes: `cm-ref`, `cm-gen`, `run-slices`, `u8`, `sequence-bytes` from Task 1.
- Produces: nothing new for later tasks.

- [ ] **Step 1: Add the PRNG import**

In `differential-sequence-tests.sps`, add `(byte-machine test prng)` to the `import` list (it is already in the lane `SOURCES`):

```scheme
        (byte-machine test prng)
```

- [ ] **Step 2: Add the fragmentation group**

Insert this `harness-group` before `(harness-finish)`:

```scheme
;; Turn a schedule of cut points (a subset of {1,2,3}, ascending) into the list
;; of consecutive [start,end) slices over the 4-byte input, with `empties`
;; zero-width slices spliced in leading, between every real slice, and trailing-
;; before-completion (never after the terminal). Bytes come from one shared
;; bytevector so a resume feed reads the same buffer.
(define seq-input (u8v 1 2 3 4))
(define (slices-for cuts)
  (let ((bounds (append '(0) cuts '(4))))
    (let loop ((bs bounds) (acc '()))
      (if (null? (cdr bs)) (reverse acc)
          (loop (cdr bs) (cons (list seq-input (car bs) (cadr bs)) acc))))))
(define (with-empties slices)
  ;; a leading empty, an empty between each pair, and one empty just before the
  ;; final (completing) slice — all zero-width [i,i) on seq-input at index 0.
  (define e (list seq-input 0 0))
  (let loop ((ss slices) (acc (list e)))     ; leading empty
    (cond ((null? ss) (reverse acc))
          ((null? (cdr ss)) (loop '() (cons (car ss) (cons e acc))))  ; empty then final
          (else (loop (cdr ss) (cons e (cons (car ss) acc)))))))

(harness-group "every fragmentation of 1 2 3 4 reaches stopped in both lanes"
  (lambda ()
    ;; All 8 subsets of the three interior split points {1,2,3}, incl. the empty
    ;; subset (whole input), the three singletons, the three pairs, and the full
    ;; triple.
    (define all-cut-sets
      '(() (1) (2) (3) (1 2) (1 3) (2 3) (1 2 3)))
    (harness-case "each split (and each split-point pair) stops at offset 4"
      (lambda ()
        (for-each
         (lambda (cuts)
           (let ()
             (check-equal (string-append "interpreter cuts " (schedule->string cuts))
                          (car (run-slices cm-ref (slices-for cuts))) 'stopped)
             (check-equal (string-append "generated cuts " (schedule->string cuts))
                          (car (run-slices cm-gen (slices-for cuts))) 'stopped)
             (check-equal (string-append "interpreter stream-offset " (schedule->string cuts))
                          (cadddr (run-slices cm-ref (slices-for cuts))) 4)
             (check-equal (string-append "generated stream-offset " (schedule->string cuts))
                          (cadddr (run-slices cm-gen (slices-for cuts))) 4)))
         all-cut-sets)))
    (harness-case "interpreter and generated agree on every fragmentation"
      (lambda ()
        (let ((bad 'none))
          (for-each
           (lambda (cuts)
             (unless (equal? (run-slices cm-ref (slices-for cuts))
                             (run-slices cm-gen (slices-for cuts)))
               (when (eq? bad 'none) (set! bad cuts))))
           all-cut-sets)
          (check-equal "no split disagreed" bad 'none))))
    (harness-case "leading / intermediate / trailing-before-completion empty feeds still accept"
      (lambda ()
        (check-equal "interpreter with empties"
                     (car (run-slices cm-ref (with-empties (slices-for '(1 2 3))))) 'stopped)
        (check-equal "generated with empties"
                     (car (run-slices cm-gen (with-empties (slices-for '(1 2 3))))) 'stopped)
        (check-equal "empties do not change agreement"
                     (run-slices cm-ref (with-empties (slices-for '(1 2 3))))
                     (run-slices cm-gen (with-empties (slices-for '(1 2 3)))))))
    (harness-case "a deterministic random multi-split schedule accepts and agrees"
      (lambda ()
        (define seed 20260828)
        (let loop ((i 0) (s (make-prng seed)))
          (when (< i 32)
            ;; draw a random ascending subset of {1,2,3}
            (let*-values (((d1 s1) (prng-next s 2))
                          ((d2 s2) (prng-next s1 2))
                          ((d3 s3) (prng-next s2 2)))
              (let ((cuts (append (if (= d1 1) '(1) '())
                                  (if (= d2 1) '(2) '())
                                  (if (= d3 1) '(3) '()))))
                (check-equal (string-append "schedule " (number->string i)
                                            " (seed " (number->string seed) ")")
                             (run-slices cm-ref (slices-for cuts))
                             (run-slices cm-gen (slices-for cuts)))
                (check-equal (string-append "schedule " (number->string i) " stops")
                             (car (run-slices cm-gen (slices-for cuts))) 'stopped))
              (loop (+ i 1) s3))))))))
```

Add the `schedule->string` helper next to the other helpers near the top of the file:

```scheme
(define (schedule->string cuts)
  (if (null? cuts) "()"
      (fold-left (lambda (acc c) (string-append acc " " (number->string c))) "(" cuts)))
```

- [ ] **Step 3: Run the sequence lanes**

Run:
```bash
make build
ctest --preset pr -R 'byte-machine\.differential\.sequence' --output-on-failure
```
Expected: both lanes **PASS** — every one of the 8 split sets stops at stream-offset 4 in both executors, empty feeds are inert, and 32 random schedules agree. A red here is a real resume/`need-input` bug: STOP and debug, do not weaken the schedule.

- [ ] **Step 4: Whole suite, then commit**

Run:
```bash
make test
```
Expected: PASS.

```bash
git add test/common/differential-sequence-tests.sps
git commit -m "test: M2 slice 1 — fragmentation, split-point pairs, multi-split schedule, empty feeds"
```

---

## Task 3: Nonzero-offset slices and exact next/consumed/stream-offset

**Files:**
- Modify: `test/common/differential-sequence-tests.sps` (add one `harness-group`)

**Interfaces:**
- Consumes: `cm-ref`, `cm-gen`, `run-slices`, `u8v` from Tasks 1–2.

- [ ] **Step 1: Add the nonzero-offset group**

Insert before `(harness-finish)`:

```scheme
(harness-group "nonzero-offset slices report exact next / consumed / stream-offset"
  (lambda ()
    ;; The 4 real bytes sit at indices 1..4 of a padded buffer [9 1 2 3 4 9].
    (define padded (u8v 9 1 2 3 4 9))
    (harness-case "one nonzero-offset slice [1,5) accepts with exact fields in both"
      (lambda ()
        ;; whole sequence in one feed over [1,5): stopped, next=5, consumed=4,
        ;; stream-offset=4.
        (check-equal "interpreter" (run-slices cm-ref (list (list padded 1 5)))
                     '(stopped 5 4 4 #f))
        (check-equal "generated"   (run-slices cm-gen (list (list padded 1 5)))
                     '(stopped 5 4 4 #f))))
    (harness-case "a nonzero-offset slice split mid-sequence resumes with exact fields"
      (lambda ()
        ;; feed [1,3) (bytes 1,2 -> need-input, next=3, consumed=2, offset=2)
        ;; then [3,5) (bytes 3,4 -> stopped, next=5, consumed=2, offset=4).
        (check-equal "interpreter"
                     (run-slices cm-ref (list (list padded 1 3) (list padded 3 5)))
                     '(stopped 5 2 4 #f))
        (check-equal "generated"
                     (run-slices cm-gen (list (list padded 1 3) (list padded 3 5)))
                     '(stopped 5 2 4 #f))))
    (harness-case "an empty nonzero-offset slice consumes nothing and needs input"
      (lambda ()
        ;; an empty slice [3,3) after feeding [1,3): need-input, next=3,
        ;; consumed=0, stream-offset=2 (unchanged).
        (check-equal "interpreter"
                     (run-slices cm-ref (list (list padded 1 3) (list padded 3 3)))
                     '(need-input 3 0 2 #f))
        (check-equal "generated"
                     (run-slices cm-gen (list (list padded 1 3) (list padded 3 3)))
                     '(need-input 3 0 2 #f))))))
```

- [ ] **Step 2: Run the sequence lanes**

Run:
```bash
make build
ctest --preset pr -R 'byte-machine\.differential\.sequence' --output-on-failure
```
Expected: both lanes **PASS** with the exact field tuples asserted (`next` is the absolute index into the supplied bytevector; `consumed = next - start`; `stream-offset` is the absolute committed count). A red means a `next`/`consumed`/offset computation bug: STOP and debug.

- [ ] **Step 3: Whole suite, then commit**

Run:
```bash
make test
```
Expected: PASS.

```bash
git add test/common/differential-sequence-tests.sps
git commit -m "test: M2 slice 1 — nonzero-offset slices with exact next/consumed/stream-offset"
```

---

## Task 4: Extend the §9.6 example to feed a nonzero-offset slice

**Files:**
- Modify: `test/common/example-one-byte-tests.sps` (add one `harness-case`)

**Interfaces:**
- Consumes: the existing example program's `one-byte` machine, `genfile`, and the generated `one-byte-parser` binding.

- [ ] **Step 1: Add a nonzero-offset case to the example**

In `test/common/example-one-byte-tests.sps` (§25 M2: "extend the Section 9.6 examples and their tests to feed a nonzero-offset slice"), **replace the whole `harness-group` "construct, verify, compile, emit, import, run" block** with the two-case version below. The first case is unchanged; the second reuses the `(generated one-byte)` library the first already emitted and loaded (no re-emit / re-load) and feeds byte `0` at index 1 of a padded buffer over `[1,2)`. The full block is shown (not a splice) so the parenthesis nesting is exact:

```scheme
(harness-group "construct, verify, compile, emit, import, run"
  (lambda ()
    (harness-case "the emitted parser accepts the exact byte across the library boundary"
      (lambda ()
        (let ((comp (compile-machine one-byte '())))
          (check "verified and compiled" (compilation-ok? comp))
          (call-with-port (open-file-output-port genfile (file-options no-fail))
            (lambda (p) (emit-machine comp 'one-byte-parser p)))
          (load genfile)
          (let* ((cm (eval 'one-byte-parser (environment '(generated one-byte))))
                 (input (make-bytevector 1 0))
                 (r (parser-feed! (make-parser cm '() #f) input 0 1)))
            (check-equal "status" (parser-result-status r) 'stopped)
            (check-equal "consumed one byte" (parser-result-consumed r) 1)))))
    (harness-case "the emitted parser accepts the exact byte in a nonzero-offset slice"
      (lambda ()
        (let* ((cm (eval 'one-byte-parser (environment '(generated one-byte))))
               (padded (let ((v (make-bytevector 3 9))) (bytevector-u8-set! v 1 0) v))
               (r (parser-feed! (make-parser cm '() #f) padded 1 2)))
          (check-equal "status" (parser-result-status r) 'stopped)
          (check-equal "next is the absolute index past the consumed byte"
                       (parser-result-next r) 2)
          (check-equal "consumed one byte" (parser-result-consumed r) 1)
          (check-equal "stream offset advanced by one" (parser-result-stream-offset r) 1))))))
```

(The existing example lanes rebuild and rerun this program; no CMake change is needed.)

- [ ] **Step 2: Run the example lanes**

Run:
```bash
make build
ctest --preset pr -R 'byte-machine\.example\.one-byte' --output-on-failure
```
Expected: both `...chez.source` and `...chez.aot` **PASS**, now including the nonzero-offset case.

- [ ] **Step 3: Whole suite, re-measure, then commit**

Run:
```bash
make test
make test-all
```
Expected: both PASS. Note the new `release` lane count (M1 baseline 60 + the two Task-1 sequence lanes = **62**; the example and program edits add no lanes) so a later record cites the measured number, not a guess. `no-scheme` stays 8/8; Scheme mutation stays 37/104 (no `src/` change).

```bash
git add test/common/example-one-byte-tests.sps
git commit -m "test: M2 slice 1 — extend the §9.6 example to a nonzero-offset slice"
```

---

## Self-Review

1. **Spec coverage (design §4):** ≥3-byte machine → Task 1 (four bytes). Fragmentation / split-point pairs / multi-split / leading-intermediate-trailing empty feeds → Task 2. All-256 at each position → Task 1. Arbitrary/nonzero-offset slices with exact `next`/`consumed`/`stream-offset` → Task 3. Extend §9.6 to a nonzero-offset slice → Task 4. Explicit error-edge mode + asserted `next` → Task 1 (reexecute fallback, `next=0` asserted). Both lanes + interpreter≡generated differential → every task asserts both `cm-ref` and `cm-gen`. All §4 exit criteria mapped.
2. **Placeholder scan:** every step shows complete code, exact file paths, and exact `ctest`/`make` commands with expected PASS. No "TBD"/"add error handling"/"similar to". The only literals left to the engine are the measured `release` count (Task 4 Step 3 says re-measure).
3. **Type/name consistency:** `make-sequence-machine`/`sequence-bytes` (Task 1) are used verbatim in Tasks 2–3; `run-slices`/`u8`/`u8v`/`drive`/`list-head-n`/`schedule->string` are all defined in Task 1/2 before use; `cm-ref`/`cm-gen` names match `differential-one-byte-tests.sps`. Lane names use layer `differential`/`example` so the `pr` filter includes them. `make-byte-dispatch-node`/`make-machine`/`make-edge` argument order matches `src/byte-machine/private/ir.sls` and `one-byte-machine.sls`.
4. **No `src/` change, no sticky-repeat reliance:** confirmed — every schedule stops feeding at the first terminal; the §12.2 sticky-repeat fix and the finish/pause work stay in Slices ②/③.
