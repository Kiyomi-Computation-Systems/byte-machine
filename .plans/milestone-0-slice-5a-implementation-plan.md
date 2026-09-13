# Milestone 0 Slice 5a — Content Fingerprint and Lane Provenance: Implementation Plan

Status: executed; delivered 2026-08-17

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every Scheme lane a content fingerprint of the shared bodies it ran, checked against a value the build computed, so that a lane which executed different or stale text exits 3 instead of reporting success.

**Architecture:** A portable rolling-hash body (`fingerprint.scm`) is included by both runtime adapters alongside the existing runner. A new adapter procedure `adapter-file-bytes` reads files through a binary port on each runtime. At build time a Chez launcher `load`s that same body and writes the expected combined value to a file. At run time the harness fingerprints the manifest it was given, compares against that file, and exits 3 on any disagreement — before any test case runs. A process that receives no manifest at all was not started by a lane registration, and skips the check rather than refusing; the guarantee that every registered lane has one is enforced at configure time instead.

**Tech Stack:** Chez Scheme 10.4.1, Gambit 4.9.8, CMake ≥ 3.26, CTest. No external Scheme libraries; no SRFI; no package manager.

**Design spec:** [`milestone-0-slice-5a-content-fingerprint.md`](./milestone-0-slice-5a-content-fingerprint.md). Decision labels `V1`–`V12` below refer to its §3.

## Global Constraints

- **Portable subset only in shared bodies.** `test/support/harness/shared/*.scm` and `src/common/**/*.scm` are included verbatim by both an R6RS library and an R7RS `define-library`. They may use only identifiers common to both standards plus the adapter protocol, and must never name Chez or Gambit. Excluded: `define-record-type`, string ports, `error`, condition accessors, hash tables, sorting, bitwise operations.
- **Arithmetic only, never bitwise.** Neither R6RS base nor R7RS small guarantees bitwise operations; both guarantee exact integers of unbounded range. `modulo`, `quotient`, and `remainder` are already exported by both adapters.
- **Never `number->string` with a radix.** Measured 2026-08-17 on this machine: `(number->string 255 16)` is `FF` on Chez and `ff` on Gambit. Hex comes from the explicit digit table only (V-forced, spec §2.1).
- **Exit status vocabulary is 0, 1, 2, 3.** Already declared in `cmake/ByteMachineExpectExit.cmake:30`. 0 pass, 1 assertion failed, 2 harness/configuration error, 3 provenance failure. Nothing else may be produced or expected.
- **The two adapters must export exactly the same names.** `test/support/harness/chez/byte-machine/test/harness.sls` and `test/support/harness/gambit/byte-machine/test/harness.sld`. Checked by mutation, not review.
- **Export only what a test body calls.** A name used solely inside the shared runner body resolves internally regardless of the export list, so deleting its export is undetectable. See the recorded survivor for `harness-summary` in `CHANGELOG.md`.
- **Environment variable names, exact:** `BYTE_MACHINE_FINGERPRINT_FILES`, `BYTE_MACHINE_EXPECT_FINGERPRINT_FILE`.
- **Manifest separator is `|`** (V10). Illegal in a Windows path, which avoids the `:` vs `;` question the spike left open at §9 item 3.
- **Every test runs from an isolated build-tree directory**, never the repository. `byte_machine_add_test` enforces this.
- **Run the suite before every commit.** `make test` must be green, and `ctest --preset no-scheme` must stay 10/10.
- **Prefer a mutation caught by a failed comparison over one caught by a raise** (AGENTS.md). A raise-based catch depends on where the mutant happens to crash rather than on an assertion naming the decision. Every mutation in Task 7 is comparison- or status-based for this reason; the two export-list mutations are the exception, because an export that is not there can only fail at library construction, and the existing passes 1 and 2 already establish that form.
- **A measurement earns a place in a design document or decision record only once it has been re-taken against the shipped artifact** (AGENTS.md). The seven values in the table below are fingerprints of constructed bytevectors and of an immutable fixture, so nothing this slice ships can move them. Any fingerprint *of a shared body* is a different matter: this slice edits `harness-runner.scm`, so every combined value over it expires as the slice proceeds. Never copy one forward — re-take it.

### Fingerprint constants — copy these exactly

```scheme
(define harness-fingerprint-modulus 2305843009213693951) ; 2^61 - 1
(define harness-fingerprint-multiplier 1000003)
(define harness-fingerprint-seed 14695981039346656)
(define harness-hex-digits "0123456789abcdef")
```

### Verified expected values

Measured 2026-08-17 on Chez 10.4.1 and Gambit 4.9.8, identical on both. Use these as literals; do not recompute them by hand.

| Input | Fingerprint |
| --- | --- |
| empty bytevector | `3435eab979e3e0` |
| bytes `97 98 99` | `60b8174578c282d` |
| bytes `0 97 98 99` | `bac4261bdc123` |
| bytes `0 0 97 98 99` | `1b3297b7cc8f592c` |
| the file `byte-machine\n` (13 bytes) | `b1058d10fb543b0` |
| combine `(1 2)` | `3cabbf7defc450d` |
| combine `(2 1)` | `3cabbf7df0b874f` |

Fingerprint strings have no leading-zero padding, so their length varies (13 to 16 digits above). A short value is not a truncated one.

---

## File Structure

**Created**

| File | Responsibility |
| --- | --- |
| `test/support/harness/shared/fingerprint.scm` | The algorithm. Pure except for `harness-fingerprint-file`, which calls `adapter-file-bytes`. Included by both adapters. |
| `test/fixtures/fingerprint-sample.bin` | 13 known bytes, so `adapter-file-bytes` has a cross-runtime assertion that does not depend on the build layer. |
| `test/support/launchers/fingerprint-manifest.ss` | Build-time expectation. Runs under Chez, `load`s `fingerprint.scm` rather than reimplementing it. |
| `.decisions/0004-content-fingerprint-and-provenance.md` | Decision record. |

**Modified**

| File | Change |
| --- | --- |
| `test/support/harness/chez/byte-machine/test/harness.sls` | `adapter-file-bytes`, export list, `(include "fingerprint.scm")` |
| `test/support/harness/gambit/byte-machine/test/harness.sld` | same, with a source-relative include path |
| `test/support/harness/shared/harness-runner.scm` | `harness-bytes->string`, `harness-provenance-diagnosis`, `harness-verify-provenance!`, call from `harness-begin` |
| `test/support/harness/self/harness-self-tests.scm` | cases for the algorithm, `adapter-file-bytes`, and the pure diagnosis |
| `test/support/harness/self/harness-bootstrap.scm` | direct `harness-verify-provenance!` call (V11) |
| `cmake/ByteMachineSchemeLane.cmake` | `SHARED_BODIES` (required), `WRONG_FINGERPRINT`, the two environment variables |
| `test/support/cmake/ByteMachineSchemeLaneSpec.cmake` | cases for the new arguments |
| `test/CMakeLists.txt` | `byte_machine_expected_fingerprint`, manifests on all lanes, 5 provenance lanes, 2 cwd-matrix copies |
| `test/support/cmake/SchemeMutationSuite.cmake` | passes 28–31, counter updates |
| `CHANGELOG.md` | Added entry |

---

## Task 1: The fingerprint algorithm

**Files:**
- Create: `test/support/harness/shared/fingerprint.scm`
- Modify: `test/support/harness/chez/byte-machine/test/harness.sls`
- Modify: `test/support/harness/gambit/byte-machine/test/harness.sld`
- Test: `test/support/harness/self/harness-self-tests.scm`

**Interfaces:**
- Consumes: `harness-group`, `harness-case`, `check`, `check-equal`, `check-not-equal` from the existing runner.
- Produces: `harness-fingerprint-bytevector` (bytevector → exact non-negative integer), `harness-fingerprint-combine` (list of integers → integer), `harness-fingerprint->string` (integer → lowercase hex string, no padding, `"0"` for zero).

**`harness-fingerprint-file` is NOT part of this task.** It references `adapter-file-bytes`, which arrives in Task 2, and R6RS requires every free identifier in a library body to be bound — Chez refuses the whole library at import time whether or not anything calls it. Defining it here breaks every Chez lane in the tree. Task 2 adds it alongside `adapter-file-bytes`.

- [ ] **Step 1: Write the failing test**

Append to `test/support/harness/self/harness-self-tests.scm`, immediately before its final `harness-finish`-adjacent section (find the last `harness-group` form and add after it):

```scheme
;; --- the content fingerprint ------------------------------------------------
;;
;; Every value below was measured on Chez 10.4.1 and Gambit 4.9.8 on
;; 2026-08-17 and was identical on both. They are literals rather than
;; recomputations because a test that recomputes the thing under test with the
;; thing under test asserts only that it is deterministic.

(harness-group "fingerprint"
  (lambda ()

    (harness-case "an empty bytevector folds to the seed"
      (lambda ()
        (check-equal "empty"
                     (harness-fingerprint->string
                      (harness-fingerprint-bytevector (harness-bytes 0 '())))
                     "3435eab979e3e0")))

    (harness-case "three ASCII bytes"
      (lambda ()
        (check-equal "abc"
                     (harness-fingerprint->string
                      (harness-fingerprint-bytevector (harness-bytes 3 '(97 98 99))))
                     "60b8174578c282d")))

    ;; The +1 on each byte exists for exactly this: without it a leading NUL is
    ;; absorbed and these three values collapse into one.
    (harness-case "leading zero bytes are significant"
      (lambda ()
        (let ((abc (harness-fingerprint->string
                    (harness-fingerprint-bytevector (harness-bytes 3 '(97 98 99)))))
              (one (harness-fingerprint->string
                    (harness-fingerprint-bytevector (harness-bytes 4 '(0 97 98 99)))))
              (two (harness-fingerprint->string
                    (harness-fingerprint-bytevector
                     (harness-bytes 5 '(0 0 97 98 99))))))
          (check-equal "one leading NUL" one "bac4261bdc123")
          (check-equal "two leading NULs" two "1b3297b7cc8f592c")
          (check-not-equal "one NUL differs from none" one abc)
          (check-not-equal "two NULs differ from one" two one))))

    (harness-case "combining is order sensitive"
      (lambda ()
        (check-equal "(1 2)"
                     (harness-fingerprint->string (harness-fingerprint-combine '(1 2)))
                     "3cabbf7defc450d")
        (check-equal "(2 1)"
                     (harness-fingerprint->string (harness-fingerprint-combine '(2 1)))
                     "3cabbf7df0b874f")))

    ;; Chez renders FF where Gambit renders ff for (number->string 255 16), so
    ;; the rendering cannot go through a radix conversion. This case is what
    ;; notices if someone ever changes it back.
    (harness-case "hex digits are lowercase on every runtime"
      (lambda ()
        (check-equal "255" (harness-fingerprint->string 255) "ff")
        (check-equal "3735928559" (harness-fingerprint->string 3735928559) "deadbeef")
        (check-equal "zero" (harness-fingerprint->string 0) "0")))))
```

Add this helper near the top of the same file, under the existing helper definitions, because `bytevector` is R7RS-only and `u8-list->bytevector` is R6RS-only, so neither is available in the shared subset:

```scheme
;; Construct a bytevector from a length and a list of byte values. Written by
;; hand because the two standards disagree about every convenient constructor:
;; R7RS has (bytevector 97 98 99), R6RS has (u8-list->bytevector '(97 98 99)),
;; and a shared body may name neither.
(define (harness-bytes length bytes)
  (let ((bv (make-bytevector length 0)))
    (let loop ((i 0) (rest bytes))
      (if (null? rest)
          bv
          (begin (bytevector-u8-set! bv i (car rest))
                 (loop (+ i 1) (cdr rest)))))))
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
make dev
```

Expected: `byte-machine.harness.self.chez.source` and `byte-machine.harness.self.gambit.source` FAIL. The failure is at library construction — `Exception: variable harness-fingerprint-bytevector is not bound` on Chez — not an assertion failure, because nothing defines the names yet.

- [ ] **Step 3: Create the shared algorithm body**

Create `test/support/harness/shared/fingerprint.scm`:

