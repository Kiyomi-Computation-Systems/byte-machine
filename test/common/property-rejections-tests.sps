;;; The rejection catalogue and the independent oracle (Milestone 7 Slice ④,
;;; design §4.5 and §4.6; decision 0033 items 1-2). Two instruments in one program,
;;; on §4.10's `byte-machine.property.rejections.chez.*` lane allocation.
;;;
;;; IT IMPORTS NO EXECUTOR, AND THAT IS THE POINT (F7, §22.6:1297). The corrupted
;;; machines are never handed to an executor: this program's own `import` form names
;;; NONE of (byte-machine interpret), (byte-machine compile) or (byte-machine
;;; runtime), and its lane's SOURCES omit them too (test/CMakeLists.txt), so under
;;; the AOT lane the program CANNOT import them. The only consumer of a corrupted
;;; machine is `verify-machine`. The catalogue's twin "verifies" means
;;; `verification-ok?` answered #t; the oracle's disagreement is a set comparison
;;; against `verification-diagnostics`. Neither instrument introduces a third notion
;;; of validity.
;;;
;;; THE CATALOGUE (§4.5): for every accepted machine of the committed seed and every
;;; applicable entry, the corrupted machine's `(code . node)` set CONTAINS the
;;; entry's expected pairs (collateral diagnostics are expected, F4), and the TWIN
;;; verifies and does not contain the entry's code. Two totality rows: the code
;;; sentinel (F5 row 1) and the refusal table (F5 row 2).
;;;
;;; THE ORACLE (§4.6): over free draws ∪ the property lane's rejected draws ∪ the
;;; catalogue's corrupted machines, each rule's `(code . node)` set is compared to
;;; the verifier's for that rule's codes. Zero differences on the committed seed;
;;; every rule fires and stays silent. A reachability rule is not compared on a
;;; machine whose node names are not unique (reachability is ill-defined there --
;;; only the dup-node-name entry produces such a machine, and it is compared on the
;;; :885 rule, which is its point).
;;;
;;; THE SEED (0033 item 3): BYTE_MACHINE_PROPERTY_SEED, unset LEGAL (the committed
;;; default), malformed LOUD -- the parsing rule replicated from
;;; property-differential-tests.sps, with the same `(rnrs)`-has-no-`string-trim`
;;; note. BYTE_MACHINE_SOURCE_ROOT and BYTE_MACHINE_HARNESS_ROOT are loud when unset
;;; (the census's reason): the code sentinel reads verify.sls as a datum and the
;;; matcher-bytes prohibition reads verify-oracle.sls as a datum.
(import (rnrs)
        (byte-machine test harness)
        (byte-machine test prng)
        (byte-machine test machine-gen)
        (byte-machine test machine-corrupt)
        (byte-machine test verify-oracle)
        (byte-machine test rejection-ledger)
        (byte-machine graph)
        (byte-machine private ir)
        (byte-machine private conditions)
        (byte-machine verify))

;; ---- the seed (0033 item 3), replicated from the differential lane -----------
(define committed-seed 20260823)
(define (ws-char? c) (let ((b (char->integer c))) (or (= b 32) (= b 9) (= b 10) (= b 13))))
(define (trim s)
  (let* ((cs (string->list s))
         (a (let drop ((l cs)) (if (and (pair? l) (ws-char? (car l))) (drop (cdr l)) l)))
         (b (reverse (let drop ((l (reverse a))) (if (and (pair? l) (ws-char? (car l))) (drop (cdr l)) l)))))
    (list->string b)))
(define seed
  (let ((raw (adapter-environment-variable "BYTE_MACHINE_PROPERTY_SEED")))
    (if (not raw) committed-seed
        (let ((t (trim raw)))
          (if (string=? t "") committed-seed
              (let ((n (string->number t 10)))
                (if (and n (integer? n) (exact? n) (>= n 0)) n
                    (assertion-violation 'rejections
                      "BYTE_MACHINE_PROPERTY_SEED is not a nonnegative decimal integer" raw))))))))

(define (env-loud name who)
  (let ((r (adapter-environment-variable name)))
    (if (and r (not (string=? r ""))) r (assertion-violation who (string-append name " is unset") r))))
(define source-root (env-loud "BYTE_MACHINE_SOURCE_ROOT" 'rejections))
(define harness-root (env-loud "BYTE_MACHINE_HARNESS_ROOT" 'rejections))

;; printed once at the suite's start (0033 item 3), as the differential lane does.
(display "property-rejections-tests: drawing seed ") (display seed) (newline)

;; ---- reading source files as data (the census technique) ---------------------
(define (read-one path)
  (call-with-input-file path
    (lambda (p) (let* ((d (read p)) (clean (eof-object? (read p)))) (cons d clean)))))
(define verify-src (read-one (string-append source-root "/byte-machine/verify.sls")))
(define ir-src (read-one (string-append source-root "/byte-machine/private/ir.sls")))
(define oracle-src (read-one (string-append harness-root "/byte-machine/test/verify-oracle.sls")))

(define (uniq xs) (fold-left (lambda (a x) (if (member x a) a (cons x a))) '() xs))
(define (count-symbol sym d)
  (cond ((pair? d) (+ (count-symbol sym (car d)) (count-symbol sym (cdr d))))
        ((vector? d) (count-symbol sym (vector->list d)))
        ((eq? d sym) 1) (else 0)))

;; the diagnostic-census walk (replicated -- programs, not libraries, so both the
;; differential lane and this one carry their own copy): every quoted first argument
;; of a make-diagnostic* form in verify.sls, distinct, is the derived code set.
(define (make-diagnostic-name? sym)
  (and (symbol? sym)
       (let ((nm (symbol->string sym)) (pre "make-diagnostic"))
         (and (>= (string-length nm) (string-length pre))
              (string=? (substring nm 0 (string-length pre)) pre)))))
(define diagnostic-constructors
  (let loop ((x (car verify-src)) (acc '()))
    (cond ((pair? x)
           (let ((acc (if (and (eq? (car x) 'define) (pair? (cdr x)) (pair? (cadr x))
                               (make-diagnostic-name? (car (cadr x))) (not (memq (car (cadr x)) acc)))
                          (cons (car (cadr x)) acc) acc)))
             (loop (cdr x) (loop (car x) acc))))
          ((vector? x) (loop (vector->list x) acc)) (else acc))))
(define (census-codes)
  (uniq (let loop ((x (car verify-src)) (acc '()))
          (cond ((pair? x)
                 (let ((acc (if (memq (car x) diagnostic-constructors)
                                (let ((a (and (pair? (cdr x)) (cadr x))))
                                  (if (and (pair? a) (eq? (car a) 'quote)) (cons (cadr a) acc) acc))
                                acc)))
                   (loop (cdr x) (loop (car x) acc))))
                ((vector? x) (loop (vector->list x) acc)) (else acc)))))

;; make-stop-node's parameter list, read from ir.sls -- the :906 structural check.
(define (ctor-params datum name)
  (let loop ((x datum))
    (cond ((and (pair? x) (eq? (car x) 'define) (pair? (cdr x)) (pair? (cadr x))
                (eq? (car (cadr x)) name))
           (cdr (cadr x)))
          ((pair? x) (or (loop (car x)) (loop (cdr x))))
          (else #f))))

;; ---- the draws ---------------------------------------------------------------
(define machine-count 64)
(define (draw-all steering)
  (let loop ((i 0) (s (make-prng seed)) (acc '()))
    (if (= i machine-count) (reverse acc)
        (let-values (((m mani s2) (gen-machine s (steering)))) (loop (+ i 1) s2 (cons m acc))))))
(define property-draws (draw-all property-steering))
(define accepted (filter (lambda (m) (verification-ok? (verify-machine m))) property-draws))
(define free-draws (draw-all free-steering))
;; the property lane's REJECTED draws, wrapped through make-rejection* (F6 -- the
;; shipped rejection ledger's first consumer, reached through F13's library).
(define rejections
  (let loop ((ds property-draws) (i 0) (acc '()))
    (if (null? ds) (reverse acc)
        (let ((v (verify-machine (car ds))))
          (loop (cdr ds) (+ i 1)
                (if (verification-ok? v) acc
                    (cons (make-rejection* i (car ds) (verification-diagnostics v)) acc)))))))
;; the catalogue's corrupted machines, with the entry each came from.
(define corruptions
  (apply append
    (map (lambda (e)
           (map (lambda (m) (cons e ((corruption-entry-corrupt e) m)))
                (filter (corruption-entry-applies? e) accepted)))
         corruption-entries)))
;; the oracle's drive: free draws ∪ rejected draws ∪ corrupted machines.
(define oracle-corpus
  (append free-draws (map rejection-machine rejections) (map cdr corruptions)))

;; ---- verifier views ----------------------------------------------------------
(define (v-pairs m)
  (map (lambda (d) (cons (diagnostic-code d) (diagnostic-node d))) (verification-diagnostics (verify-machine m))))
(define (v-pairs/codes m codes) (uniq (filter (lambda (p) (memq (car p) codes)) (v-pairs m))))
(define (subset? a b) (for-all (lambda (x) (member x b)) a))
(define (set=? a b) (and (subset? a b) (subset? b a)))
(define (applicable e) (filter (corruption-entry-applies? e) accepted))
(define (seed-label s) (string-append " (seed " (number->string seed) ")"))

(harness-begin "property.rejections")

;; ---- the catalogue: positive half (Task 3 Step 2) ----------------------------
(harness-group "the catalogue's positive half -- the corruption emits its diagnostic"
  (lambda ()
    (for-each
     (lambda (e)
       (harness-case (string-append "positive: " (symbol->string (corruption-entry-name e))
                                    " " (symbol->string (corruption-entry-bullet e)) (seed-label seed))
        (lambda ()
          (check (string-append (symbol->string (corruption-entry-name e))
                                " corruptions all contain the expected pairs")
                 (for-all (lambda (m)
                            (subset? ((corruption-entry-expected e) m)
                                     (v-pairs ((corruption-entry-corrupt e) m))))
                          (applicable e))))))
     corruption-entries)))

;; ---- the catalogue: negative half (Task 3 Step 3) ----------------------------
(harness-group "the catalogue's negative half -- the twin verifies and does not"
  (lambda ()
    (for-each
     (lambda (e)
       (harness-case (string-append "negative: " (symbol->string (corruption-entry-name e))
                                    " " (symbol->string (corruption-entry-bullet e)) (seed-label seed))
        (lambda ()
          (let ((codes (map car ((corruption-entry-expected e) (car (applicable e))))))
            (check (string-append (symbol->string (corruption-entry-name e))
                                  " twins verify and lack the entry's code")
                   (for-all (lambda (m)
                              (let ((tw ((corruption-entry-twin e) m)))
                                (and (verification-ok? (verify-machine tw))
                                     (not (exists (lambda (c) (memq c codes)) (map car (v-pairs tw)))))))
                            (applicable e)))))))
     corruption-entries)))

;; ---- never executed (Task 3 Step 4, F7) --------------------------------------
(harness-group "the corrupted machines are never handed to an executor"
  (lambda ()
    (harness-case "no executor is in scope; only verify-machine consumes a corrupted machine"
      (lambda ()
        ;; The count of corrupted machines handed to any executor is 0 by the program
        ;; having none in scope -- there is no interpret/compile/runtime binding to
        ;; call. The enforcement that no corrupted machine reaches an executor is
        ;; STRUCTURAL and not a runtime check: this program imports no executor (the
        ;; header's import form names none of interpret/compile/runtime) and its lane's
        ;; SOURCES omit them, so under the AOT lane the static-import closure cannot
        ;; reach one -- a runtime `check` here could only ever be a tautology, which is
        ;; why there is none. The corpus is non-empty (so the catalogue groups above,
        ;; which are the only consumers of a corrupted machine and pass it only to
        ;; verify-machine, actually ran over it).
        (check "the corpus of corrupted machines is non-empty" (pair? corruptions))))))

;; ---- per-entry application counts (Task 3 Step 5) ----------------------------
(harness-group "every catalogue entry applied to at least one accepted machine"
  (lambda ()
    (harness-case (string-append "per-entry application counts" (seed-label seed))
      (lambda ()
        ;; the whole table, printed so a collapse is legible without a re-run.
        (for-each (lambda (e)
                    (display "  ") (display (corruption-entry-name e))
                    (display " -> ") (display (length (applicable e))) (newline))
                  corruption-entries)
        (for-each (lambda (e)
                    (check (string-append (symbol->string (corruption-entry-name e)) " applied >= 1")
                           (>= (length (applicable e)) 1)))
                  corruption-entries)))))

;; ---- F5 row 1: the code sentinel ---------------------------------------------
(harness-group "the entry codes plus the unconstructible list equal the census"
  (lambda ()
    (harness-case "code sentinel"
      (lambda ()
        (let* ((entry-codes (uniq (apply append
                              (map (lambda (e) (map car ((corruption-entry-expected e) (car (applicable e)))))
                                   corruption-entries))))
               (sentinel (uniq (append entry-codes unconstructible-codes)))
               (census (census-codes)))
          (check "the sentinel set-equals the census's derived code set" (set=? sentinel census))
          (check-equal "and the census derives exactly thirty codes" (length census) 30)
          (check-equal "and the sentinel is exactly thirty codes" (length sentinel) 30))))))

;; ---- F5 row 2: the refusal table (Task 3 Step 7) -----------------------------
(harness-group "the constructor refusals still refuse"
  (lambda ()
    (for-each
     (lambda (r)
       (harness-case (string-append "refusal: " (symbol->string (refusal-name r))
                                    " " (symbol->string (refusal-bullet r)))
        (lambda ()
          (if (refusal-thunk r)
              (check (string-append (symbol->string (refusal-name r)) " raises a contract violation")
                     (guard (ex ((byte-machine-contract-condition? ex)
                                 (eq? (byte-machine-contract-condition-code ex) 'invalid-argument))
                                (#t #f))
                       ((refusal-thunk r)) #f))
              ;; :906 has no thunk: assert structurally that a terminal constructor
              ;; has no out-edge slot -- make-stop-node takes (name source-label).
              (check-equal "make-stop-node takes name and source-label only -- no out-edge slot"
                           (ctor-params (car ir-src) 'make-stop-node) '(name source-label))))))
     constructor-refusals)))

;; ---- Task 9 Step 3: the matcher-bytes prohibition, made checkable -------------
(harness-group "the oracle's :893 row never reads matcher-bytes"
  (lambda ()
    (harness-case "matcher-bytes occurs zero times in verify-oracle.sls"
      (lambda ()
        (check "verify-oracle.sls is exactly one datum" (cdr oracle-src))
        (check-equal "the symbol matcher-bytes does not occur in the oracle"
                     (count-symbol 'matcher-bytes (car oracle-src)) 0)))))

;; ---- the oracle: zero differences, fire and silent (Task 4) ------------------
(define (compared-for rule)
  ;; the corpus machines this rule is compared on (reach? rules skip non-unique-name
  ;; machines, where reachability is ill-defined).
  (filter (lambda (m) (or (not (oracle-rule-reach? rule)) (not (machine? m)) (nodes-unique? m)))
          oracle-corpus))
(harness-group "the independent oracle agrees with the verifier on the committed seed"
  (lambda ()
    (for-each
     (lambda (rule)
       (let* ((codes (oracle-rule-codes rule))
              (ms (compared-for rule))
              (compare (if (eq? (oracle-rule-comparison rule) 'subset) subset? set=?))
              (diff (let scan ((xs ms))
                      (cond ((null? xs) 'none)
                            ((not (compare (uniq (oracle-eval rule (car xs))) (v-pairs/codes (car xs) codes)))
                             (list 'oracle (uniq (oracle-eval rule (car xs))) 'verifier (v-pairs/codes (car xs) codes)))
                            (else (scan (cdr xs)))))))
         (harness-case (string-append "oracle rule " (symbol->string (oracle-rule-name rule)) (seed-label seed))
          (lambda ()
            (check-equal (string-append (symbol->string (oracle-rule-name rule)) " agrees with the verifier")
                         diff 'none)))))
     oracle-rules)))

(harness-group "every oracle rule both fires and stays silent"
  (lambda ()
    (harness-case (string-append "fire and silent counters" (seed-label seed))
      (lambda ()
        (for-each
         (lambda (rule)
           (let ((fire 0) (silent 0))
             (for-each (lambda (m)
                         (if (null? (oracle-eval rule m)) (set! silent (+ silent 1)) (set! fire (+ fire 1))))
                       (compared-for rule))
             (check (string-append (symbol->string (oracle-rule-name rule)) " fired at least once") (>= fire 1))
             (check (string-append (symbol->string (oracle-rule-name rule)) " stayed silent at least once") (>= silent 1))))
         oracle-rules)))))

;; ---- the drive's own sentinels (Task 3 Step 8, Task 4 Step 7) ----------------
(harness-group "the drive's loop sentinels -- a literal and a derived total"
  (lambda ()
    (harness-case (string-append "sentinels" (seed-label seed))
      (lambda ()
        (check-equal "the property draw yields the differential lane's accepted literal"
                     (length accepted) 36)
        (check-equal "every property draw was accepted or rejected"
                     (+ (length accepted) (length rejections)) machine-count)
        (check-equal "the entry table has thirty entries" (length corruption-entries) 30)
        ;; the (machine, entry) pairs actually driven equals the sum of per-entry counts.
        (check-equal "the (machine,entry) pairs driven equal the sum of per-entry counts"
                     (length corruptions)
                     (apply + (map (lambda (e) (length (applicable e))) corruption-entries)))
        ;; the loop-over-the-loops (Task 4 Step 7): the comparisons actually performed
        ;; equal machines x rules, adjusted for the reach? skips -- computed by a
        ;; DIFFERENT formula (rule-counts times corpus sizes) than the observed sum of
        ;; per-rule |compared-for|, so a wrong filter in one rule separates the two.
        (let* ((reach-corpus (filter (lambda (m) (or (not (machine? m)) (nodes-unique? m))) oracle-corpus))
               (n-reach (length (filter oracle-rule-reach? oracle-rules)))
               (n-plain (- (length oracle-rules) n-reach))
               (expected (+ (* n-plain (length oracle-corpus)) (* n-reach (length reach-corpus))))
               (observed (apply + (map (lambda (r) (length (compared-for r))) oracle-rules))))
          (check-equal "the oracle performed machines x rules comparisons (reach? skips adjusted)"
                       observed expected))
        (check "the oracle corpus is non-empty" (pair? oracle-corpus))))))

(harness-finish)
