;;; The member-2 runtime-export drift guard (Slice A design §6; parent §9.2, §20).
;;; compile.sls's reserved-member-2 must exactly mirror (byte-machine runtime)'s
;;; exports; otherwise the emitter could accept a binding that collides with a
;;; runtime export. This asserts the two sets are equal. It passes today (they are
;;; identical); its RED is the mutation that drops an entry (SchemeMutationSuite
;;; Pass 40). If a /v2 export is ever added, both lists change together or this
;;; lane fails.
;;;
;;; (byte-machine runtime) is imported below even though no binding from it is
;;; referenced by name -- environment-symbols reaches it dynamically by name via
;;; `environment`. Measured against Chez 10.4.1 on 2026-08-23: the AOT compile
;;; step (chez-compile.ss) runs compile-program with compile-imported-libraries
;;; #t, which compiles only what the program statically imports; the AOT
;;; launcher then loads exclusively from compiled objects (its source guard is
;;; always empty, deliberately, so it can never fall back to source). Without a
;;; static import here, runtime.sls is declared in this lane's SOURCES (for
;;; fingerprinting and the source lane) but is never compiled to an object the
;;; AOT lane's library-directories can find, and `environment` raises "library
;;; (byte-machine runtime) not found" under aot only. The static import forces
;;; chez-compile.ss to include it, and does not change what environment-symbols
;;; measures.
(import (rnrs) (rnrs eval)
        (only (chezscheme) environment-symbols)
        (byte-machine test harness)
        (byte-machine compile)
        (byte-machine runtime))

(harness-begin "unit.reserved-drift")

(define (sorted syms)
  (list-sort (lambda (a b) (string<? (symbol->string a) (symbol->string b))) syms))
(define declared (sorted reserved-member-2))
(define live (sorted (environment-symbols (environment '(byte-machine runtime)))))

(harness-group "reserved member 2 mirrors the runtime exports"
  (lambda ()
    (harness-case "the declared set equals the live runtime export set"
      (lambda ()
        (check-equal "no drift between reserved-member-2 and (byte-machine runtime)"
                     declared live)))))

(harness-finish)