```scheme
;;; Content fingerprint for shared test bodies.
;;;
;;; A run reports the digest of the bodies it executed so that a stale
;;; artifact, a copied backend-specific variant, or a basename collision is
;;; detectable rather than merely unlikely. Chez and Gambit must report the
;;; same value for the same text; that agreement is the claim, and everything
;;; below is chosen to keep it from depending on anything unspecified.
;;;
;;; This is a change detector, not a cryptographic digest. It is a polynomial
;;; rolling hash modulo the Mersenne prime 2^61-1. Do not use it for anything
;;; security relevant.
;;;
;;; PORTABILITY CONTRACT
;;;
;;; Included verbatim by both adapters, like harness-runner.scm. Only the
;;; common R6RS/R7RS subset plus the adapter protocol. The arithmetic is
;;; deliberately not bitwise: neither standard's base library guarantees
;;; bitwise operations, and both guarantee exact integers of unbounded range,
;;; so arithmetic is the portable choice. Intermediate products exceed 64 bits,
;;; which is what makes exact bignums load-bearing rather than incidental.
;;;
;;; WHAT THIS CANNOT PROVE
;;;
;;; The manifest is declared, not observed. Scheme cannot portably report which
;;; files an `include` spliced in, so a matching fingerprint means the declared
;;; text is unchanged and both runtimes read it identically -- not that the run
;;; included exactly those files. See section 5.3 of the slice-5a design.

(define harness-fingerprint-modulus 2305843009213693951) ; 2^61 - 1
(define harness-fingerprint-multiplier 1000003)
(define harness-fingerprint-seed 14695981039346656)

;; Fold one byte at a time. The +1 keeps leading zero bytes significant: without
;; it a NUL contributes nothing and two files differing only by a run of leading
;; NULs fingerprint identically.
(define (harness-fingerprint-bytevector bv)
  (let ((n (bytevector-length bv)))
    (let loop ((i 0)
               (h (modulo harness-fingerprint-seed harness-fingerprint-modulus)))
      (if (= i n)
          h
          (loop (+ i 1)
                (modulo (+ (* h harness-fingerprint-multiplier)
                           (+ (bytevector-u8-ref bv i) 1))
                        harness-fingerprint-modulus))))))

;; harness-fingerprint-file is NOT defined here. It would reference
;; adapter-file-bytes, which Task 2 supplies, and R6RS requires every free
;; identifier in a library body to be bound: Chez refuses the library at import
;; time whether or not anything calls it. Task 2 adds the definition and its
;; export together with adapter-file-bytes.

;; Combine per-file fingerprints in the order given. Order is significant, so a
;; reordered manifest is a different combined value: the result identifies a
;; sequence of bodies, not a set of them.
(define (harness-fingerprint-combine fingerprints)
  (let loop ((rest fingerprints)
             (h (modulo harness-fingerprint-seed harness-fingerprint-modulus)))
    (if (null? rest)
        h
        (loop (cdr rest)
              (modulo (+ (* h harness-fingerprint-multiplier) (+ (car rest) 1))
                      harness-fingerprint-modulus)))))

;; Lowercase hex from an explicit digit table, never number->string with a
;; radix. Measured 2026-08-17: Chez yields "FF" and Gambit yields "ff" for
;; (number->string 255 16). Neither is wrong -- the standards do not fix the
;; case -- so a radix conversion would make the one claim this file exists to
;; establish depend on a detail these two runtimes already answer differently.
;; Comparing case-insensitively later would be worse: it would hide exactly the
;; class of divergence this file exists to expose.
(define harness-hex-digits "0123456789abcdef")

(define (harness-fingerprint->string h)
  (if (= h 0)
      "0"
      (let loop ((n h) (acc (list)))
        (if (= n 0)
            (list->string acc)
            (loop (quotient n 16)
                  (cons (string-ref harness-hex-digits (remainder n 16)) acc))))))
```

- [ ] **Step 4: Include the body and export its names from the Chez adapter**

In `test/support/harness/chez/byte-machine/test/harness.sls`, add to the export list immediately after the `harness-counters harness-restore-counters! harness-capture-state` line:

```scheme
    ;; content fingerprint (harness-fingerprint-file arrives in Task 2,
    ;; alongside adapter-file-bytes)
    harness-fingerprint-bytevector harness-fingerprint-combine
    harness-fingerprint->string
```

Then replace the final include with two, keeping the surrounding comment:

```scheme
  ;; --- shared bodies -------------------------------------------------------
  ;;
  ;; Included by bare filename, resolved through the launcher's
  ;; source-directories. Nothing below this point is Chez-specific.

  (include "fingerprint.scm")
  (include "harness-runner.scm"))
```

- [ ] **Step 5: Do the same for the Gambit adapter**

In `test/support/harness/gambit/byte-machine/test/harness.sld`, add the identical four export names after the same `harness-counters harness-restore-counters! harness-capture-state` line:

```scheme
    ;; content fingerprint (harness-fingerprint-file arrives in Task 2,
    ;; alongside adapter-file-bytes)
    harness-fingerprint-bytevector harness-fingerprint-combine
    harness-fingerprint->string
```

Then replace the final include, keeping its comment:

```scheme
  ;; --- shared bodies -------------------------------------------------------
  ;;
  ;; Source-file-relative, which is how Gambit resolves include inside
  ;; define-library. Nothing below this point is Gambit-specific.

  (include "../../../shared/fingerprint.scm")
  (include "../../../shared/harness-runner.scm"))
```

- [ ] **Step 6: Copy `fingerprint.scm` into the two non-empty matrix directories**

Both adapters now include it, so it joins the set of bodies the working-directory matrix must carry. This is required *in this task*, not later: the matrix's fixture directories mirror every shared body the harness library includes, and the launcher mutation in `SchemeMutationSuite.cmake` fails all three Chez lanes identically for want of the file — destroying the asymmetry that makes passes 21–23 evidence — from the moment the include is added.

In `test/CMakeLists.txt`, alongside the existing `configure_file` calls for `harness-runner.scm`, add:

```cmake
configure_file("${BYTE_MACHINE_HARNESS_SHARED_DIR}/fingerprint.scm"
               "${BYTE_MACHINE_CWD_IDENTICAL_DIR}/fingerprint.scm" COPYONLY)
configure_file("${BYTE_MACHINE_HARNESS_SHARED_DIR}/fingerprint.scm"
               "${BYTE_MACHINE_CWD_DECOY_DIR}/fingerprint.scm" COPYONLY)
```

This is the only change to `test/CMakeLists.txt` this task makes.

- [ ] **Step 7: Run the tests to verify they pass**

```bash
make test
```

Expected: 40/40 pass. The five new fingerprint cases run inside the two self-tests lanes, on both runtimes, reporting the same literals.

- [ ] **Step 8: Commit**

```bash
git add test/support/harness/shared/fingerprint.scm test/support/harness/chez test/support/harness/gambit test/support/harness/self/harness-self-tests.scm test/CMakeLists.txt && git commit -m "feat: a portable content fingerprint both runtimes agree on"
```

---

## Task 2: Reading bytes through a binary port

**Files:**
- Create: `test/fixtures/fingerprint-sample.bin`
- Modify: `test/support/harness/chez/byte-machine/test/harness.sls`
- Modify: `test/support/harness/gambit/byte-machine/test/harness.sld`
- Modify: `cmake/ByteMachineSchemeLane.cmake`
- Test: `test/support/harness/self/harness-self-tests.scm`

**Interfaces:**
- Consumes: `harness-fingerprint-bytevector`, `harness-fingerprint->string` from Task 1.
- Also produces `harness-fingerprint-file` (path → integer), which Task 1 deliberately did not define: it references `adapter-file-bytes`, and an unbound free identifier makes Chez refuse the entire library at import time. Add it to `test/support/harness/shared/fingerprint.scm` in the same step that adds `adapter-file-bytes`, and add its name to both adapters' export lists at the same time:

```scheme
(define (harness-fingerprint-file path)
  (harness-fingerprint-bytevector (adapter-file-bytes path)))
```
- Produces: `adapter-file-bytes` (path string → bytevector; an empty file yields a zero-length bytevector, never an EOF object). The self-tests reach the fixture through a new environment variable `BYTE_MACHINE_FINGERPRINT_SAMPLE`.

The self-tests call `adapter-file-bytes` **directly**, not only through `harness-fingerprint-file`. That is deliberate: a name used solely inside the shared runner body resolves internally whatever the export list says, so an export-list mutation against it would be undetectable — the trap `CHANGELOG.md` already records for `harness-summary`.

- [ ] **Step 1: Create the fixture**

```bash
printf 'byte-machine\n' > test/fixtures/fingerprint-sample.bin
od -c test/fixtures/fingerprint-sample.bin
```

Expected: `b y t e - m a c h i n e \n` and a total of 13 bytes (`0000015` octal). `.gitattributes` already marks fixture trees binary, so this file is exempt from LF normalization and its bytes survive a checkout on any platform.

- [ ] **Step 2: Write the failing test**

Append inside the existing `harness-group "fingerprint"` form from Task 1, as its last two cases:

```scheme
    ;; adapter-file-bytes is called directly here, not only through
    ;; harness-fingerprint-file. A name used only inside the shared runner body
    ;; resolves internally regardless of the export list, so testing it only
    ;; indirectly would make its export-list mutation undetectable.
    (harness-case "a file is read as its exact bytes"
      (lambda ()
        (let ((bv (adapter-file-bytes
                   (adapter-environment-variable "BYTE_MACHINE_FINGERPRINT_SAMPLE"))))
          (check-equal "length" (bytevector-length bv) 13)
          (check-equal "first byte is b" (bytevector-u8-ref bv 0) 98)
          (check-equal "last byte is LF" (bytevector-u8-ref bv 12) 10))))

    (harness-case "both runtimes fingerprint the same file identically"
      (lambda ()
        (check-equal "sample"
                     (harness-fingerprint->string
                      (harness-fingerprint-file
                       (adapter-environment-variable "BYTE_MACHINE_FINGERPRINT_SAMPLE")))
                     "b1058d10fb543b0")))
```

- [ ] **Step 3: Run the tests to verify they fail**

```bash
make dev
```

Expected: both self-tests lanes FAIL with `variable adapter-file-bytes is not bound` on Chez. Not an assertion failure — nothing defines it yet.

- [ ] **Step 4: Implement `adapter-file-bytes` on Chez**

In `test/support/harness/chez/byte-machine/test/harness.sls`, add after `adapter-describe-condition` and before `adapter-flush-output`:

```scheme
  ;; A binary port, so the value is a fingerprint of bytes rather than of
  ;; decoded characters -- and so an LF is an LF on a platform whose text ports
  ;; would translate it. get-bytevector-all returns the EOF object for an empty
  ;; file rather than a zero-length bytevector, so an empty file fingerprints as
  ;; the seed instead of raising.
  (define (adapter-file-bytes path)
    (let* ((port (open-file-input-port path))
           (bytes (get-bytevector-all port)))
      (close-port port)
      (if (eof-object? bytes) (make-bytevector 0) bytes)))
```

Add `adapter-file-bytes` to the export list, on the `adapter-value->string adapter-describe-condition adapter-flush-output` line:

```scheme
    adapter-value->string adapter-describe-condition adapter-file-bytes
    adapter-flush-output
```

- [ ] **Step 5: Implement `adapter-file-bytes` on Gambit**

`(scheme file)` is not currently imported by the Gambit adapter. Add it to the import list:

```scheme
  (import (scheme base) (scheme write) (scheme process-context) (scheme file)
          (only (gambit) system-version-string system-type-string
                display-exception))
```

Add the procedure after `adapter-describe-condition` and before `adapter-flush-output`, inside the `(begin ...)` block:

```scheme
    ;; A binary port, for the reason the Chez adapter gives. R7RS has no
    ;; get-bytevector-all, so this reads in chunks and concatenates; 65536 is a
    ;; block size, not a limit, and a body larger than one chunk is the ordinary
    ;; case rather than an edge case.
    (define (adapter-file-bytes path)
      (let ((port (open-binary-input-file path)))
        (let loop ((chunks '()) (total 0))
          (let ((chunk (read-bytevector 65536 port)))
            (if (eof-object? chunk)
                (begin
                  (close-port port)
                  (let ((bv (make-bytevector total 0)))
                    (let fill ((rest (reverse chunks)) (at 0))
                      (if (null? rest)
                          bv
                          (let ((c (car rest)))
                            (let copy ((i 0))
                              (if (< i (bytevector-length c))
                                  (begin
                                    (bytevector-u8-set! bv (+ at i)
                                                        (bytevector-u8-ref c i))
                                    (copy (+ i 1)))))
                            (fill (cdr rest)
                                  (+ at (bytevector-length c))))))))
                (loop (cons chunk chunks) (+ total (bytevector-length chunk))))))))
```

Add `adapter-file-bytes` to the export list on the same line as its Chez counterpart:

```scheme
    adapter-value->string adapter-describe-condition adapter-file-bytes
    adapter-flush-output
```

- [ ] **Step 6: Point the lanes at the fixture**

In `cmake/ByteMachineSchemeLane.cmake`, inside `byte_machine_add_scheme_lane`, replace the single-line environment assignment:

