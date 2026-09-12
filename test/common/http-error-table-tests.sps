;;; Milestone 8 Slice ⓪: the fixture-state -> expected-error table's oracle.
;;;
;;; The table (test/support/harness/byte-machine/test/http-error-table.sls)
;;; discharges §21.4:1177's precondition. This lane holds it to decision 0034's
;;; two totality rows and the shape guards, WITH THE EIGHTEEN §21.4 CODES SPELLED
;;; OUT HERE so a change to the table's own copy is caught against the spec, not
;;; against itself.
;;;
;;; It ships green and is a RATCHET: a nineteenth code, a dropped code, a region
;;; with no row and no stated reason, or a (region trigger) covered twice all
;;; fail here. The "read from the machine" half of 0034's code set-equal has no
;;; machine at Slice ⓪ and is Slice ⑤'s (asserted here against the eighteen
;;; alone); this file's header says so.
(import (rnrs)
        (byte-machine test harness)
        (byte-machine test http-error-table))

(harness-begin "unit.http-error-table")

;; --- helpers, pure -----------------------------------------------------------

(define (distinct xs)
  ;; order-preserving de-duplication; the tables are small.
  (let loop ((xs xs) (seen '()))
    (cond ((null? xs) (reverse seen))
          ((member (car xs) seen) (loop (cdr xs) seen))
          (else (loop (cdr xs) (cons (car xs) seen))))))

(define (has-duplicate? xs)
  (not (= (length xs) (length (distinct xs)))))

(define (subset? a b) (for-all (lambda (x) (member x b)) a))

(define (set-equal? a b)
  (and (subset? (distinct a) b) (subset? (distinct b) a)))

(define (sort-syms l)
  (list-sort (lambda (a b) (string<? (symbol->string a) (symbol->string b))) l))

(define (row-region r) (car r))
(define (row-trigger r) (cadr r))
(define (row-code r) (caddr r))
(define (row-position-kind r) (cadddr r))
(define (row-offset-rule r) (car (cddddr r)))
(define (row-production r) (cadr (cddddr r)))

(define (nonempty-string? s) (and (string? s) (> (string-length s) 0)))

;; The eighteen stable §21.4:1156-1173 codes, spelled here in spec order. This
;; is the oracle; the table's rows are checked against it, never the reverse.
(define catalog-21.4
  '(invalid-method
    invalid-target
    invalid-version
    invalid-line-ending
    invalid-header-name
    invalid-header-value
    duplicate-content-length
    invalid-content-length
    content-length-overflow
    duplicate-transfer-encoding
    unsupported-transfer-encoding
    framing-conflict
    invalid-chunk-size
    chunk-size-overflow
    invalid-chunk-extension
    invalid-chunk-ending
    forbidden-trailer
    unexpected-eof))

;; --- shape guards ------------------------------------------------------------

(harness-group "the table's shape (decision 0034 item 2)"
  (lambda ()
    (harness-case "there are eighteen §21.4 codes, no more, no fewer"
      (lambda ()
        (check-equal "eighteen codes spelled from §21.4" (length catalog-21.4) 18)
        (check "the eighteen are distinct" (not (has-duplicate? catalog-21.4)))))
    (harness-case "the regions are distinct and in stream order"
      (lambda ()
        (check "no region repeats" (not (has-duplicate? http-error-regions)))
        (check-equal "eighteen regions" (length http-error-regions) 18)))
    (harness-case "the three triggers are exactly §21.4:1175's three"
      (lambda ()
        (check-equal "triggers" (sort-syms http-error-triggers) '(boundary byte eof))))
    (harness-case "every row is a well-formed six-tuple over the declared domains"
      (lambda ()
        (for-each
         (lambda (r)
           (let ((label (string-append (symbol->string (row-region r)) "/"
                                        (symbol->string (row-trigger r)) "/"
                                        (symbol->string (row-code r)))))
             (check (string-append label ": six fields") (= (length r) 6))
             (check (string-append label ": region is declared")
                    (and (member (row-region r) http-error-regions) #t))
             (check (string-append label ": trigger is one of three")
                    (and (memq (row-trigger r) http-error-triggers) #t))
             (check (string-append label ": code is a symbol") (symbol? (row-code r)))
             (check (string-append label ": position-kind is byte, boundary or eof")
                    (and (memq (row-position-kind r) '(byte boundary eof)) #t))
             (check (string-append label ": offset-rule is a non-empty string")
                    (nonempty-string? (row-offset-rule r)))
             (check (string-append label ": production is a non-empty string")
                    (nonempty-string? (row-production r)))))
         http-error-rows)))
    (harness-case "every inapplicable cell is (region trigger reason) with a reason as data"
      (lambda ()
        (for-each
         (lambda (e)
           (let ((label (string-append (symbol->string (car e)) "/"
                                        (symbol->string (cadr e)))))
             (check (string-append label ": three fields") (= (length e) 3))
             (check (string-append label ": region is declared")
                    (and (member (car e) http-error-regions) #t))
             (check (string-append label ": trigger is one of three")
                    (and (memq (cadr e) http-error-triggers) #t))
             (check (string-append label ": reason is a non-empty string")
                    (nonempty-string? (caddr e)))))
         http-error-inapplicable)))))

;; --- totality row (a): the codes (decision 0034 item 3a) ---------------------

(harness-group "the code column is total over §21.4 (decision 0034 item 3a)"
  (lambda ()
    (harness-case "every row's code is one of the eighteen -- no fixture-invented code at Slice ⓪"
      (lambda ()
        (check "row codes ⊆ §21.4"
               (subset? (distinct (map row-code http-error-rows)) catalog-21.4))))
    (harness-case "the row codes contain all eighteen -- the §21.4:1154 floor"
      (lambda ()
        (check "§21.4 ⊆ row codes"
               (subset? catalog-21.4 (map row-code http-error-rows)))))
    (harness-case "at Slice ⓪ the union set-equals the eighteen (⑤ closes the read-from-machine half)"
      (lambda ()
        (check "union of row codes = the eighteen"
               (set-equal? (map row-code http-error-rows) catalog-21.4))))))

;; --- totality row (b): every region x trigger is covered exactly once --------

(harness-group "the region x trigger grid is total and partitioned (decision 0034 item 3b)"
  (lambda ()
    (harness-case "every (region trigger) has a row XOR an inapplicable reason"
      (lambda ()
        (for-each
         (lambda (region)
           (for-each
            (lambda (trigger)
              (let* ((label (string-append (symbol->string region) "/"
                                           (symbol->string trigger)))
                     (has-row (exists (lambda (r) (and (eq? (row-region r) region)
                                                       (eq? (row-trigger r) trigger)))
                                      http-error-rows))
                     (has-reason (exists (lambda (e) (and (eq? (car e) region)
                                                          (eq? (cadr e) trigger)))
                                         http-error-inapplicable)))
                (check (string-append label ": covered by a row or a reason")
                       (or has-row has-reason))
                (check (string-append label ": not covered by both")
                       (not (and has-row has-reason)))))
            http-error-triggers))
         http-error-regions)))
    (harness-case "every non-idle region carries an unexpected-eof row (§21.4:1175 EOF sentence)"
      (lambda ()
        (for-each
         (lambda (region)
           (unless (eq? region 'idle)
             (check (string-append (symbol->string region) ": has unexpected-eof on eof")
                    (exists (lambda (r) (and (eq? (row-region r) region)
                                             (eq? (row-trigger r) 'eof)
                                             (eq? (row-code r) 'unexpected-eof)))
                            http-error-rows))))
         http-error-regions)))
    (harness-case "idle's eof is a clean finish, not an error (decision 0037)"
      (lambda ()
        (check "idle has no eof row"
               (not (exists (lambda (r) (and (eq? (row-region r) 'idle)
                                             (eq? (row-trigger r) 'eof)))
                            http-error-rows)))
        (check "idle/eof carries its clean-finish reason as data"
               (exists (lambda (e) (and (eq? (car e) 'idle) (eq? (cadr e) 'eof)))
                       http-error-inapplicable))))))

;; --- the two rows Slice ⓪ decides with the grammar (design Appendix) ---------

(harness-group "the two grammar-decided rows (design Appendix)"
  (lambda ()
    (harness-case "forbidden-trailer is a `byte` at the colon, not a boundary"
      (lambda ()
        (let ((ft (filter (lambda (r) (eq? (row-code r) 'forbidden-trailer)) http-error-rows)))
          (check-equal "exactly one forbidden-trailer row" (length ft) 1)
          (check-equal "it is trailer-name/byte with byte position-kind"
                       (list (row-region (car ft)) (row-trigger (car ft)) (row-position-kind (car ft)))
                       '(trailer-name byte byte)))))
    (harness-case "framing-conflict is a genuine boundary, by contrast"
      (lambda ()
        (let ((fc (filter (lambda (r) (eq? (row-code r) 'framing-conflict)) http-error-rows)))
          (check-equal "exactly one framing-conflict row" (length fc) 1)
          (check-equal "it is header-crlf/boundary with boundary position-kind"
                       (list (row-region (car fc)) (row-trigger (car fc)) (row-position-kind (car fc)))
                       '(header-crlf boundary boundary)))))
    (harness-case "fixed-body and chunk-data reject nothing but EOF"
      (lambda ()
        (for-each
         (lambda (region)
           (check (string-append (symbol->string region) ": byte is inapplicable")
                  (exists (lambda (e) (and (eq? (car e) region) (eq? (cadr e) 'byte)))
                          http-error-inapplicable))
           (check (string-append (symbol->string region) ": boundary is inapplicable")
                  (exists (lambda (e) (and (eq? (car e) region) (eq? (cadr e) 'boundary)))
                          http-error-inapplicable))
           (check (string-append (symbol->string region) ": eof is unexpected-eof")
                  (exists (lambda (r) (and (eq? (row-region r) region)
                                           (eq? (row-trigger r) 'eof)
                                           (eq? (row-code r) 'unexpected-eof)))
                          http-error-rows)))
         '(fixed-body chunk-data))))))

;; --- §4.9 item 2: the fixture-region -> node-name map ------------------------

(harness-group "the fixture-region -> node-name map (§4.9 item 2, owner-approved)"
  (lambda ()
    (harness-case "the map covers exactly the declared regions, once each"
      (lambda ()
        (check "map keys = regions"
               (set-equal? (map car http-error-region-nodes) http-error-regions))
        (check "no region keyed twice"
               (not (has-duplicate? (map car http-error-region-nodes))))))
    (harness-case "at Slice ⓪ no node exists, so every region maps to the empty list"
      (lambda ()
        (check "every node list is empty"
               (for-all (lambda (kv) (null? (cdr kv))) http-error-region-nodes))))
    (harness-case "every declared node is in exactly one region (vacuous at ⓪, bites once nodes exist)"
      (lambda ()
        (let ((all-nodes (apply append (map cdr http-error-region-nodes))))
          (check "no node appears in two regions" (not (has-duplicate? all-nodes))))))))

(harness-finish)
