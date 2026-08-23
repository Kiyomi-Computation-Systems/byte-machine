# 0008: The emitter emits a complete importable library, not an included body

Date: 2026-08-23
Status: accepted
Milestone: 1, Gate 0 (milestone-1-design.md §3.1)

## Context

The parent plan's §9.6 required Milestone 1's end-to-end example to *include*
the generated body from a hand-written consumer library wrapper. Decision 0006
(§7.2) forbids any Scheme file in this repository including another. The two
instructions contradict each other; the Milestone 0 close-out (§9) recorded the
conflict as a design call, not a wording fix, and handed it here.

The pre-collapse design imagined the emitter writing a bare `.scm` body (loose
definitions, not a module) that a hand-written `.sls` wrapper pulled in with
`(include ...)` and re-exported. Decision 0006 removed the only mechanism that
made that composition possible: a bare body is not a module, so nothing can
`import` it, and `include` is banned.

## Decision

1. **The emitter emits a complete, self-contained R6RS `.sls` library.** The
   generated file owns its library name, its export list, and its imports; its
   only byte-machine import is `(byte-machine runtime)`. It contains the machine
   body and defines exactly the single top-level compiled-machine binding named
   by the `binding` argument to `render-machine`/`emit-machine` (§9.2).
2. **Consumers compose the generated parser by `import`, never `include`.** The
   §9.6 example's consumer does `(import (<generated-library-name>))`; there is
   no wrapper that includes anything. §7.2's no-include rule stands unbroken.
3. **"Wrapper-free" is read as "needs no hand-written wrapper."** §9.5's ABI
   export exists so the generated code's sole byte-machine dependency is
   `(byte-machine runtime)`. The generated library is itself the importable
   unit; no adapter library is required around it.
4. **A human-authored re-export wrapper remains possible but is out of scope.**
   A consumer that wants a different public library name may write a wrapper that
   imports the generated library and re-exports it — additive, by `import`, and
   not built in Milestone 1.

## Consequences

- Phase 3's emitter writes library boilerplate (the `(library ...)` form, export
  list, and `(import (byte-machine runtime))`) as part of its output, to the
  supplied binary port only (§20).
- The parent plan's §9.6 step 5, §9.5 ABI paragraph, and §7.1 "generated bodies"
  sentence are corrected in place (they are instructions, not records) to match
  this decision.
- Decision 0006's no-include rule is unchanged and now has a second beneficiary:
  generated code composes by the module system like every other library.
