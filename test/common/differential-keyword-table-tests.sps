;;; interpreter ≡ generated over the keyword-table node (Milestone 11 Slice ①).
;;; The lowering is decision 0044's compact table walked by
;;; `byte-machine-keyword-step/v1`, NOT one dispatch state per prefix; the
;;; interpreter's kw-step is derived independently (decision 0015). This lane is
;;; the differential that catches a lowering or runtime-walk defect the
;;; interpreter-absolute lane (keyword-interpret-tests.sps) cannot see.
;;;
;;; Agreement alone cannot carry the lane -- a fold or walk mutation that hit
;;; both executors identically would leave a comparison green -- so every group
;;; but the exhaustive byte sweep also asserts the GENERATED side ABSOLUTELY
;;; against the brief's §7 criteria. The sweep's own value is coverage: every
;;; trie transition at every prefix, across all 256 next-bytes, in both the
;;; case-sensitive and case-insensitive tables, which no fixed tuple set stands
;;; in for.
(import (rnrs) (rnrs eval)
        (only (chezscheme) load)
        (byte-machine test harness)
        (byte-machine test keyword-table-machine)
        (byte-machine graph)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime)
        (byte-machine compile))

(harness-begin "differential.keyword-table")

(define tmpdir
  (let ((d (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")))
    (if (and d (not (string=? d ""))) d
        (assertion-violation 'differential-keyword-table
                             "BYTE_MACHINE_TEST_TMPDIR is unset" d))))

;; Emit, load and eval one fixture's generated library. As in the sequence-node
;; differential, the binding <name>-parser is this function's own, and the
;; library name (generated <name>) is drawn from the machine's own machine-name
;; -- the two agree because this fixture's `build` reuses the same symbol for
;; both, and `environment` raises loudly if a future fixture ever diverges them.
(define (generated-machine name machine)
  (let ((genfile (string-append tmpdir "/generated-" (symbol->string name) ".sls"))
        (binding (string->symbol (string-append (symbol->string name) "-parser"))))
    (call-with-port (open-file-output-port genfile (file-options no-fail))
      (lambda (p) (emit-machine (compile-machine machine '()) binding p)))
    (load genfile)
    (eval binding (environment (list 'generated name)))))

(define (str->bv s) (u8-list->bytevector (map char->integer (string->list s))))
(define (bytes->bv bs) (u8-list->bytevector bs))
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
(define (feed1-bytes cm bs)
  (let* ((bv (bytes->bv bs)) (p (make-parser cm '() #f))
         (r (parser-feed! p bv 0 (bytevector-length bv))))
    (rfields r p)))
;; Feed s in two chunks split at k, on machine.
(define (feed-split cm s k)
  (let* ((bv (str->bv s)) (n (bytevector-length bv)) (p (make-parser cm '() #f)))
    (parser-feed! p bv 0 k)
    (let ((r (parser-feed! p bv k n))) (rfields r p))))

(define cs-ref (make-interpreted-machine (verify-machine (make-keyword-table-machine))))
(define cs-gen (generated-machine 'kwtable (make-keyword-table-machine)))
(define ci-ref (make-interpreted-machine (verify-machine (make-keyword-table-ci-machine))))
(define ci-gen (generated-machine 'kwtableci (make-keyword-table-ci-machine)))

;; --- the §7 criteria, agreement AND generated-absolute (case-sensitive) ------
(harness-group "the brief criteria hold on the generated table and both lanes agree"
  (lambda ()
    (define cases
      ;; input . expected 7-tuple
      (list (cons "GET-PARAMETER " '(stopped 13 13 13 got-gp #f #f))
            (cons "GET " '(stopped 3 3 3 got-get #f #f))
            (cons "GETX" '(stopped 3 3 3 got-get #f #f))
            (cons "GET-X" '(error 4 4 4 reject unexpected-byte 4))
            (cons "closed " '(stopped 6 6 6 got-closed #f #f))
            (cons "close " '(stopped 5 5 5 got-close #f #f))
            (cons "closex" '(stopped 5 5 5 got-close #f #f))
            (cons "xyz" '(error 0 0 0 reject unexpected-byte 0))))
    (harness-case "each input matches its expected generated tuple and agrees with the interpreter"
      (lambda ()
        (let ((bad 'none) (ran 0))
          (for-each
           (lambda (c)
             (set! ran (+ ran 1))
             (let ((g (feed1 cs-gen (car c))) (i (feed1 cs-ref (car c))))
               (when (eq? bad 'none)
                 (cond ((not (equal? g (cdr c))) (set! bad (list 'gen (car c) g)))
                       ((not (equal? i g)) (set! bad (list 'disagree (car c) i g)))))))
           cases)
          (check-equal "no case misbehaved" bad 'none)
          (check-equal "all eight criteria cases ran" ran 8))))))

;; --- the per-table fold (decision 0045), agreement AND generated-absolute ----
(harness-group "the fold holds on the generated table and both lanes agree"
  (lambda ()
    (harness-case "the case-sensitive generated table refuses a lowercase method"
      (lambda ()
        (check-equal "gen" (feed1 cs-gen "get ") '(error 0 0 0 reject unexpected-byte 0))
        (check-equal "agree" (feed1 cs-ref "get ") (feed1 cs-gen "get "))))
    (harness-case "the case-insensitive generated table accepts every casing to the same target"
      (lambda ()
        (let ((bad 'none) (ran 0))
          (for-each
           (lambda (s)
             (set! ran (+ ran 1))
             (let ((g (feed1 ci-gen s)) (i (feed1 ci-ref s)))
               (when (eq? bad 'none)
                 (cond ((not (equal? g '(stopped 3 3 3 got-get #f #f))) (set! bad (list 'gen s g)))
                       ((not (equal? i g)) (set! bad (list 'disagree s i g)))))))
           '("GET " "get " "GeT " "gEt " "getX"))
          (check-equal "no casing misbehaved" bad 'none)
          (check-equal "all five casings ran" ran 5))))
    (harness-case "the fold keeps the long keyword and folds letters only (hyphen matches itself)"
      (lambda ()
        (check-equal "get-parameter" (feed1 ci-gen "get-parameter ") '(stopped 13 13 13 got-gp #f #f))
        (check-equal "Closed" (feed1 ci-gen "Closed ") '(stopped 6 6 6 got-closed #f #f))
        (check-equal "gExY no-matches at 2" (feed1 ci-gen "gExY") '(error 2 2 2 reject unexpected-byte 2))
        (check-equal "agree get-parameter" (feed1 ci-ref "get-parameter ") (feed1 ci-gen "get-parameter "))
        (check-equal "agree gExY" (feed1 ci-ref "gExY") (feed1 ci-gen "gExY"))))))

;; --- cross-feed resume (decision 0044: the compound current is resumable) -----
;; GET-PARAMETER split at every k accepts got-gp at stream-offset 13; the walk
;; survives a feed boundary at any depth. Generated-absolute at each split, and
;; agreement with the interpreter.
(harness-group "the walk resumes across a feed boundary at every depth"
  (lambda ()
    (define splits '((1 . 12) (2 . 11) (3 . 10) (4 . 9) (7 . 6) (10 . 3) (13 . 0)))
    (harness-case "each split accepts got-gp with the right final-slice consumed count in both lanes"
      (lambda ()
        (let ((bad 'none) (ran 0))
          (for-each
           (lambda (sp)
             (set! ran (+ ran 1))
             (let* ((k (car sp))
                    (want (list 'stopped (cdr sp) 13 13 'got-gp #f #f))
                    (g (feed-split cs-gen "GET-PARAMETER " k))
                    (i (feed-split cs-ref "GET-PARAMETER " k)))
               (when (eq? bad 'none)
                 (cond ((not (equal? g want)) (set! bad (list 'gen k g)))
                       ((not (equal? i g)) (set! bad (list 'disagree k i g)))))))
           splits)
          (check-equal "no split misbehaved" bad 'none)
          (check-equal "all seven splits ran" ran 7))))))

;; --- exhaustive byte sweep over every trie prefix, both tables ---------------
;; For each prefix of each keyword (the trie's live paths) and every 0..255 next
;; byte, the interpreter and the generated table must agree. Coverage is the
;; point: every transition, present and absent, in both fold modes.
(harness-group "interpreter and generated agree on every next-byte at every prefix"
  (lambda ()
    (define (string->bytes s) (map char->integer (string->list s)))
    (define (take-n l k) (if (= k 0) '() (cons (car l) (take-n (cdr l) (- k 1)))))
    (define (prefixes-of bs)
      (let loop ((k 0) (acc '()))
        (if (> k (length bs)) (reverse acc)
            (loop (+ k 1) (cons (take-n bs k) acc)))))
    (define all-prefixes
      ;; every prefix (incl. empty and full) of every keyword, deduplicated
      (fold-left
       (lambda (acc kw)
         (fold-left (lambda (a p) (if (member p a) a (cons p a))) acc
                    (prefixes-of (string->bytes (car kw)))))
       '() keyword-table-keywords))
    (harness-case "every (table, prefix, next-byte) drive agrees, and the sweep is complete"
      (lambda ()
        (let ((bad 'none) (drives 0))
          (for-each
           (lambda (pair)
             (let ((ref (car pair)) (gen (cdr pair)))
               (for-each
                (lambda (prefix)
                  (let loop ((b 0))
                    (when (< b 256)
                      (let ((i (feed1-bytes ref (append prefix (list b))))
                            (g (feed1-bytes gen (append prefix (list b)))))
                        (unless (equal? i g)
                          (when (eq? bad 'none) (set! bad (list prefix b i g))))
                        (set! drives (+ drives 1))
                        (loop (+ b 1))))))
                all-prefixes)))
           (list (cons cs-ref cs-gen) (cons ci-ref ci-gen)))
          (check-equal "no (table prefix byte) disagreed" bad 'none)
          ;; 20 distinct prefixes x 256 bytes x 2 tables = 10240 drives. The
          ;; prefix count is pinned to a measured literal, not recomputed from
          ;; all-prefixes: 20 = empty + GET-path(3) + GET-PARAMETER-tail(10) +
          ;; close-path(5) + closed-tail(1), the GET and close paths shared.
          (check-equal "the prefix set is the whole trie" (length all-prefixes) 20)
          (check-equal "the sweep ran every drive" drives (* 20 256 2)))))))

;; --- decision 0045 item 5: the flag is fingerprint-visible -------------------
;; Two tables differing ONLY in case-insensitive? must compile to different
;; parsers. The two fixtures carry different machine-names, so their renders
;; would differ from the name alone; to isolate the flag this builds two tables
;; with the SAME name, same keyword set, same targets -- everything but the
;; flag identical -- and shows the rendered bytes still differ. If they did not,
;; a case-insensitive table and a case-sensitive one over the same keywords
;; would share a fingerprint and be indistinguishable declarations.
(harness-group "the case-insensitive flag alone moves the rendered output"
  (lambda ()
    (define (build-flagged ci?)
      (make-machine 'flagtable 'table '() '() '()
        (list (make-error-declaration 'default-eof 'eof "unexpected end of input" #f)
              (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f)
              (make-error-declaration 'incomplete 'truncated-keyword "incomplete keyword" #f))
        (list (make-keyword-table-node 'table
                (map (lambda (p)
                       (make-keyword-entry (map char->integer (string->list (car p))) (cdr p) #f))
                     keyword-table-keywords)
                (make-edge 'reject 'reexecute) 'eof-incomplete ci? #f)
              (make-stop-node 'got-get #f) (make-stop-node 'got-gp #f)
              (make-stop-node 'got-close #f) (make-stop-node 'got-closed #f)
              (make-error-node 'eof-incomplete 'incomplete #f)
              (make-error-node 'reject 'rejected #f))
        'default-eof #f))
    (harness-case "same name, same keywords: the flag alone still changes the bytes"
      (lambda ()
        (let ((cs-bytes (render-machine (compile-machine (build-flagged #f) '()) 'flagtable))
              (ci-bytes (render-machine (compile-machine (build-flagged #t) '()) 'flagtable)))
          (check "the two renders differ on the flag alone" (not (equal? cs-bytes ci-bytes))))))))

(harness-finish)
