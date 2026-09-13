;;; Milestone 11 Slice ②: the brief §2b HTTP-header case-insensitivity
;;; demonstration (criterion 4) and the folded-collision rejection's per-table
;;; contrast (decision 0045 item 3), interpreter ≡ generated with the generated
;;; side asserted ABSOLUTELY (agreement alone cannot carry a fold defect that hit
;;; both executors identically -- Slice ①'s lane lesson).
;;;
;;; Two kinds of group:
;;;  - RECOGNITION: a case-insensitive header table folds every casing of
;;;    Content-Length / Transfer-Encoding to one target; a case-sensitive one over
;;;    the same names recognizes only the canonical bytes. That is criterion 4.
;;;  - COLLISION: a case-insensitive table over two byte-distinct case variants
;;;    (Content-Length + content-length) is refused by name; the SAME table
;;;    case-sensitive verifies clean. The collision group calls `verify-machine`
;;;    DIRECTLY -- the case-insensitive collision machine is invalid by design and
;;;    would raise through `make-interpreted-machine`. The CS-verifies-clean
;;;    assertion is the per-table pin (a mutant dropping the case-insensitive?
;;;    guard rejects it wrongly).
(import (rnrs) (rnrs eval)
        (only (chezscheme) load)
        (byte-machine test harness)
        (byte-machine test keyword-header-machine)
        (byte-machine graph)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime)
        (byte-machine compile))

(harness-begin "differential.keyword-header")