```cmake
  set(environment "BYTE_MACHINE_EXECUTION_MODE=source" ${arg_ENVIRONMENT})
```

with:

```cmake
  # The fixture is immutable and lives in the source tree; a lane only ever
  # reads it. Set for every lane rather than only the self-tests, so a body that
  # starts needing it does not also need a registration change.
  set(environment
    "BYTE_MACHINE_EXECUTION_MODE=source"
    "BYTE_MACHINE_FINGERPRINT_SAMPLE=${CMAKE_SOURCE_DIR}/test/fixtures/fingerprint-sample.bin"
    ${arg_ENVIRONMENT})
```

- [ ] **Step 7: Run the tests to verify they pass**

```bash
make test
```

Expected: 40/40 pass. Both runtimes report `b1058d10fb543b0` for the same 13-byte file.

**Three files beyond the list above also need changes, all found during execution:**

- `test/support/cmake/ByteMachineSchemeLaneSpec.cmake` — the modified module's own specification asserts the exact environment string the module builds, so it must gain the new entry. Use `${CMAKE_SOURCE_DIR}` symbolically rather than a hardcoded path, so the spec and the module evaluate the same variable in the same process and the assertion holds wherever it runs.
- `test/support/cmake/MutationSuite.cmake` — one existing mutation anchors on the environment line this task edits, and must be re-anchored to the moved text. Re-anchor it; do not delete it. The total must stay at 96.
- `test/CMakeLists.txt` — the Scheme mutation suite is registered with `byte_machine_add_test`, not as a lane, and its `execute_process` children inherit that registration's environment. Add `BYTE_MACHINE_FINGERPRINT_SAMPLE` to its `ENVIRONMENT` list pointing at the source-tree fixture, or its unmutated baseline goes red the moment the self-tests read the fixture.

- [ ] **Step 8: Commit**

```bash
git add test/fixtures/fingerprint-sample.bin test/support/harness test/support/cmake cmake/ByteMachineSchemeLane.cmake test/CMakeLists.txt && git commit -m "feat: read a file as bytes on both runtimes, through a binary port"
```

---

## Task 3: The build-time expectation

**Files:**
- Create: `test/support/launchers/fingerprint-manifest.ss`
- Modify: `test/CMakeLists.txt`

**Interfaces:**
- Consumes: `test/support/harness/shared/fingerprint.scm` from Task 1, by `load` rather than by reimplementation (V6).
- Produces: `byte_machine_expected_fingerprint(<name> <out_var> <body>...)`, setting `<out_var>` to the path of a build-tree file containing the combined fingerprint. Keyed by a digest of the manifest, so registrations sharing a manifest share one computation.

- [ ] **Step 1: Write the launcher**

Create `test/support/launchers/fingerprint-manifest.ss`:

```scheme
;;; Compute the expected combined fingerprint of a manifest, at build time.
;;;
;;; Usage:
;;;   fingerprint-manifest.ss <shared-dir> <output> <body>...
;;;
;;; A lane prints the combined fingerprint of the bodies it executed. Until
;;; something reads that value back it is a claim, not a check: two lanes can
;;; print different digests for text both say they ran, and a suite that only
;;; prints stays green. This produces the value each lane must agree with,
;;; computed by the build from the repository sources before anything is
;;; compiled from them.
;;;
;;; THE ALGORITHM IS NOT REIMPLEMENTED HERE
;;;
;;; fingerprint.scm is loaded verbatim, so this program and the runner cannot
;;; drift apart. A second implementation agreeing with the first is the kind of
;;; proof that proves nothing -- and when it stopped agreeing, the disagreement
;;; would look exactly like the defect this file exists to detect.
;;;
;;; Consequence, recorded because it is not obvious: this runs under Chez, so a
;;; Chez lane compares Chez's output against a Chez computation and agrees with
;;; itself by construction. It is the Gambit lane that makes the comparison
;;; cross-runtime. See section 6.1 of the slice-5a design.

;;; Status 2 is the harness's "harness, configuration, or registration error",
;;; the same meaning the Chez source launcher gives it.
(define (die message)
  (display "byte-machine-fingerprint: HARNESS-ERROR " (current-error-port))
  (display message (current-error-port))
  (newline (current-error-port))
  (exit 2))

(define args (command-line-arguments))

(if (< (length args) 3)
    (die "usage: fingerprint-manifest.ss <shared-dir> <output> <body>..."))

(define shared-dir (list-ref args 0))
(define output (list-ref args 1))
(define bodies (list-tail args 2))

;; The adapter protocol's one member this program needs. Defined before the
;; load, because the loaded body calls it.
(define (adapter-file-bytes path)
  (if (not (file-exists? path))
      (die (string-append "manifest body does not exist: " path)))
  (let* ((port (open-file-input-port path))
         (bytes (get-bytevector-all port)))
    (close-port port)
    (if (eof-object? bytes) (make-bytevector 0) bytes)))

(load (string-append shared-dir "/fingerprint.scm"))

(define combined
  (harness-fingerprint->string
   (harness-fingerprint-combine (map harness-fingerprint-file bodies))))

;; No trailing newline. The reader trims whitespace anyway, but writing exactly
;; the value keeps the file's bytes equal to the string it represents.
(let ((port (open-file-output-port output (file-options no-fail))))
  (put-bytevector port (string->utf8 combined))
  (close-port port))

(display "byte-machine-fingerprint: ")
(display combined)
(newline)
(exit 0)
```

- [ ] **Step 2: Verify it produces the measured value**

```bash
/opt/homebrew/bin/chez --script test/support/launchers/fingerprint-manifest.ss test/support/harness/shared /tmp/bm-fp-check.txt test/support/harness/shared/harness-runner.scm src/common/byte-machine/placeholder.scm src/common/byte-machine/placeholder-consumer.scm
```

Expected: a line of the form `byte-machine-fingerprint: <16-or-fewer lowercase hex digits>`.

Do **not** assert `101cc6beb745d034`. The design spec §2 measured that value before this slice began, and Tasks 4 and 5 add roughly eighty lines to `harness-runner.scm`, so it is already stale by the time you run this. What this step verifies is that the launcher runs, loads the algorithm, reads three real bodies, and prints one combined value — not that the value equals a number written down earlier. Run it a second time and confirm you get the same answer; that is the property worth checking here.

- [ ] **Step 3: Add the CMake function**

In `test/CMakeLists.txt`, immediately after the `# --- Source tree paths ---` block and before the `byte_machine_portability_guard(` call, insert:

```cmake
# --- Build-time fingerprint expectations -----------------------------------

set(BYTE_MACHINE_FINGERPRINT_LAUNCHER
    "${CMAKE_CURRENT_LIST_DIR}/support/launchers/fingerprint-manifest.ss")
set(BYTE_MACHINE_FINGERPRINT_DIR "${CMAKE_BINARY_DIR}/fingerprints")

# byte_machine_expected_fingerprint(<name> <out_var> <body>...)
#
# Produce, at build time, the combined fingerprint the named lane must report,
# and set <out_var> to the file holding it.
#
# A build output rather than a configure-time value, because a registration's
# environment is fixed when CMake configures and this must be recomputed
# whenever a body changes -- which is precisely the case it exists to catch.
# The DEPENDS list is what makes that true, so a body added to a manifest
# without being added there produces an expectation that silently never
# refreshes.
#
# Keyed by a digest of the manifest, not by lane name: the value depends only on
# the manifest, and keying by name would spawn one Chez process per lane to
# produce a handful of distinct answers while hiding which lanes claim to run
# the same text.
function(byte_machine_expected_fingerprint name out_var)
  if(NOT ARGN)
    message(FATAL_ERROR
      "byte-machine: '${name}' asked for a fingerprint expectation over no "
      "bodies. An empty manifest fingerprints to the seed on every lane, which "
      "would compare equal forever and check nothing.")
  endif()

  string(JOIN "|" manifest ${ARGN})
  string(SHA256 manifest_digest "${manifest}")
  string(SUBSTRING "${manifest_digest}" 0 16 manifest_key)
  set(expect_file "${BYTE_MACHINE_FINGERPRINT_DIR}/${manifest_key}.fingerprint")

  # add_custom_command rejects a second rule for the same OUTPUT, so the first
  # lane to need a manifest creates the rule and the rest reuse it.
  get_property(known GLOBAL PROPERTY BYTE_MACHINE_FINGERPRINT_MANIFESTS)
  if(NOT manifest_key IN_LIST known)
    set_property(GLOBAL APPEND PROPERTY BYTE_MACHINE_FINGERPRINT_MANIFESTS
                 "${manifest_key}")

    add_custom_command(
      OUTPUT "${expect_file}"
      COMMAND "${CMAKE_COMMAND}" -E make_directory "${BYTE_MACHINE_FINGERPRINT_DIR}"
      COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}" --script
              "${BYTE_MACHINE_FINGERPRINT_LAUNCHER}"
              "${BYTE_MACHINE_HARNESS_SHARED_DIR}"
              "${expect_file}"
              ${ARGN}
      DEPENDS ${ARGN}
              "${BYTE_MACHINE_FINGERPRINT_LAUNCHER}"
              "${BYTE_MACHINE_HARNESS_SHARED_DIR}/fingerprint.scm"
      COMMENT "byte-machine: fingerprint manifest ${manifest_key} (first needed by ${name})"
      VERBATIM)

    add_custom_target("byte_machine_fingerprint_${manifest_key}"
                      DEPENDS "${expect_file}")
    if(NOT TARGET byte_machine_fingerprints)
      add_custom_target(byte_machine_fingerprints ALL)
    endif()
    add_dependencies(byte_machine_fingerprints
                     "byte_machine_fingerprint_${manifest_key}")
  endif()

  set(${out_var} "${expect_file}" PARENT_SCOPE)
endfunction()

# A deliberately wrong expectation, so the provenance check is proved to fire by
# a registered lane rather than by editing a build artifact during a mutation
# gate. It is not a fingerprint of anything and cannot become one: every real
# value is lowercase hex, so no manifest can ever produce this text.
function(byte_machine_wrong_fingerprint name out_var)
  set(expect_file "${BYTE_MACHINE_FINGERPRINT_DIR}/${name}.wrong")
  file(MAKE_DIRECTORY "${BYTE_MACHINE_FINGERPRINT_DIR}")
  file(WRITE "${expect_file}" "not-a-fingerprint")
  set(${out_var} "${expect_file}" PARENT_SCOPE)
endfunction()
```

- [ ] **Step 4: Prove the function runs and produces the file**

Add this temporary call directly after the function definitions:

```cmake
byte_machine_expected_fingerprint(scratch-probe _bm_probe_file
  "${BYTE_MACHINE_HARNESS_SHARED_DIR}/harness-runner.scm"
  "${BYTE_MACHINE_SRC_COMMON_DIR}/placeholder.scm"
  "${BYTE_MACHINE_SRC_COMMON_DIR}/placeholder-consumer.scm")
message(STATUS "byte-machine: probe expectation at ${_bm_probe_file}")
```

Then:

```bash
make build && cat $(ls build/dev/fingerprints/*.fingerprint | head -1); echo
```

Expected: the same value Step 2 printed, with no trailing newline (the `echo` supplies the line break). Compare against what you actually observed in Step 2, not against any literal in this plan or in the design spec — both were measured before `harness-runner.scm` grew the provenance code, and Step 2's own note says why.

- [ ] **Step 5: Remove the temporary probe**

Delete the `byte_machine_expected_fingerprint(scratch-probe ...)` call and its `message(STATUS ...)` line added in Step 4. Real callers arrive in Task 5.

```bash
make build
```

Expected: configures and builds clean, with no `probe expectation` line.

- [ ] **Step 6: Commit**

```bash
git add test/support/launchers/fingerprint-manifest.ss test/CMakeLists.txt && git commit -m "feat: compute a manifest's expected fingerprint at build time"
```

---

## Task 4: The provenance decision, as a pure function

**Files:**
- Modify: `test/support/harness/shared/harness-runner.scm`
- Modify: `test/support/harness/chez/byte-machine/test/harness.sls`
- Modify: `test/support/harness/gambit/byte-machine/test/harness.sld`
- Test: `test/support/harness/self/harness-self-tests.scm`

**Interfaces:**
- Consumes: nothing new.
- Produces: `harness-bytes->string` (bytevector → string, ASCII, outer whitespace trimmed), and `harness-provenance-diagnosis` (expected-or-`#f`, computed → `#f` when they agree, else a diagnostic string).

