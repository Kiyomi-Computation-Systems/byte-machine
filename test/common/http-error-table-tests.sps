;;; The oracle for the fixture-state -> expected-error table.
;;;
;;; The table (test/support/harness/byte-machine/test/http-error-table.sls)
;;; states, for every HTTP fixture region and trigger, the error code produced
;;; and where. This lane holds it to two totality rows and the shape guards, WITH
;;; THE EIGHTEEN HTTP ERROR CODES SPELLED OUT HERE so a change to the table's own
;;; copy is caught against the specification, not against itself.
;;;
;;; It is a RATCHET: a nineteenth code, a dropped code, a region with no row and
;;; no stated reason, or a (region trigger) covered twice all fail here. The code
;;; set is asserted here against the eighteen alone; that the machine produces
;;; each code is http-close-tests.sps's malformed sweep.
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

;; The eighteen stable HTTP error codes, in specification order. This
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

(harness-group "the table's shape"
  (lambda ()
    (harness-case "there are eighteen HTTP error codes, no more, no fewer"
      (lambda ()
        (check-equal "eighteen codes in the catalog" (length catalog-21.4) 18)
        (check "the eighteen are distinct" (not (has-duplicate? catalog-21.4)))))
    (harness-case "the regions are distinct and in stream order"
      (lambda ()
        (check "no region repeats" (not (has-duplicate? http-error-regions)))
        (check-equal "eighteen regions" (length http-error-regions) 18)))
    (harness-case "the three triggers are exactly byte, boundary and eof"
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

;; --- totality row (a): the codes --------------------------------------------

(harness-group "the code column is total over the eighteen HTTP error codes"
  (lambda ()
    (harness-case "every row's code is one of the eighteen -- no fixture-invented code"
      (lambda ()
        (check "row codes ⊆ the eighteen"
               (subset? (distinct (map row-code http-error-rows)) catalog-21.4))))
    (harness-case "the row codes contain all eighteen"
      (lambda ()
        (check "the eighteen ⊆ row codes"
               (subset? catalog-21.4 (map row-code http-error-rows)))))
    (harness-case "the union of the row codes set-equals the eighteen"
      (lambda ()
        (check "union of row codes = the eighteen"
               (set-equal? (map row-code http-error-rows) catalog-21.4))))))

;; --- totality row (b): every region x trigger is covered exactly once --------

(harness-group "the region x trigger grid is total and partitioned"
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
    (harness-case "every non-idle region carries an unexpected-eof row"
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
    (harness-case "idle's eof is a clean finish, not an error"
      (lambda ()
        (check "idle has no eof row"
               (not (exists (lambda (r) (and (eq? (row-region r) 'idle)
                                             (eq? (row-trigger r) 'eof)))
                            http-error-rows)))
        (check "idle/eof carries its clean-finish reason as data"
               (exists (lambda (e) (and (eq? (car e) 'idle) (eq? (cadr e) 'eof)))
                       http-error-inapplicable))))))

;; --- the two rows decided by the grammar -------------------------------------

(harness-group "the two grammar-decided rows"
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

;; --- the fixture-region -> node-name map -------------------------------------

(harness-group "the fixture-region -> node-name map"
  (lambda ()
    (harness-case "the map covers exactly the declared regions, once each"
      (lambda ()
        (check "map keys = regions"
               (set-equal? (map car http-error-region-nodes) http-error-regions))
        (check "no region keyed twice"
               (not (has-duplicate? (map car http-error-region-nodes))))))
    (harness-case "the fixture declares no nodes, so every region maps to the empty list"
      (lambda ()
        (check "every node list is empty"
               (for-all (lambda (kv) (null? (cdr kv))) http-error-region-nodes))))
    (harness-case "every declared node is in exactly one region (vacuous while the fixture declares no nodes)"
      (lambda ()
        (let ((all-nodes (apply append (map cdr http-error-region-nodes))))
          (check "no node appears in two regions" (not (has-duplicate? all-nodes))))))))

(harness-finish)
