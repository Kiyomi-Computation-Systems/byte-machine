;;; The §22.4:1271 cross-lane error projection, with ONE owner.
;;;
;;; The differential compares "error domain, code, public source-node name,
;;; absolute position, and position kind" -- five members. It does NOT compare
;;; parser-error-state-id: §12.7:777 says generated IDs "are deterministic for a
;;; given normalized graph, but an independently interpreted machine need not
;;; report the same ID. Differential tests do not compare that accessor across
;;; executor kinds." Both lanes must still REPORT one; only the comparison omits
;;; it.
;;;
;;; This lives in one library rather than in each differential program because
;;; eight local copies of a §12.7:777 reading is eight places for it to drift,
;;; and because the positive exclusion check needs something to assert against.
;;; The trap it exists to prevent: once the error slot holds a record, every
;;; whole-value tuple comparison goes red -- correctly, since the state id is
;;; lane-local -- and the obvious repair is to compare (parser-error-code e)
;;; instead, which restores green while narrowing the comparison back to the one
;;; symbol it compared before the family existed, shipping four of the five
;;; comparable members with no differential behind them.
(library (byte-machine test error-projection)
  (export project-error projected-members error-state-id)
  (import (rnrs) (byte-machine runtime))

  ;; #f in, #f out: parser-result-error is #f on every non-error result, and
  ;; keeping that shape means the non-error tuples in the differential programs
  ;; read exactly as they did before this family existed.
  (define (project-error e)
    (if (parser-error? e)
        (list (parser-error-domain e)
              (parser-error-code e)
              (parser-error-reason e)
              (parser-error-node-name e)
              (parser-error-offset e)
              (parser-error-position-kind e))
        e))

  ;; What project-error yields, named so a test can assert the width rather than
  ;; counting a literal list. Six, not five: §22.4:1271's five plus `reason`,
  ;; which §12.7:777 neither requires to match nor licenses to differ. It is
  ;; compared here rather than left as an orphan, and comparing it earned its
  ;; keep: the two lanes resolved the declaration by different keys -- the
  ;; interpreter by name, the emitter by resolved code -- and `reason` is the
  ;; only member that divergence moved, so this is the projection member that
  ;; caught it. Do not narrow this list on the argument that both lanes "build
  ;; it from the same declaration"; that was the assumption the defect broke.
  (define projected-members 6)

  ;; The deliberately excluded member. Exposed so a lane can assert that both
  ;; executors REPORT a state id while the comparison omits it -- positively,
  ;; rather than by the omission being invisible.
  (define (error-state-id e)
    (and (parser-error? e) (parser-error-state-id e))))