Split for the reason `harness-empty-selection-diagnosis` is split, and the split is not ceremony: a run that cannot verify itself cannot assert anything about itself from the inside, so the rule has to be testable as a function of two values.

- [ ] **Step 1: Write the failing test**

Append a new group to `test/support/harness/self/harness-self-tests.scm`, after the `harness-group "fingerprint"` form:

```scheme
;; --- provenance, as a decision ---------------------------------------------
;;
;; The shell around this exits the process, so nothing inside a suite can
;; observe it. The rule itself is two values in and a diagnostic or #f out, and
;; that part is checkable here.

(harness-group "provenance"
  (lambda ()

    (harness-case "agreement is not a diagnosis"
      (lambda ()
        (check "identical values agree"
               (not (harness-provenance-diagnosis "abc123" "abc123")))))

    (harness-case "a mismatch names both values"
      (lambda ()
        (let ((d (harness-provenance-diagnosis "abc123" "def456")))
          (check "there is a diagnosis" (if d #t #f))
          (check "it names the expectation" (harness-string-contains? d "abc123"))
          (check "it names what was computed" (harness-string-contains? d "def456")))))

    (harness-case "a missing expectation is its own diagnosis"
      (lambda ()
        (let ((d (harness-provenance-diagnosis #f "abc123")))
          (check "there is a diagnosis" (if d #t #f))
          (check "it does not claim a mismatch"
                 (not (harness-string-contains? d "mismatch"))))))

    ;; Whitespace is trimmed at the ends only. A reader that also collapsed
    ;; interior space would make "dead beef" compare equal to "deadbeef", which
    ;; is the sort of leniency that turns a corrupted expectation into a passing
    ;; comparison.
    (harness-case "the expectation file's outer whitespace is trimmed"
      (lambda ()
        (check-equal "trailing newline"
                     (harness-bytes->string (harness-bytes 4 '(97 98 99 10)))
                     "abc")
        (check-equal "leading and trailing spaces"
                     (harness-bytes->string (harness-bytes 5 '(32 97 98 99 32)))
                     "abc")
        (check-equal "empty" (harness-bytes->string (harness-bytes 0 '())) "")
        (check-equal "interior space is kept"
                     (harness-bytes->string (harness-bytes 7 '(100 101 97 100 32 98 102)))
                     "dead bf")))))
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
make dev
```

Expected: both self-tests lanes FAIL with `variable harness-provenance-diagnosis is not bound`.

- [ ] **Step 3: Implement the two pure helpers**

In `test/support/harness/shared/harness-runner.scm`, add both to the "Pure helpers" section, directly after `harness-normalize-filter`:

```scheme
;; Decode a bytevector as ASCII, trimming whitespace at the ends only. The
;; expectation file is written without a trailing newline, but an editor, a
;; shell redirect, or a future writer may add one, and a comparison that failed
;; on a newline would be a provenance failure reported for the wrong reason.
;;
;; Interior whitespace is deliberately kept. Collapsing it would make
;; "dead beef" compare equal to "deadbeef" -- leniency that turns a corrupted
;; expectation into a passing comparison, which is the one outcome this whole
;; mechanism exists to prevent.
(define (harness-whitespace-byte? b)
  (or (= b 32) (= b 9) (= b 10) (= b 13)))

(define (harness-bytes->string bv)
  (let ((n (bytevector-length bv)))
    (let find-start ((start 0))
      (cond
        ((= start n) "")
        ((harness-whitespace-byte? (bytevector-u8-ref bv start))
         (find-start (+ start 1)))
        (else
         (let find-end ((end n))
           (if (harness-whitespace-byte? (bytevector-u8-ref bv (- end 1)))
               (find-end (- end 1))
               (let loop ((i start) (acc (list)))
                 (if (= i end)
                     (list->string (reverse acc))
                     (loop (+ i 1)
                           (cons (integer->char (bytevector-u8-ref bv i))
                                 acc)))))))))))

;; The provenance rule, as a function of two values. `expected` is #f when the
;; build supplied nothing at all, which is a different defect from a mismatch:
;; one means the lane ran text nobody measured, the other means it ran the wrong
;; text. Reporting them the same way would send a reader to the wrong file.
(define (harness-provenance-diagnosis expected computed)
  (cond
    ((not expected)
     (string-append
      "no expectation was supplied, so nothing can say whether this run "
      "executed the text it was supposed to. This run computed " computed "."))
    ((string=? expected computed) #f)
    (else
     (string-append
      "fingerprint mismatch: the build expected " expected
      " but this run computed " computed
      ". Either this lane executed different text from the one the build "
      "measured, or it is running a stale artifact."))))
```

- [ ] **Step 4: Export both from both adapters**

In `test/support/harness/chez/byte-machine/test/harness.sls` and in `test/support/harness/gambit/byte-machine/test/harness.sld`, extend the fingerprint export block added in Task 1 so it reads identically in both files:

```scheme
    ;; content fingerprint and provenance
    harness-fingerprint-bytevector harness-fingerprint-combine
    harness-fingerprint->string harness-fingerprint-file
    harness-bytes->string harness-provenance-diagnosis
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
make test
```

Expected: 40/40 pass.

- [ ] **Step 6: Commit**

```bash
git add test/support/harness && git commit -m "feat: the provenance rule as a function of two values"
```

---

## Task 5: The check, every manifest, and the lanes that prove it fires

**Files:**
- Modify: `test/support/harness/shared/harness-runner.scm`
- Modify: `test/support/harness/chez/byte-machine/test/harness.sls`
- Modify: `test/support/harness/gambit/byte-machine/test/harness.sld`
- Modify: `test/support/harness/self/harness-bootstrap.scm`
- Modify: `cmake/ByteMachineSchemeLane.cmake`
- Modify: `test/support/cmake/ByteMachineSchemeLaneSpec.cmake`
- Modify: `test/CMakeLists.txt`

**Interfaces:**
- Consumes: `harness-provenance-diagnosis`, `harness-bytes->string`, `harness-fingerprint-file`, `harness-fingerprint-combine`, `harness-fingerprint->string`, `harness-split`, `adapter-file-bytes`, `adapter-exit`, `adapter-environment-variable`; `byte_machine_expected_fingerprint` and `byte_machine_wrong_fingerprint` from Task 3.
- Produces: `harness-verify-provenance!` (no arguments; returns normally or exits 3). `byte_machine_add_scheme_lane` gains `SHARED_BODIES <path>...` — **required**, like `TIMEOUT` — and the `WRONG_FINGERPRINT` option. The suite ends at 44 tests.

This task's first registered lane is the slice's central failing test: nothing in this tree has ever produced status 3. The task is deliberately one unit so the tree is never committed red — the check goes live and every manifest arrives together.

**The one decision this task must get right.** An unset or empty `BYTE_MACHINE_FINGERPRINT_FILES` means *"this process was not started by a lane registration"*, and provenance is **skipped**, not refused. Refusing is unimplementable: `byte_machine_mutation_run` requires every spec to pass unmutated on the staged tree, and `byte_machine_mutation_run_spec` runs verify commands through `execute_process` with no environment at all, so a refusal fails all 27 existing mutation passes at their baseline before a single mutation runs. Nothing is lost, because `SHARED_BODIES` being a required argument already makes an unprovenanced registered lane impossible one layer up. See design spec §6.2 and decision V13.

- [ ] **Step 1: Register the failing lane**

At the end of `test/CMakeLists.txt`, add:

```cmake
# --- Provenance ------------------------------------------------------------
#
# Every lane above checks the fingerprint of the text it ran against the value
# the build computed. These prove that check can fail. Without them the
# mechanism would be a claim: protium recorded two occasions where two of its
# lanes printed different digests for text both said they ran, and the suite
# stayed green, because nothing read the values back.
#
# Status 3 is what makes them falsifiable. Six lanes in this tree legitimately
# expect 1 or 2, so a provenance failure sharing either status would be
# indistinguishable from those fixtures' own expected outcomes.
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.provenance.chez.source
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.chez.sps"
  SHARED_BODIES ${BYTE_MACHINE_HARNESS_MANIFEST}
                "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.scm"
  WRONG_FINGERPRINT
  EXPECT_EXIT 3
  TIMEOUT 120
  LABELS expected-red)
```

- [ ] **Step 2: Run it to verify configuration fails**

```bash
make build 2>&1 | tail -20
```

Expected: configuration FAILS with `byte-machine: unexpected arguments to byte_machine_add_scheme_lane: SHARED_BODIES;...;WRONG_FINGERPRINT`. Neither the arguments nor `BYTE_MACHINE_HARNESS_MANIFEST` exist yet.

- [ ] **Step 3: Teach the lane module the two new arguments, with `SHARED_BODIES` required**

In `cmake/ByteMachineSchemeLane.cmake`, change the `cmake_parse_arguments` call in `byte_machine_add_scheme_lane` from:

```cmake
  cmake_parse_arguments(PARSE_ARGV 0 arg ""
    "NAME;BACKEND;PROGRAM;TIMEOUT;EXPECT_EXIT;WORKING_DIRECTORY" "LABELS;ENVIRONMENT")
```

to:

```cmake
  cmake_parse_arguments(PARSE_ARGV 0 arg "WRONG_FINGERPRINT"
    "NAME;BACKEND;PROGRAM;TIMEOUT;EXPECT_EXIT;WORKING_DIRECTORY"
    "LABELS;ENVIRONMENT;SHARED_BODIES")
```

Change the required-argument loop from:

```cmake
  foreach(required NAME BACKEND PROGRAM TIMEOUT)
```

to:

```cmake
  # SHARED_BODIES is required, not optional. The property worth having is not
  # "the lanes have provenance" but "a lane cannot be added without it" -- and
  # this configure-time check is the whole of that guarantee, because the
  # harness skips provenance rather than refusing when no manifest reaches it.
  # It matters little here, where every lane is a source lane, and a great deal
  # in slices 5b and 5c, where a lane registered without provenance is exactly
  # the lane that can silently fall back to source.
  foreach(required NAME BACKEND PROGRAM TIMEOUT SHARED_BODIES)
```

Immediately after the existing `if(NOT EXISTS "${arg_PROGRAM}")` block, add:

```cmake
  # A manifest entry that does not exist would be a provenance failure at run
  # time, reported by the harness as though the build tree were incomplete. It
  # is a registration mistake, and it is cheaper to say so here.
  foreach(body IN LISTS arg_SHARED_BODIES)
    if(NOT EXISTS "${body}")
      message(FATAL_ERROR
        "byte-machine: '${arg_NAME}' names a shared body that does not exist: "
        "${body}.")
    endif()
  endforeach()
```

After the `set(environment ...)` block from Task 2, add:

```cmake
  # The manifest, and the expectation it must agree with. The separator is `|`
  # rather than a path separator: `:` and `;` differ between platforms, and `|`
  # is illegal in a Windows path, so it cannot occur inside a member.
  #
  # Gated on a discovered Chez, because byte_machine_expected_fingerprint runs
  # the expectation launcher under Chez. A host with Gambit but no Chez reaches
  # this line on every Gambit lane -- that lane's own runtime was found, so it
  # did not take the no-runtime return above -- and would otherwise build a
  # custom command whose executable is the empty string. Neither variable is set
  # in that case, so the harness skips provenance exactly as it does for any
  # process a lane registration did not start. The lane still runs and still
  # proves what it proved before this slice; it just carries no fingerprint,
  # which is the honest outcome when the build cannot compute one.
  if(BYTE_MACHINE_CHEZ_EXECUTABLE)
    string(JOIN "|" fingerprint_files ${arg_SHARED_BODIES})
    if(arg_WRONG_FINGERPRINT)
      byte_machine_wrong_fingerprint("${arg_NAME}" expect_file)
    else()
      byte_machine_expected_fingerprint("${arg_NAME}" expect_file
                                        ${arg_SHARED_BODIES})
    endif()
    list(APPEND environment
      "BYTE_MACHINE_FINGERPRINT_FILES=${fingerprint_files}"
      "BYTE_MACHINE_EXPECT_FINGERPRINT_FILE=${expect_file}")
  endif()
```

Note the consequence for the four provenance lanes registered later in this task: each expects exit 3, and each would exit 0 on a Chez-less host, since with no expectation there is nothing to disagree with. They are Chez lanes and Gambit lanes respectively, so three of the four are already skipped when Chez is absent — but `byte-machine.harness.provenance.gambit.source` is not. Register that one inside an `if(BYTE_MACHINE_CHEZ_EXECUTABLE)` guard, with a comment saying why a Gambit lane depends on a Chez being present.

`byte_machine_expected_fingerprint` and `byte_machine_wrong_fingerprint` are defined in `test/CMakeLists.txt` (Task 3), which is processed before any lane is registered, so both are in scope at call time.