(define tmpdir
  (let ((d (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")))
    (if (and d (not (string=? d ""))) d
        (assertion-violation 'differential-keyword-header
                             "BYTE_MACHINE_TEST_TMPDIR is unset" d))))

;; Emit, load and eval one fixture's generated library (the sequence/keyword-node
;; differential precedent; the binding is this function's own).
(define (generated-machine name machine)
  (let ((genfile (string-append tmpdir "/generated-" (symbol->string name) ".sls"))
        (binding (string->symbol (string-append (symbol->string name) "-parser"))))
    (call-with-port (open-file-output-port genfile (file-options no-fail))
      (lambda (p) (emit-machine (compile-machine machine '()) binding p)))
    (load genfile)
    (eval binding (environment (list 'generated name)))))

(define (str->bv s) (u8-list->bytevector (map char->integer (string->list s))))
(define (error-code-of r)
  (let ((e (parser-result-error r))) (and (parser-error? e) (parser-error-code e))))
(define (error-off-of r)
  (let ((e (parser-result-error r))) (and (parser-error? e) (parser-error-offset e))))
(define (rfields r p)
  (list (parser-result-status r) (parser-result-consumed r)
        (parser-result-next r) (parser-result-stream-offset r)
        (parser-state-name p) (error-code-of r) (error-off-of r)))
(define (feed1 cm s)
  (let* ((bv (str->bv s)) (p (make-parser cm '() #f))
         (r (parser-feed! p bv 0 (bytevector-length bv))))
    (rfields r p)))

(define cs-ref (make-interpreted-machine (verify-machine (make-keyword-header-machine))))
(define cs-gen (generated-machine 'kwheader (make-keyword-header-machine)))
(define ci-ref (make-interpreted-machine (verify-machine (make-keyword-header-ci-machine))))
(define ci-gen (generated-machine 'kwheaderci (make-keyword-header-ci-machine)))

;; --- criterion 4, the HIT half: the case-insensitive table folds every casing --
(harness-group "the case-insensitive table folds every casing of a header name to one target"
  (lambda ()
    (harness-case "Content-Length in canonical, lower and mixed case all reach got-content-length"
      (lambda ()
        (let ((bad 'none) (ran 0)
              (want '(stopped 14 14 14 got-content-length #f #f)))
          (for-each
           (lambda (s)
             (set! ran (+ ran 1))
             (let ((g (feed1 ci-gen s)) (i (feed1 ci-ref s)))
               (when (eq? bad 'none)
                 (cond ((not (equal? g want)) (set! bad (list 'gen s g)))
                       ((not (equal? i g)) (set! bad (list 'disagree s i g)))))))
           '("Content-Length " "content-length " "cOnTeNt-LeNgTh "))
          (check-equal "no casing misbehaved" bad 'none)
          (check-equal "all three casings ran" ran 3))))
    (harness-case "a second hyphenated name (Transfer-Encoding) folds across the hyphen too"
      (lambda ()
        (check-equal "canonical" (feed1 ci-gen "Transfer-Encoding ") '(stopped 17 17 17 got-transfer-encoding #f #f))
        (check-equal "lower" (feed1 ci-gen "transfer-encoding ") '(stopped 17 17 17 got-transfer-encoding #f #f))
        (check-equal "agree lower" (feed1 ci-ref "transfer-encoding ") (feed1 ci-gen "transfer-encoding "))))))

;; --- criterion 4, the MISS half: the case-sensitive table refuses the casings --
(harness-group "the case-sensitive table recognizes only the canonical bytes"
  (lambda ()
    (harness-case "Content-Length canonical hits; lower and mixed case no-match at offset 0"
      (lambda ()
        (check-equal "canonical hits" (feed1 cs-gen "Content-Length ") '(stopped 14 14 14 got-content-length #f #f))
        (check-equal "lower misses" (feed1 cs-gen "content-length ") '(error 0 0 0 reject unexpected-byte 0))
        (check-equal "mixed misses" (feed1 cs-gen "cOnTeNt-LeNgTh ") '(error 0 0 0 reject unexpected-byte 0))
        (check-equal "agree canonical" (feed1 cs-ref "Content-Length ") (feed1 cs-gen "Content-Length "))
        (check-equal "agree lower" (feed1 cs-ref "content-length ") (feed1 cs-gen "content-length "))
        (check-equal "agree mixed" (feed1 cs-ref "cOnTeNt-LeNgTh ") (feed1 cs-gen "cOnTeNt-LeNgTh "))))))

;; --- structure: extension, near-miss, and an incomplete prefix ----------------
(harness-group "extension, near-miss and incomplete prefix behave, both lanes"
  (lambda ()
    (harness-case "an extension takes the keyword and leaves the extra byte (Connections -> Connection + s)"
      (lambda ()
        (check-equal "gen" (feed1 ci-gen "Connections") '(stopped 10 10 10 got-connection #f #f))
        (check-equal "agree" (feed1 ci-ref "Connections") (feed1 ci-gen "Connections"))))
    (harness-case "a near-miss at byte 0 no-matches (no keyword begins with X)"
      (lambda ()
        (check-equal "gen" (feed1 ci-gen "Xpgrade ") '(error 0 0 0 reject unexpected-byte 0))
        (check-equal "agree" (feed1 ci-ref "Xpgrade ") (feed1 ci-gen "Xpgrade "))))
    (harness-case "a prefix short of Upgrade, then a non-continuing byte, no-matches at the divergence"
      (lambda ()
        (check-equal "gen" (feed1 ci-gen "Upgrad ") '(error 6 6 6 reject unexpected-byte 6))
        (check-equal "agree" (feed1 ci-ref "Upgrad ") (feed1 ci-gen "Upgrad "))))))

;; --- the folded-collision rejection is per-table (decision 0045 item 3) -------
;; verify-machine directly: the case-insensitive collision machine is invalid by
;; design (it would raise through make-interpreted-machine). The CS-verifies-clean
;; assertion is the per-table pin.
(harness-group "a case-insensitive fold collision is refused; the same case-sensitive table verifies"
  (lambda ()
    (harness-case "the case-insensitive collision table is refused by name"
      (lambda ()
        (let* ((v (verify-machine (make-keyword-collision-ci-machine)))
               (codes (map diagnostic-code (verification-diagnostics v))))
          (check "the collision table does not verify" (not (verification-ok? v)))
          (check "case-insensitive-keyword-collision is among its diagnostics"
                 (and (memq 'case-insensitive-keyword-collision codes) #t)))))
    (harness-case "the same table, case-sensitive, verifies clean (byte-distinct entries, no fold)"
      (lambda ()
        (let ((v (verify-machine (make-keyword-collision-cs-machine))))
          (check "the case-sensitive collision-shaped table verifies" (verification-ok? v))
          (check-equal "with no diagnostics" (length (verification-diagnostics v)) 0))))))

(harness-finish)