- [ ] **Step 4: Give every existing lane a manifest**

In `test/CMakeLists.txt`, define the shared manifest once, immediately after the `# --- Source tree paths ---` block:

```cmake
# The bodies every harness lane executes. Named once: a lane that listed them
# itself would drift, and a manifest that drifts is one that quietly stops
# describing the run.
set(BYTE_MACHINE_HARNESS_MANIFEST
    "${BYTE_MACHINE_HARNESS_SHARED_DIR}/fingerprint.scm"
    "${BYTE_MACHINE_HARNESS_SHARED_DIR}/harness-runner.scm")
```

Then add `SHARED_BODIES` to every `byte_machine_add_scheme_lane` call already in the file — each lane's manifest is the harness manifest plus the shared body its program includes:

| Lane | `SHARED_BODIES` |
| --- | --- |
| `harness.failing-body.*` | `${BYTE_MACHINE_HARNESS_MANIFEST}` `${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-failing.scm` |
| `harness.bootstrap.*` | `${BYTE_MACHINE_HARNESS_MANIFEST}` `${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-bootstrap.scm` |
| `harness.self.*` and `harness.verbose.*` | `${BYTE_MACHINE_HARNESS_MANIFEST}` `${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.scm` |
| `harness.duplicate-case.*` | `${BYTE_MACHINE_HARNESS_MANIFEST}` `${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-duplicate-case.scm` |
| `harness.empty-selection.*` | `${BYTE_MACHINE_HARNESS_MANIFEST}` `${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-empty-selection.scm` |
| `portability.placeholder-cwd-*.*` | `${BYTE_MACHINE_HARNESS_MANIFEST}` `${BYTE_MACHINE_SRC_COMMON_DIR}/placeholder.scm` `${BYTE_MACHINE_TEST_COMMON_DIR}/placeholder-tests.scm` |
| `portability.placeholder-identity.*` | `${BYTE_MACHINE_HARNESS_MANIFEST}` `${BYTE_MACHINE_SRC_COMMON_DIR}/placeholder.scm` `${BYTE_MACHINE_SRC_COMMON_DIR}/placeholder-consumer.scm` `${BYTE_MACHINE_TEST_COMMON_DIR}/placeholder-identity-tests.scm` |

For example, the failing-body lane becomes:

```cmake
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.failing-body.chez.source
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-failing.chez.sps"
  SHARED_BODIES ${BYTE_MACHINE_HARNESS_MANIFEST}
                "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-failing.scm"
  EXPECT_EXIT 1
  TIMEOUT 120
  LABELS expected-red)
```

The three `placeholder-cwd-*` lanes are registered inside a `foreach(cwd_case ...)` loop; add `SHARED_BODIES` once inside the loop body, to both the Chez and the Gambit registration.

- [ ] **Step 6: Run it again to verify the lane now fails for the right reason**

```bash
make build && ctest --test-dir build/dev -R 'provenance' --output-on-failure 2>&1 | tail -20
```

Expected: configuration succeeds and the lane FAILS, reporting `exit status 0, expected 3`. The harness does not check provenance yet, so the self-tests pass and the process exits 0. Every other lane still passes.

- [ ] **Step 7: Implement the check**

In `test/support/harness/shared/harness-runner.scm`, add to the "Suite lifecycle" section, immediately before `harness-begin`:

```scheme
;; ---------------------------------------------------------------------------
;; Provenance
;; ---------------------------------------------------------------------------
;;
;; A provenance failure ends the run there and then, rather than recording an
;; error and continuing. Recording is not enough, for the reason status 3 exists
;; at all: a body that goes on to hang satisfies a timeout expectation whether
;; or not an error was recorded first, so a recorded-and-continued failure is
;; invisible to every lane whose expected outcome does not depend on reaching
;; the summary. Beyond that, continuing is pointless -- a run that cannot show
;; it is executing the intended text says nothing meaningful afterwards.

(define (harness-provenance-failure! detail)
  (harness-say-always
   (string-append "byte-machine-harness: PROVENANCE-ERROR " detail))
  (harness-say-always
   (string-append
    "byte-machine-harness: summary suite=" harness-suite-name
    " runtime=" (adapter-runtime-name)
    " mode=" (adapter-execution-mode)
    " os=" (adapter-os)
    " architecture=" (adapter-architecture)
    " cases=0 status=" (number->string harness-status-provenance)))
  (adapter-flush-output)
  (adapter-exit harness-status-provenance))

;; A body named in the manifest that cannot be read is a provenance failure, not
;; an I/O accident to propagate. Without this the raise escapes the runner and
;; takes the process out through a status outside this file's four-value
;; vocabulary, with no summary line and a message about a file handle -- which
;; the exact-status helper would then report as an out-of-vocabulary status, a
;; true statement about the wrong thing.
(define (harness-fingerprint-file-checked path)
  (let ((h (guard (e (#t #f)) (harness-fingerprint-file path))))
    (if h
        h
        (harness-provenance-failure!
         (string-append
          "cannot read " path
          ", which this run is supposed to have executed. The build tree is "
          "incomplete; build before running the tests.")))))

;; Returns the expected value as a string, or #f. #f covers both an unset
;; variable and a build that never produced the file; harness-provenance-
;; diagnosis reports either as "no expectation was supplied", since from the
;; run's side they are the same condition.
(define (harness-expected-fingerprint)
  (let ((path (adapter-environment-variable "BYTE_MACHINE_EXPECT_FINGERPRINT_FILE")))
    (if (or (not path) (string=? path ""))
        #f
        (let ((bytes (guard (e (#t #f)) (adapter-file-bytes path))))
          (if bytes (harness-bytes->string bytes) #f)))))

;; Fingerprint each manifest entry, report the values, then check the combined
;; one. Printing alone would not be a check: a digest nothing reads is a claim.
;;
;; AN ABSENT MANIFEST IS NOT A FAILURE
;;
;; An unset or empty BYTE_MACHINE_FINGERPRINT_FILES means this process was not
;; started by a lane registration, and the only things that start a harness
;; program any other way are a developer running one by hand and the Scheme
;; mutation suite. The second is not optional: byte_machine_mutation_run
;; requires every spec to exit 0 unmutated on the staged tree, and it runs its
;; verify commands with no environment at all, so refusing here would fail all
;; twenty-seven mutation passes at their baseline before a single mutation ran.
;;
;; Nothing is lost by skipping. SHARED_BODIES is a required argument of
;; byte_machine_add_scheme_lane, so a registered lane always has a manifest and
;; there is no reachable path by which a real lane silently loses provenance.
;; The guarantee lives at configure time, where it cannot be forged; a run-time
;; refusal would add only a rule this repository's own tooling cannot satisfy.
(define (harness-verify-provenance!)
  (let ((raw (adapter-environment-variable "BYTE_MACHINE_FINGERPRINT_FILES")))
    (if (or (not raw) (string=? raw ""))
        #t
        (let loop ((rest (harness-split raw #\|)) (acc '()))
          (if (null? rest)
              (let ((combined (harness-fingerprint->string
                               (harness-fingerprint-combine (reverse acc)))))
                (harness-say-always
                 (string-append "byte-machine-harness: fingerprint combined="
                                combined))
                (let ((d (harness-provenance-diagnosis
                          (harness-expected-fingerprint) combined)))
                  (if d
                      (harness-provenance-failure! d)
                      (harness-say-always
                       "byte-machine-harness: fingerprint verified against the build manifest"))))
              (let ((h (harness-fingerprint-file-checked (car rest))))
                (harness-say-always
                 (string-append "byte-machine-harness: fingerprint "
                                (car rest) "="
                                (harness-fingerprint->string h)))
                (loop (cdr rest) (cons h acc))))))))
```

Then call it from `harness-begin`. Change:

```scheme
(define (harness-begin suite-name)
  (set! harness-suite-name suite-name)
  (harness-clear-state!)
```

to:

```scheme
(define (harness-begin suite-name)
  (set! harness-suite-name suite-name)
  ;; Before anything else a suite might report. A run that cannot show it
  ;; executed the intended text must not first print a banner implying it did.
  (harness-verify-provenance!)
  (harness-clear-state!)
```

- [ ] **Step 8: Export the entry point from both adapters**

In both adapters, extend the block from Task 4 so the two read identically:

```scheme
    ;; content fingerprint and provenance
    harness-fingerprint-bytevector harness-fingerprint-combine
    harness-fingerprint->string harness-fingerprint-file
    harness-bytes->string harness-provenance-diagnosis
    harness-verify-provenance!
```

- [ ] **Step 9: Give the bootstrap body its own call**

The bootstrap deliberately does not call `harness-begin`, so a check living only there would leave both bootstrap lanes unchecked (V11). In `test/support/harness/self/harness-bootstrap.scm`, immediately after the `bootstrap-assert` definition and before the first `bootstrap-assert` call, add:

```scheme
;; The one runner facility this body uses before judging any of them. It is here
;; because the bootstrap does not call harness-begin -- the suite lifecycle is
;; among the things it is not allowed to trust -- and a provenance check that
;; lived only in harness-begin would leave these two lanes the only ones in the
;; tree running text nothing verified. It either returns or ends the process, so
;; it cannot report a false negative into the counter below.
(harness-verify-provenance!)
```

- [ ] **Step 10: Run the tests**

```bash
make test
```

Expected: 41/41 pass. The provenance lane now exits 3 as it expects, and every other lane prints `fingerprint verified against the build manifest`.

- [ ] **Step 11: Register the three remaining provenance lanes**

Append to the provenance section of `test/CMakeLists.txt`:

```cmake
# The Gambit half. This one is not a duplicate of the Chez lane: the path it
# exercises reads the expectation through adapter-file-bytes, which is
# per-runtime code, and exits through adapter-exit. The two refusals below run
# on Chez alone under slice 2's rule S6 -- they are decisions in the shared
# runner body, identical text on both runtimes, and this pair already
# establishes that both reach it.
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.provenance.gambit.source
  BACKEND gambit
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.gambit.scm"
  SHARED_BODIES ${BYTE_MACHINE_HARNESS_MANIFEST}
                "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.scm"
  WRONG_FINGERPRINT
  EXPECT_EXIT 3
  TIMEOUT 120
  LABELS expected-red)

# The build never produced this file, and never will: no rule names it as an
# output. That is the "you did not build before running the tests" case, which
# would otherwise escape as a raw I/O condition and a status outside the
# vocabulary.
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.provenance-absent-expectation.chez.source
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.chez.sps"
  SHARED_BODIES ${BYTE_MACHINE_HARNESS_MANIFEST}
                "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.scm"
  EXPECT_EXIT 3
  TIMEOUT 120
  LABELS expected-red
  ENVIRONMENT "BYTE_MACHINE_EXPECT_FINGERPRINT_FILE=${CMAKE_BINARY_DIR}/fingerprints/never-produced.fingerprint")

# A manifest naming a body that is not there. What fails is reading the text,
# before any comparison happens.
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.provenance-missing-body.chez.source
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.chez.sps"
  SHARED_BODIES ${BYTE_MACHINE_HARNESS_MANIFEST}
                "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.scm"
  EXPECT_EXIT 3
  TIMEOUT 120
  LABELS expected-red
  ENVIRONMENT "BYTE_MACHINE_FINGERPRINT_FILES=${CMAKE_BINARY_DIR}/fingerprints/no-such-body.scm")
```

There is deliberately no lane asserting that an unset manifest exits 3. Under this design an unset manifest skips the check, and a lane asserting that a skip skips would pass whether the code checked anything or not.

- [ ] **Step 12: Add the lane-module specification cases**

In `test/support/cmake/ByteMachineSchemeLaneSpec.cmake`, add to the `BYTE_MACHINE_SPEC_CASE` dispatch chain, following the shape of the existing `lane-rejects-unparsed-arguments` case:

```cmake
  elseif(c STREQUAL "lane-requires-shared-bodies")
    byte_machine_add_scheme_lane(
      NAME byte-machine.harness.example.chez.source
      BACKEND chez
      PROGRAM "${SPEC_SELF}"
      TIMEOUT 10)
  elseif(c STREQUAL "lane-rejects-missing-shared-body")
    byte_machine_add_scheme_lane(
      NAME byte-machine.harness.example.chez.source
      BACKEND chez
      PROGRAM "${SPEC_SELF}"
      SHARED_BODIES "${SPEC_SELF}" "/nonexistent/body.scm"
      TIMEOUT 10)
```

And register both with the file's existing rejection-assertion helper, alongside the other such calls:

```cmake
spec_case_must_be_rejected("lane-requires-shared-bodies"
  "SHARED_BODIES is required")
spec_case_must_be_rejected("lane-rejects-missing-shared-body"
  "names a shared body that does not exist")
```

Read the surrounding calls first and match their exact helper name and argument order; the helper is defined in `test/support/cmake/SpecSupport.cmake`. Note that the existing spec cases stub `byte_machine_add_test` and `byte_machine_add_exit_code_test`; `byte_machine_expected_fingerprint` and `byte_machine_wrong_fingerprint` live in `test/CMakeLists.txt` and are not visible under `cmake -P`, so both new cases must be rejected *before* reaching them — which they are, since a missing required argument and a nonexistent body are both refused earlier in the function.

- [ ] **Step 13: Run everything**

```bash
make test && ctest --preset no-scheme --output-on-failure 2>&1 | tail -5
```

Expected: 44/44 on the dev preset, 10/10 on `no-scheme`.

- [ ] **Step 14: Confirm each provenance lane fails for its own reason**

```bash
ctest --test-dir build/dev -R 'provenance' -V 2>&1 | grep -E 'PROVENANCE-ERROR|Test #|Passed|Failed'
```

Expected: four lanes, each passing, and three distinct `PROVENANCE-ERROR` messages — `fingerprint mismatch` (twice, once per runtime), `no expectation was supplied`, and `cannot read ... The build tree is incomplete`. Identical messages would mean the lanes are not discriminating what they claim to.

- [ ] **Step 15: Commit**

```bash
git add test/support/harness cmake/ByteMachineSchemeLane.cmake test/support/cmake/ByteMachineSchemeLaneSpec.cmake test/CMakeLists.txt && git commit -m "feat: a run that cannot show it ran the intended text exits 3"
```

---

## Task 6: Mutations

**Files:**
- Modify: `test/support/cmake/SchemeMutationSuite.cmake`

**Interfaces:**
- Consumes: `byte_machine_mutation(FILE <path> SPEC <program> LABEL <text> FIND <text> REPLACE <text> [EXPECT_SURVIVES <reason>] [EXPECT_STATUS <code>] [EXPECT_OUTPUT_MATCHES <regex>])`, `byte_machine_mutation_reset()`, `byte_machine_mutation_run(<source_root> <stage_dir>)`, and the file-scope variable `BYTE_MACHINE_MUTATION_VERIFY_COMMAND`.
- Produces: passes 28–31 and updated counters.

A passing suite is not evidence. Each decision is broken on a staged copy and the owning lane must notice.

- [ ] **Step 1: Add the fingerprint body to the staged directories**

`test/support/harness` is already in `BYTE_MACHINE_MUTATION_STAGE_DIRS`, so `fingerprint.scm` is staged with it. No change needed — confirm by reading the list near the top of the file and checking `test/support/harness` is present.

- [ ] **Step 2: Write passes 28 and 29 — the algorithm, once per runtime**

Append to `test/support/cmake/SchemeMutationSuite.cmake`, at the end of the file but **before** the totals assertion block:

```cmake
# --- Passes 28 and 29: the fingerprint algorithm ----------------------------
#
# Run once per runtime for the reason passes 9 and 10 give: the text is shared,
# but how each runtime reaches it is not, and an adapter that quietly stopped
# including it is exactly an adapter whose runtime never notices the body
# changing.
#
# The self-tests assert measured literals, so any change to seed, multiplier,
# modulus, the +1, or the digit table moves at least one of them.

set(FINGERPRINT test/support/harness/shared/fingerprint.scm)

function(byte_machine_slice5a_algorithm_pass runtime)
  byte_machine_mutation_reset()

  if(runtime STREQUAL "chez")
    set(spec harness-self-tests.chez.sps)
  else()
    set(spec harness-self-tests.gambit.scm)
  endif()

  # Without the +1 a NUL contributes nothing, and the three leading-zero cases
  # collapse into one value. This is the only mutation here that a fixed set of
  # literals could survive if the literals happened not to include a NUL --
  # which is why they do.
  byte_machine_mutation(
    FILE ${FINGERPRINT} SPEC ${spec}
    LABEL "fingerprint on ${runtime}: leading zero bytes stop being significant"
    FIND [[                           (+ (bytevector-u8-ref bv i) 1))]]
    REPLACE [[                           (bytevector-u8-ref bv i))]])

  byte_machine_mutation(
    FILE ${FINGERPRINT} SPEC ${spec}
    LABEL "fingerprint on ${runtime}: the seed changes"
    FIND [[(define harness-fingerprint-seed 14695981039346656)]]
    REPLACE [[(define harness-fingerprint-seed 14695981039346657)]])

  byte_machine_mutation(
    FILE ${FINGERPRINT} SPEC ${spec}
    LABEL "fingerprint on ${runtime}: the multiplier changes"
    FIND [[(define harness-fingerprint-multiplier 1000003)]]
    REPLACE [[(define harness-fingerprint-multiplier 1000033)]])

  byte_machine_mutation(
    FILE ${FINGERPRINT} SPEC ${spec}
    LABEL "fingerprint on ${runtime}: the modulus changes"
    FIND [[(define harness-fingerprint-modulus 2305843009213693951) ; 2^61 - 1]]
    REPLACE [[(define harness-fingerprint-modulus 2305843009213693907)]])

  # Combining becomes a sum, so order stops mattering and the two combine cases
  # collapse to one value.
  byte_machine_mutation(
    FILE ${FINGERPRINT} SPEC ${spec}
    LABEL "fingerprint on ${runtime}: combining stops being order sensitive"
    FIND [[              (modulo (+ (* h harness-fingerprint-multiplier) (+ (car rest) 1))]]
    REPLACE [[              (modulo (+ h (+ (car rest) 1))]])

  byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")
endfunction()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness/chez"
  "--source-dir" "${STAGE_DIR}/test/support/harness/shared"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-self-tests.chez.sps")

byte_machine_slice5a_algorithm_pass("chez")

if(BYTE_MACHINE_GAMBIT_EXECUTABLE)
  set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
    "${BYTE_MACHINE_GAMBIT_EXECUTABLE}"
    "-:search=${STAGE_DIR}/test/support/harness/gambit"
    "-f"
    "${STAGE_DIR}/test/support/harness/self/harness-self-tests.gambit.scm")

  byte_machine_slice5a_algorithm_pass("gambit")
endif()
```

- [ ] **Step 3: Write passes 30 and 31 — the hex table, caught symmetrically**

Append immediately after:

```cmake
# --- Passes 30 and 31: the hex rendering table -------------------------------
#
# MEASURED 2026-08-17, AND SYMMETRIC -- NOT THE ASYMMETRIC OUTCOME A FIRST
# READING OF "fingerprint.scm is also what the build-time expectation loads"
# SUGGESTS.
#
# Neither pass sets a manifest, so provenance is skipped here exactly as it is
# for every other pass but 32 and 33 below: BYTE_MACHINE_FINGERPRINT_FILES is
# unset, harness-verify-provenance! returns #t immediately, and the self-tests
# suite runs its own cases undisturbed. It is the self-tests' own "hex digits
# are lowercase on every runtime" case that actually witnesses this mutation --
# it check-equals fixed literals ("ff", "deadbeef", "0") rather than deriving
# its expectation from fingerprint.scm, so mutating the digit table fails an
# ordinary comparison on both runtimes: both processes exit 1 (the harness's
# own "an assertion failed" status) with a "byte-machine-harness: FAIL " line,
# which is exactly what EXPECT_STATUS and EXPECT_OUTPUT_MATCHES below assert
# and exactly what the real run reports caught for both.
#
# The asymmetric story -- Chez agreeing with a build-time expectation that
# moved with it, Gambit alone catching the divergence -- is not demonstrated
# by any pass in this file, passes 32 and 33 included. Both run Chez only,
# neither wrapped in if(BYTE_MACHINE_GAMBIT_EXECUTABLE), so neither can be
# where "Gambit alone catches it" happens. Both compare against a fixed
# wrong-value fixture rather than a fingerprint recomputed from the mutated
# tree -- pass 32 against a file holding the literal "not-a-fingerprint",
# pass 33 against never-produced.fingerprint, a path this suite never writes
# -- so neither expectation can move with a mutation the way the story
# requires. And harness-hex-digits is the one definition both adapters
# include verbatim: any pass that did compute its expectation via Chez over
# the same staged tree the mutation lands on would have that computation read
# the identical mutated table the runtime under test reads, so the two would
# agree regardless of runtime. Showing the asymmetry needs a provenance-
# wrapped verify command whose expectation is built from an *unmutated* tree
# while the runtime under test sees the mutated one; staging gives every pass
# one tree, already mutated, so no pass here can offer that.
#
# Section 6.1 of the slice-5a design carries the claim instead, in the
# design's own terms: the cross-runtime guarantee rests on the Gambit lane
# because the expectation is a Chez computation -- an argument from how the
# build is wired, not a fact this suite reproves. An earlier draft of this
# comment reassigned the asymmetric outcome to passes 32 and 33 rather than
# dropping it; checked against what those two passes actually mutate and
# compare, that reassignment does not hold either.

set(HEX_MUTATION_FIND [[(define harness-hex-digits "0123456789abcdef")]])
set(HEX_MUTATION_REPLACE [[(define harness-hex-digits "0123456789ABCDEF")]])

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness/chez"
  "--source-dir" "${STAGE_DIR}/test/support/harness/shared"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-self-tests.chez.sps")

byte_machine_mutation(
  FILE ${FINGERPRINT} SPEC harness-self-tests.chez.sps
  LABEL "fingerprint: hex digits become uppercase (Chez)"
  FIND "${HEX_MUTATION_FIND}"
  REPLACE "${HEX_MUTATION_REPLACE}"
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "byte-machine-harness: FAIL ")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

if(BYTE_MACHINE_GAMBIT_EXECUTABLE)
  byte_machine_mutation_reset()

  set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
    "${BYTE_MACHINE_GAMBIT_EXECUTABLE}"
    "-:search=${STAGE_DIR}/test/support/harness/gambit"
    "-f"
    "${STAGE_DIR}/test/support/harness/self/harness-self-tests.gambit.scm")

  byte_machine_mutation(
    FILE ${FINGERPRINT} SPEC harness-self-tests.gambit.scm
    LABEL "fingerprint: hex digits become uppercase (Gambit)"
    FIND "${HEX_MUTATION_FIND}"
    REPLACE "${HEX_MUTATION_REPLACE}"
    EXPECT_STATUS 1
    EXPECT_OUTPUT_MATCHES "byte-machine-harness: FAIL ")

  byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")
endif()
```

- [ ] **Step 4: Write passes 32 and 33 — the provenance check itself**

Every other pass in this file runs with no manifest, so provenance is skipped and none of them can witness it. These two are the exception: each sets a manifest and an expectation through `cmake -E env`, and runs the lane through the exact-status helper so that **exit 3 is what a healthy check scores** and the baseline is green. That is the same shape passes 5 and 6 use for the launcher's refusals, and for the same reason — `byte_machine_mutation_run` requires a green baseline, and a lane that proves a refusal is red by construction until something inverts it.

Note `EXPECT_STATUS 0` is impossible here and anywhere else: `byte_machine_mutation_verdict` returns `not-caught` for `rc EQUAL 0` before it consults any expectation. A mutation is caught by making the *wrapper* exit nonzero, which happens when the inner lane stops exiting 3.

Append after pass 31:

```cmake
# --- Passes 32 and 33: the provenance check itself ---------------------------
#
# Wrapped in the exact-status helper so exit 3 -- the refusal -- is the green
# baseline, exactly as passes 5 and 6 do for the launcher. A mutation that makes
# the check more permissive drops the inner status to 0, the wrapper reports
# nonzero, and the mutation is caught.
#
# THE MANIFEST NAMES ONE BODY ON PURPOSE
#
# BYTE_MACHINE_EXPECT_COMMAND packs its argument vector with `|`, which is also
# the manifest separator, so a two-element manifest would be unpacked as two
# arguments. One body is enough: these passes test whether the check runs and is
# consulted, not how values combine, which passes 28 and 29 cover.

set(RUNNER_BODY test/support/harness/shared/harness-runner.scm)

set(WRONG_FP_FILE "${WORK_DIR}/wrong.fingerprint")
file(WRITE "${WRONG_FP_FILE}" "not-a-fingerprint")

byte_machine_mutation_reset()

string(JOIN "|" PROVENANCE_MISMATCH_COMMAND
  "${CMAKE_COMMAND}" "-E" "env"
  "BYTE_MACHINE_FINGERPRINT_FILES=${STAGE_DIR}/test/support/harness/shared/fingerprint.scm"
  "BYTE_MACHINE_EXPECT_FINGERPRINT_FILE=${WRONG_FP_FILE}"
  "--"
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness/chez"
  "--source-dir" "${STAGE_DIR}/test/support/harness/shared"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-self-tests.chez.sps")

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${CMAKE_COMMAND}"
  "-DBYTE_MACHINE_EXPECT_EXIT=3"
  "-DBYTE_MACHINE_EXPECT_COMMAND=${PROVENANCE_MISMATCH_COMMAND}"
  -P "${STAGE_DIR}/cmake/ByteMachineExpectExit.cmake")

byte_machine_mutation(
  FILE ${RUNNER_BODY} SPEC byte-machine.harness.provenance.chez.source
  LABEL "provenance: the comparison always reports agreement"
  FIND [[    ((string=? expected computed) #f)]]
  REPLACE [[    (#t #f)]])

byte_machine_mutation(
  FILE ${RUNNER_BODY} SPEC byte-machine.harness.provenance.chez.source
  LABEL "provenance: harness-begin stops checking at all"
  FIND [[  (harness-verify-provenance!)
  (harness-clear-state!)]]
  REPLACE [[  (harness-clear-state!)]])

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# Pass 33: the same wrapper, but the expectation file does not exist, so the
# refusal under test is the missing-expectation branch rather than the
# comparison. Its mutation removes the branch that treats an absent expectation
# as a diagnosis; without it the run compares nothing and proceeds.
byte_machine_mutation_reset()

string(JOIN "|" PROVENANCE_ABSENT_COMMAND
  "${CMAKE_COMMAND}" "-E" "env"
  "BYTE_MACHINE_FINGERPRINT_FILES=${STAGE_DIR}/test/support/harness/shared/fingerprint.scm"
  "BYTE_MACHINE_EXPECT_FINGERPRINT_FILE=${WORK_DIR}/never-produced.fingerprint"
  "--"
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness/chez"
  "--source-dir" "${STAGE_DIR}/test/support/harness/shared"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-self-tests.chez.sps")

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${CMAKE_COMMAND}"
  "-DBYTE_MACHINE_EXPECT_EXIT=3"
  "-DBYTE_MACHINE_EXPECT_COMMAND=${PROVENANCE_ABSENT_COMMAND}"
  -P "${STAGE_DIR}/cmake/ByteMachineExpectExit.cmake")

byte_machine_mutation(
  FILE ${RUNNER_BODY} SPEC byte-machine.harness.provenance-absent-expectation.chez.source
  LABEL "provenance: a missing expectation stops being a diagnosis"
  FIND [[    ((not expected)]]
  REPLACE [[    ((and #f expected)]])

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")
```

**A stated blind spot.** The third refusal — a manifest naming an unreadable body — has no mutation here. Making it witnessable would need an expectation crafted to equal what the mutant computes after the read fails, which is a value with no meaning outside that mutation. It is covered by its registered lane, `byte-machine.harness.provenance-missing-body.chez.source`, and this is recorded rather than papered over with an `EXPECT_SURVIVES`, which AGENTS.md reserves for the genuinely unwitnessable.

- [ ] **Step 5: Add `adapter-file-bytes` to the two existing export-list passes**

The adapter export-list passes drop one named export at a time with an explicit `FIND`/`REPLACE`, so `adapter-file-bytes` needs its own mutation in each rather than a pass of its own. It is load-bearing — the self-tests call it directly (Task 2), which is why it is not another entry in the declared-survivor group alongside `harness-summary`.

In the `# --- The Chez adapter's export list ---` block, add before its `byte_machine_mutation_run` call:

```cmake
# Load-bearing, unlike the three names in the survivor below: the self-tests
# call adapter-file-bytes directly rather than only through
# harness-fingerprint-file, precisely so that dropping its export is visible.
byte_machine_mutation(
  FILE ${CHEZ_ADAPTER} SPEC harness-self-tests.chez.sps
  LABEL "chez adapter: adapter-file-bytes is dropped from the export list"
  FIND [[    adapter-value->string adapter-describe-condition adapter-file-bytes]]
  REPLACE [[    adapter-value->string adapter-describe-condition]])
```

In the `# --- Second pass: the Gambit adapter's export list ---` block, add before its `byte_machine_mutation_run` call:

```cmake
byte_machine_mutation(
  FILE test/support/harness/gambit/byte-machine/test/harness.sld
  SPEC harness-self-tests.gambit.scm
  LABEL "gambit adapter: adapter-file-bytes is dropped from the export list"
  FIND [[    adapter-value->string adapter-describe-condition adapter-file-bytes]]
  REPLACE [[    adapter-value->string adapter-describe-condition]])
```

Both `FIND` strings must match the export lines exactly as Task 2 Steps 4 and 5 wrote them. `byte_machine_mutation` fails loudly on a `FIND` that matches nothing, so a mismatch is reported rather than silently skipped.

- [ ] **Step 6: Update the counters**

Six new passes and seventeen new mutations. Counting them, so a reviewer can check the literals below without running anything:

| Added | Passes | Mutations | Gambit-gated |
| --- | --- | --- | --- |
| pass 28, algorithm on Chez | 1 | 5 | no |
| pass 29, algorithm on Gambit | 1 | 5 | yes |
| pass 30, hex on Chez | 1 | 1 | no |
| pass 31, hex on Gambit | 1 | 1 | yes |
| pass 32, provenance comparison and call site | 1 | 2 | no |
| pass 33, provenance missing expectation | 1 | 1 | no |
| `adapter-file-bytes` export, into existing pass 1 | 0 | 1 | no |
| `adapter-file-bytes` export, into existing pass 2 | 0 | 1 | yes |
| **total** | **6** | **17** | **2 passes, 7 mutations** |

So `27 + 6 = 33` passes and `64 + 17 = 81` mutations, of which `4 + 2 = 6` passes and `11 + 7 = 18` mutations are Gambit-gated. Without Gambit the derived pair is 27 passes and 63 mutations.

Near the top of `test/support/cmake/SchemeMutationSuite.cmake`, change:

```cmake
set(EXPECTED_PASSES_WITH_GAMBIT 27)
set(EXPECTED_MUTATIONS_WITH_GAMBIT 64)
```

to:

```cmake
set(EXPECTED_PASSES_WITH_GAMBIT 33)
set(EXPECTED_MUTATIONS_WITH_GAMBIT 81)
```

and:

```cmake
set(GAMBIT_ONLY_PASSES 4)
set(GAMBIT_ONLY_MUTATIONS 11)
```

to:

```cmake
set(GAMBIT_ONLY_PASSES 6)
set(GAMBIT_ONLY_MUTATIONS 18)
```

- [ ] **Step 7: Run the mutation suite**

```bash
ctest --test-dir build/dev -R 'scheme-mutation' --output-on-failure 2>&1 | tail -25
```

Expected: PASS, with the suite's own totals check accepting 33 passes and 81 mutations. If it reports different numbers, the run is right and Step 6's table is wrong — replace the literals with what the run reports and correct Step 6's table to match. Counters are confirmed against a real run, never inherited from a plan; slice 4 followed the same rule and its design document says so explicitly.

Also update the prose block at the top of the file: it opens with `TWENTY-SEVEN PASSES WHEN GAMBIT IS DISCOVERED` and describes each pass. Update the heading and add a paragraph for passes 28–33, matching the style of the existing per-pass paragraphs. The file's own comment says the declared numbers exist so a reader checks one number by eye, not two that can disagree.

- [ ] **Step 8: Verify the hex mutation is caught symmetrically**

```bash
ctest --test-dir build/dev -R 'scheme-mutation' -V 2>&1 | grep -i 'uppercase'
```

Expected: both the Chez and the Gambit uppercase mutations reported as caught, each with status 1 and a `FAIL ` line — the self-tests' own lowercase case catches it on both. If the Chez one reports *survived*, the self-tests' hex case has been weakened or removed; restore it rather than relaxing the expectation.

- [ ] **Step 9: Run everything**

```bash
make test && ctest --preset no-scheme --output-on-failure 2>&1 | tail -5
```

Expected: 44/44 and 10/10.

- [ ] **Step 10: Commit**

```bash
git add test/support/cmake/SchemeMutationSuite.cmake && git commit -m "test: break every fingerprint and provenance decision and require a lane to notice"
```

---

## Task 7: The record

**Files:**
- Create: `.decisions/0004-content-fingerprint-and-provenance.md`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Read the existing decision records for shape**

```bash
cat .decisions/README.md .decisions/0003-cross-library-identity.md
```

Match their structure: context, the decision, the measurements behind it, consequences, and what would reopen it.

- [ ] **Step 2: Write the decision record**

Create `.decisions/0004-content-fingerprint-and-provenance.md`. It must state, at minimum:

- The measured radix divergence — `(number->string 255 16)` is `FF` on Chez 10.4.1 and `ff` on Gambit 4.9.8 on Darwin 25.5.0 arm64, measured 2026-08-17 — and that it forces the explicit digit table.
- The cross-runtime agreement measurement, **re-taken against the shipped artifact rather than copied from the design spec**. AGENTS.md requires this, and the design spec's §2.0 says explicitly that its combined value is a pre-slice reading of a body this slice edits. Take the new one from a real lane — run `ctest --test-dir build/dev -R 'placeholder-identity' -V` on each runtime and read the `fingerprint combined=` line — and record which two lanes produced it, so the record states what was measured against what.
- The V1 split of D5, and what slices 5b and 5c inherit unchanged.
- **The §5.3 bound**: the manifest is declared, not observed, so a matching fingerprint does not prove the run included exactly those files. Name what narrows it (slice 3's T6 body mutations on both runtimes) and what does not.
- **The §6.1 consequence**: the expectation is computed by a Chez process, so a Chez lane agrees with itself by construction and the cross-runtime claim is carried by the Gambit lane alone. Reference the uppercase mutation as the demonstration.
- The §11 open question: whether the manifest should be observed rather than declared, and the condition that reopens it — a shared body executing in a lane whose manifest does not name it.

- [ ] **Step 3: Add the changelog entry**

Under `## [Unreleased]` → `### Added` in `CHANGELOG.md`, append an entry in the voice of the existing ones — what changed, and the defect it exists to prevent, not a feature list. Cover: the fingerprint and its arithmetic-not-bitwise choice, the digit table and the measurement forcing it, `adapter-file-bytes` through a binary port, the build-computed expectation loaded rather than reimplemented, status 3's first producer, `SHARED_BODIES` being required rather than optional, and the uppercase mutation's outcome as measured rather than as predicted -- it is caught symmetrically, on both runtimes, by the self-tests' own fixed hex literals, because the passes carrying it set no manifest and so never reach the provenance comparison.

- [ ] **Step 4: Final verification**

```bash
make test && ctest --preset no-scheme --output-on-failure 2>&1 | tail -5 && git status --short
```

Expected: 44/44, 10/10, and only the two documentation files modified.

- [ ] **Step 5: Commit**

```bash
git add .decisions/0004-content-fingerprint-and-provenance.md CHANGELOG.md && git commit -m "docs: record the fingerprint measurements and what they do not prove"
```

---

## Self-Review

**Spec coverage.** Every section of the design spec maps to a task: §5.2 algorithm → Task 1; §5.1 `adapter-file-bytes` → Task 2; §6 build-time expectation → Task 3; §6 in-process check → Tasks 4 and 5; §6.2 and V13's skip-when-unset → Task 5's opening note and Step 7; §4.1 cwd-matrix copies and V9's required argument → Task 5; §7 mutations → Task 6; §9 decision record → Task 7.

**Two conflicts were resolved before execution, both by the human.**

1. **Provenance skips rather than refuses when the manifest is unset** (design V13, §6.2). Refusing would have failed all 27 existing mutation passes at their baseline — verified against `MutationRunner.cmake`, whose `byte_machine_mutation_run` requires a green baseline and whose `byte_machine_mutation_run_spec` passes no environment. The `provenance-no-manifest` lane is deleted rather than inverted; the suite ends at 44, not 45.
2. **Tasks 5 and 6 are merged** so the tree is never committed red, honouring both the plan's own Global Constraints and CLAUDE.md's "run tests before every commit".

**F9 is placed, not deferred.** The adapter export-list passes drop one named export at a time with an explicit `FIND`/`REPLACE` rather than sweeping the list, so `adapter-file-bytes` gets a concrete mutation in each of the two existing passes — Task 6 Step 5 — and adds no new pass.

**One stated blind spot.** The unreadable-manifest-body refusal has no mutation; witnessing it would require an expectation crafted to equal what the mutant computes after the read fails. It is covered by its registered lane and recorded at Task 6 Step 4, rather than papered over with an `EXPECT_SURVIVES` that AGENTS.md reserves for the genuinely unwitnessable.

**Type consistency.** `harness-fingerprint-bytevector`, `harness-fingerprint-file`, `harness-fingerprint-combine`, `harness-fingerprint->string`, `harness-bytes->string`, `harness-provenance-diagnosis`, `harness-verify-provenance!`, `harness-fingerprint-file-checked`, `harness-expected-fingerprint`, `harness-provenance-failure!`, `adapter-file-bytes`, `harness-bytes`, `byte_machine_expected_fingerprint`, `byte_machine_wrong_fingerprint`, `BYTE_MACHINE_FINGERPRINT_FILES`, `BYTE_MACHINE_EXPECT_FINGERPRINT_FILE`, `BYTE_MACHINE_FINGERPRINT_SAMPLE`, `BYTE_MACHINE_HARNESS_MANIFEST` — each is spelled the same everywhere it appears, and each is defined in the task before the one that first uses it.

---

## Task 8: The check must be reached, not merely configured

**Files:**
- Modify: `test/support/harness/shared/harness-runner.scm`
- Modify: `test/support/harness/chez/byte-machine/test/harness.sls`
- Modify: `test/support/harness/gambit/byte-machine/test/harness.sld`
- Create: `test/support/harness/self/harness-unreached-provenance.scm`
- Create: `test/support/harness/self/harness-unreached-provenance.chez.sps`
- Create: `test/support/harness/self/harness-unreached-provenance.gambit.scm`
- Modify: `test/support/harness/self/harness-self-tests.scm`
- Modify: `test/CMakeLists.txt`
- Modify: `test/support/cmake/SchemeMutationSuite.cmake`

**Interfaces:**
- Consumes: `harness-provenance-diagnosis`, `harness-verify-provenance!`, `harness-exit-status`, `harness-summary` from Tasks 4 and 5.
- Produces: `harness-provenance-reachability-diagnosis` (manifest-string-or-`#f`, checked-boolean → `#f` or a diagnostic string), and a runner that exits 3 when a lane was given a manifest that nothing verified.

### Why this exists

`SHARED_BODIES` being required guarantees the *environment is set*. It does not guarantee the check *runs*. `harness-verify-provenance!` is reached from `harness-begin`, or by a hand-placed call — which is exactly what `harness-bootstrap.scm` needed, because it deliberately never calls `harness-begin`. Had that one line been forgotten, both bootstrap lanes would have run un-provenanced and nothing would have failed.

That is the last reachable way a *registered* lane loses provenance silently, and V9's whole claim — "a lane cannot be added without it" — rests on closing it.

### The bound this does not close, stated before it is built

The guard fires from `harness-summary`. A body that calls neither `harness-begin` nor `harness-summary` — the bootstrap's own shape — still cannot be caught by it. That shape is a deliberate, singular exception that already carries its own call, and catching it would need a mechanism outside the harness entirely. What this closes is the far larger class: every body that uses the suite lifecycle but never reaches the check.

- [ ] **Step 1: Write the failing lane**

Create `test/support/harness/self/harness-unreached-provenance.scm`:

```scheme
;;; A suite that was given a manifest and never verified it.
;;;
;;; PORTABILITY: a shared body, included verbatim by each runtime's thin
;;; wrapper. Common R6RS/R7RS subset only.
;;;
;;; Every other body in this tree reaches harness-verify-provenance! through
;;; harness-begin. This one deliberately does not call harness-begin at all, so
;;; the check is never reached -- and its lane is registered with a real
;;; manifest, so the build did declare text this run was supposed to verify.
;;; That combination is the defect: provenance configured and not performed.
;;;
;;; It still reaches harness-summary, which is where the guard lives. A body
;;; that reached neither could not be caught this way, which is stated at the
;;; guard itself.

(harness-case "a case runs, so the suite is not empty"
  (lambda ()
    (check "this assertion is beside the point; reaching the summary is not" #t)))

(harness-finish)
```

Create the two wrappers, matching the import lists of the existing `harness-duplicate-case` wrappers exactly:

`harness-unreached-provenance.chez.sps`:

```scheme
;;; Chez wrapper for the unreached-provenance body. Runtime-specific only in
;;; its imports.

(import (rnrs) (byte-machine test harness) (only (chezscheme) include))

(include "harness-unreached-provenance.scm")
```

`harness-unreached-provenance.gambit.scm`:

```scheme
;;; Gambit wrapper for the unreached-provenance body. Runtime-specific only in
;;; its imports.

(import (scheme base) (scheme write) (byte-machine test harness))

(include "harness-unreached-provenance.scm")
```

Register both lanes at the end of the provenance section of `test/CMakeLists.txt`:

```cmake
# Provenance configured and never performed. SHARED_BODIES guarantees the
# environment carries a manifest; nothing until now guaranteed anything read
# it. This body reaches harness-summary without ever reaching
# harness-verify-provenance!, which is precisely the shape harness-bootstrap
# would have had if its hand-placed call had been forgotten -- and that would
# have run un-provenanced with nothing failing.
#
# A real manifest, deliberately: with none, the run is a process no lane
# registration started, and skipping is correct rather than a defect.
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.unreached-provenance.chez.source
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-unreached-provenance.chez.sps"
  SHARED_BODIES ${BYTE_MACHINE_HARNESS_MANIFEST}
                "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-unreached-provenance.scm"
  EXPECT_EXIT 3
  TIMEOUT 120
  LABELS expected-red)

byte_machine_add_scheme_lane(
  NAME byte-machine.harness.unreached-provenance.gambit.source
  BACKEND gambit
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-unreached-provenance.gambit.scm"
  SHARED_BODIES ${BYTE_MACHINE_HARNESS_MANIFEST}
                "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-unreached-provenance.gambit.scm"
  EXPECT_EXIT 3
  TIMEOUT 120
  LABELS expected-red)
```

Note the Gambit registration's second manifest entry is the `.gambit.scm` wrapper, not the shared body — correct that to the shared body when you write it, matching the Chez lane.

- [ ] **Step 2: Run it and confirm it fails**

```bash
make build && ctest --test-dir build/dev -R 'unreached-provenance' --output-on-failure 2>&1 | tail -15
```

Expected: both lanes FAIL with `exit status 0, expected 3`. The body runs one passing case and exits 0, because nothing yet notices the manifest went unverified.

- [ ] **Step 3: Add the pure rule and its self-tests**

In `harness-runner.scm`, add to the "Pure helpers" section, after `harness-provenance-diagnosis`:

```scheme
;; A lane whose build declared a manifest, in a run where nothing verified it.
;;
;; SHARED_BODIES being required makes the environment unforgeable; it says
;; nothing about whether anything read it. The check is reached from
;; harness-begin, or by a hand-placed call -- which is what harness-bootstrap
;; needed, having deliberately no harness-begin. Forget that line in a future
;; body and the lane runs un-provenanced with nothing failing, which is the one
;; remaining way V9's guarantee can be true at configure time and false at run
;; time.
;;
;; Pure, and separate from the summary's read of the live flag, for the reason
;; harness-empty-selection-diagnosis is: a run in this state cannot assert
;; anything about itself from the inside, so the rule has to be checkable as a
;; function of two values.
;;
;; An absent or empty manifest is not this defect. It means no lane
;; registration started this process, and skipping is then correct -- see
;; harness-verify-provenance!.
(define (harness-provenance-reachability-diagnosis manifest checked?)
  (if (and manifest (not (string=? manifest "")) (not checked?))
      (string-append
       "the build declared a manifest for this run and nothing verified it. "
       "harness-verify-provenance! was never reached, so this suite's result "
       "says nothing about whether it executed the text it was given.")
      #f))
```

Add self-test cases for both sides of the condition and for the two ways it must stay quiet, in the existing `harness-group "provenance"`:

```scheme
    (harness-case "a manifest nothing verified is a defect"
      (lambda ()
        (let ((d (harness-provenance-reachability-diagnosis "a.scm|b.scm" #f)))
          (check "there is a diagnosis" (if d #t #f))
          (check "it says the check was not reached"
                 (harness-string-contains? d "never reached")))))

    (harness-case "a manifest that was verified is not a defect"
      (lambda ()
        (check "verified"
               (not (harness-provenance-reachability-diagnosis "a.scm" #t)))))

    ;; An absent or empty manifest means no lane registration started this
    ;; process. Skipping is correct there, so neither may be reported as a
    ;; defect -- and both spellings must agree, for the reason
    ;; harness-normalize-filter gives about a shell that writes VAR= .
    (harness-case "no manifest is not a defect, however it is spelled"
      (lambda ()
        (check "absent" (not (harness-provenance-reachability-diagnosis #f #f)))
        (check "empty" (not (harness-provenance-reachability-diagnosis "" #f)))))
```

- [ ] **Step 4: Wire the flag and the status**

Add the flag beside the other top-level mutable state, NOT inside `harness-clear-state!` and NOT in `harness-capture-state` / `harness-restore-state!`. Both reasons are load-bearing: `harness-begin` calls `harness-verify-provenance!` *before* `harness-clear-state!`, so a flag cleared there would be set and immediately erased; and a probe restores captured state, so a flag captured there would be reset by any probe that ran after the check.

```scheme
;; Set by harness-verify-provenance! itself, so "unset" means the procedure was
;; never called -- not that it ran and found nothing. Deliberately outside
;; harness-clear-state! and the probe's captured state: harness-begin verifies
;; before it clears, and a probe restoring this would erase the fact that the
;; check happened.
(define harness-provenance-checked #f)
(define harness-provenance-unreached #f)
```

Set it at the very top of `harness-verify-provenance!`, unconditionally — before the skip branch, so the flag records that the procedure ran rather than what it concluded.

In `harness-summary`, alongside the existing empty-selection check and before the status is computed:

```scheme
  (let ((unreached (harness-provenance-reachability-diagnosis
                    (adapter-environment-variable "BYTE_MACHINE_FINGERPRINT_FILES")
                    harness-provenance-checked)))
    (if unreached
        (begin
          (set! harness-provenance-unreached #t)
          (harness-say-always
           (string-append "byte-machine-harness: PROVENANCE-ERROR " unreached)))))
```

And extend `harness-exit-status` with a first clause, keeping status computed in one place as this file's header requires:

```scheme
(define (harness-exit-status)
  (cond ((or harness-provenance-unreached) harness-status-provenance)
        ((> harness-error-count 0) harness-status-harness-error)
        ((> harness-failure-count 0) harness-status-failed)
        (else harness-status-pass)))
```

Provenance outranks both other nonzero statuses, for the reason slice 2's decision S3 reserved 3 in the first place: several lanes legitimately expect 1 or 2, and a provenance defect sharing either would be indistinguishable from those fixtures' own expected outcomes.

Export `harness-provenance-reachability-diagnosis` from both adapters, in the existing `;; content fingerprint and provenance` group. Verify parity with a set comparison.

- [ ] **Step 5: Run everything**

```bash
make test && ctest --preset no-scheme --output-on-failure 2>&1 | tail -5
```

Expected: 46/46 and 10/10. The two new lanes now exit 3; every other lane is unaffected, because each reaches the check through `harness-begin`.

Also confirm the mutation suite is undisturbed — its staged lanes carry no manifest, so the guard must stay quiet there:

```bash
ctest --test-dir build/dev -R 'scheme-mutation' --output-on-failure 2>&1 | tail -6
```

- [ ] **Step 6: Mutate the guard**

Add a pass to `SchemeMutationSuite.cmake` breaking the reachability rule and requiring the new lane to notice. The verify command is the new lane wrapped in the exact-status helper with `BYTE_MACHINE_EXPECT_EXIT=3`, and the manifest and its expectation supplied through `cmake -E env`, exactly as passes 32 and 33 do — read them and match their shape, including the one-body manifest, since `BYTE_MACHINE_EXPECT_COMMAND` packs with `|`.

Two mutations, because the rule has two halves that fail independently:
- the diagnosis always returns `#f` — the guard stops guarding;
- `harness-verify-provenance!` sets the flag even when it is never called, i.e. initialise `harness-provenance-checked` to `#t` — the guard cannot distinguish a reached check from an unreached one.

Update the declared counters and the file's opening prose to match what the suite actually reports.

- [ ] **Step 7: Run everything again and commit**

```bash
make test && ctest --preset no-scheme --output-on-failure 2>&1 | tail -5 && ctest --test-dir build/dev -R 'mutation' --output-on-failure 2>&1 | tail -6
```

```bash
git add -A && git commit -m "feat: a manifest nothing verified is a provenance failure"
```
