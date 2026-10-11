;;; interpreter ≡ generated over the keyword-table node. The lowering is a
;;; compact table walked by `byte-machine-keyword-step/v1`, NOT one dispatch
;;; state per prefix; the interpreter's kw-step is derived independently. This
;;; lane is the differential that catches a lowering or runtime-walk defect the
;;; interpreter-absolute lane (keyword-interpret-tests.sps) cannot see.
;;;
;;; Agreement alone cannot carry the lane -- a fold or walk mutation that hit
;;; both executors identically would leave a comparison green -- so every group
;;; but the exhaustive byte sweep also asserts the GENERATED side ABSOLUTELY
;;; against expected tuples. The sweep's own value is coverage: every trie
;;; transition at every prefix, across all 256 next-bytes, in both the
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

;; --- the keyword-match cases, agreement AND generated-absolute (case-sensitive)
(harness-group "the keyword-match cases hold on the generated table and both lanes agree"
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
          (check-equal "all eight keyword-match cases ran" ran 8))))))

;; --- the per-table fold, agreement AND generated-absolute -------------------
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

;; --- cross-feed resume (the compound current is resumable) ------------------
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

;; --- the case-insensitive? flag is fingerprint-visible ----------------------
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

;; --- the error position-kind is compared across executors --------------------
;; interpret.sls (the comment above `declaration-index`) lists position-kind
;; among the fields "required to match across executors", but the 7-tuple
;; above excludes it, so a keyword-step position-kind lowering defect (the
;; no-match else branch's `byte`) would agree on every other field and slip.
;; This group compares it directly, both lanes, and asserts the generated value
;; absolutely.
(define (err-pk cm s)
  (let* ((bv (str->bv s)) (p (make-parser cm '() #f))
         (r (parser-feed! p bv 0 (bytevector-length bv))) (e (parser-result-error r)))
    (and (parser-error? e) (parser-error-position-kind e))))
(define (err-pk-finish cm s)
  (let ((p (make-parser cm '() #f)))
    (unless (= 0 (string-length s)) (parser-feed! p (str->bv s) 0 (string-length s)))
    (let* ((r (parser-finish! p)) (e (parser-result-error r)))
      (and (parser-error? e) (parser-error-position-kind e)))))
(harness-group "the error position-kind agrees across executors and is absolute"
  (lambda ()
    (harness-case "a no-match reject reports position-kind byte on the generated table and both agree"
      (lambda ()
        (check-equal "generated" (err-pk cs-gen "xyz") 'byte)
        (check-equal "agree" (err-pk cs-ref "xyz") (err-pk cs-gen "xyz"))))
    (harness-case "an EOF mid-table reports position-kind eof on the generated table and both agree"
      (lambda ()
        (check-equal "generated" (err-pk-finish cs-gen "GET") 'eof)
        (check-equal "agree" (err-pk-finish cs-ref "GET") (err-pk-finish cs-gen "GET"))))))

;; --- the no-match edge's advance mode ----------------------------------------
;; The fixtures above use a reexecute no-match; this group covers the walk's
;; advance arm (it consumes the offending byte and reports `boundary` after it).
;; A table identical but for the no-match mode isolates that arm on both lanes.
(define (build-mode name mode)
  (make-machine name 'table '() '() '()
    (list (make-error-declaration 'default-eof 'eof "unexpected end of input" #f)
          (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f)
          (make-error-declaration 'incomplete 'truncated-keyword "incomplete keyword at end of input" #f))
    (list (make-keyword-table-node 'table
            (map (lambda (p) (make-keyword-entry (map char->integer (string->list (car p))) (cdr p) #f))
                 keyword-table-keywords)
            (make-edge 'reject mode) 'eof-incomplete #f #f)
          (make-stop-node 'got-get #f) (make-stop-node 'got-gp #f)
          (make-stop-node 'got-close #f) (make-stop-node 'got-closed #f)
          (make-error-node 'eof-incomplete 'incomplete #f)
          (make-error-node 'reject 'rejected #f))
    'default-eof #f))
(harness-group "the no-match edge's advance mode consumes the byte and reports boundary"
  (lambda ()
    (define adv-ref (make-interpreted-machine (verify-machine (build-mode 'advkw 'advance))))
    (define adv-gen (generated-machine 'advkw (build-mode 'advkw 'advance)))
    (harness-case "a non-keyword byte advances (consumed 1) and the reject is at the boundary after it, both lanes"
      (lambda ()
        (check-equal "generated" (feed1 adv-gen "xyz") '(error 1 1 1 reject unexpected-byte 1))
        (check-equal "generated position-kind" (err-pk adv-gen "xyz") 'boundary)
        (check-equal "agree tuple" (feed1 adv-ref "xyz") (feed1 adv-gen "xyz"))
        (check-equal "agree position-kind" (err-pk adv-ref "xyz") (err-pk adv-gen "xyz"))))
    (harness-case "a matched keyword still accepts under an advance no-match (the mode is the no-match edge's, not the keyword's)"
      (lambda ()
        (check-equal "generated" (feed1 adv-gen "GET ") '(stopped 3 3 3 got-get #f #f))
        (check-equal "agree" (feed1 adv-ref "GET ") (feed1 adv-gen "GET "))))))

;; --- the default EOF route (the reached-declaration credit list) -------------
;; A keyword table whose eof-target is #f takes the machine's default EOF error;
;; that makes the table the sole consumer of the default-eof declaration, so the
;; emitter must credit the keyword-table kind in its reached-declaration walk or
;; the declaration is filtered out of the errs table and render-machine raises on
;; a machine the verifier accepted. Rendering, loading and running such a
;; machine exercises that credit.
(define (build-default-eof)
  (make-machine 'defeofkw 'table '() '() '()
    (list (make-error-declaration 'default-eof 'eof "unexpected end of input" #f)
          (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))
    (list (make-keyword-table-node 'table
            (map (lambda (p) (make-keyword-entry (map char->integer (string->list (car p))) (cdr p) #f))
                 keyword-table-keywords)
            (make-edge 'reject 'reexecute) #f #f #f)   ; eof-target #f -> machine default-eof
          (make-stop-node 'got-get #f) (make-stop-node 'got-gp #f)
          (make-stop-node 'got-close #f) (make-stop-node 'got-closed #f)
          (make-error-node 'reject 'rejected #f))
    'default-eof #f))
(harness-group "a keyword table on the default EOF route renders, loads and runs"
  (lambda ()
    (harness-case "the default-eof machine renders and its EOF route takes the machine default error"
      (lambda ()
        (let* ((g (generated-machine 'defeofkw (build-default-eof)))
               (p (make-parser g '() #f)))
          (parser-feed! p (str->bv "GET") 0 3)
          (let ((r (parser-finish! p)))
            (check-equal "eof error" (parser-result-status r) 'error)
            (check-equal "the machine default eof code" (parser-error-code (parser-result-error r)) 'eof)
            (check-equal "position kind eof" (parser-error-position-kind (parser-result-error r)) 'eof)))))))

;; --- the prefix read in place -----------------------------------------------
;; The runtime walk compares each keyword, in one pass, against the prefix as two
;; parts -- the `path` a previous feed parked, then this feed's bytes where they
;; lie -- instead of building one list, and stops where the longest shared
;; prefix ends. The shared fixture cannot tell most wrong versions of that apart:
;; its keywords never agree after a byte on which they differ, so a walk that
;; stopped comparing its PARKED bytes still picks the right one; and none of its
;; inputs runs on past a completed keyword that is no other's prefix. GET and SET
;; agree on every byte but the first, so a walk resumed after that byte has only
;; the parked byte to choose by. Each case below separates one Pass 67 mutant
;; from its neighbours; two drive the op directly, for answers no executor
;; reaches on its own.
(define (build-shared-tail)
  (make-machine 'tailkw 'table '() '() '()
    (list (make-error-declaration 'default-eof 'eof "unexpected end of input" #f)
          (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f)
          (make-error-declaration 'incomplete 'truncated-keyword "incomplete keyword at end of input" #f))
    (list (make-keyword-table-node 'table
            (map (lambda (p) (make-keyword-entry (map char->integer (string->list (car p))) (cdr p) #f))
                 '(("GET" . got-get) ("SET" . got-set)))
            (make-edge 'reject 'reexecute) 'eof-incomplete #f #f)
          (make-stop-node 'got-get #f) (make-stop-node 'got-set #f)
          (make-error-node 'eof-incomplete 'incomplete #f)
          (make-error-node 'reject 'rejected #f))
    'default-eof #f))
(harness-group "the walk reads its parked prefix and this feed's bytes in place"
  (lambda ()
    (define tail-ref (make-interpreted-machine (verify-machine (build-shared-tail))))
    (define tail-gen (generated-machine 'tailkw (build-shared-tail)))
    (harness-case "resumed after its first byte, SET is chosen by the parked byte alone"
      (lambda ()
        (check-equal "generated SET|ET" (feed-split tail-gen "SET " 1) '(stopped 2 3 3 got-set #f #f))
        (check-equal "generated GET|ET" (feed-split tail-gen "GET " 1) '(stopped 2 3 3 got-get #f #f))
        (check-equal "agree SET|ET" (feed-split tail-ref "SET " 1) (feed-split tail-gen "SET " 1))
        (check-equal "agree GET|ET" (feed-split tail-ref "GET " 1) (feed-split tail-gen "GET " 1))))
    (harness-case "a completed keyword that prefixes no other stops the walk at its end"
      (lambda ()
        (check-equal "generated GETXY" (feed1 cs-gen "GETXY ") '(stopped 3 3 3 got-get #f #f))
        (check-equal "agree GETXY" (feed1 cs-ref "GETXY ") (feed1 cs-gen "GETXY "))))
    ;; Each input below separates one wrong split from its neighbours, which the
    ;; rows above leave indistinguishable (measured against the Pass 67 mutants).
    (harness-case "resumed two bytes in, a wrong third byte is refused where it stands"
      (lambda ()
        ;; The parked SE counts toward the prefix's length: a walk that counted
        ;; only this feed's bytes would lag two bytes behind and refuse at Y.
        (check-equal "generated SE|XY" (feed-split tail-gen "SEXY " 2) '(error 0 2 2 reject unexpected-byte 2))
        (check-equal "agree SE|XY" (feed-split tail-ref "SEXY " 2) (feed-split tail-gen "SEXY " 2))))
    (harness-case "a feed that ends mid-table parks the byte it consumed"
      (lambda ()
        ;; G parked, then GET: GG begins no keyword. A walk that parked nothing
        ;; would start afresh and take GET.
        (check-equal "generated G|GET" (feed-split cs-gen "GGET " 1) '(error 0 1 1 reject unexpected-byte 1))
        (check-equal "agree G|GET" (feed-split cs-ref "GGET " 1) (feed-split cs-gen "GGET " 1))))
    (harness-case "a feed that starts part-way into its bytevector walks from its own start"
      (lambda ()
        (define (feed-from cm s from)
          (let* ((bv (str->bv s)) (p (make-parser cm '() #f))
                 (r (parser-feed! p bv from (bytevector-length bv))))
            (rfields r p)))
        (check-equal "generated zz|GET" (feed-from cs-gen "zzGET " 2) '(stopped 3 5 3 got-get #f #f))
        (check-equal "agree zz|GET" (feed-from cs-ref "zzGET " 2) (feed-from cs-gen "zzGET " 2))))
    (harness-case "a case-insensitive walk folds the bytes it parked, not only the ones it is fed"
      (lambda ()
        ;; CL parked in capitals against the table's lower-case close/closed.
        (check-equal "generated CL|OSED" (feed-split ci-gen "CLOSED " 2) '(stopped 4 6 6 got-closed #f #f))
        (check-equal "agree CL|OSED" (feed-split ci-ref "CLOSED " 2) (feed-split ci-gen "CLOSED " 2))
        ;; And the op directly, fed from its bytevector's start: every end-to-end
        ;; resume above also reddens when the parked bytes are DROPPED, reversed
        ;; or misread, identically; only here does an unfolded parked byte alone
        ;; change the answer.
        (check-equal "op G|et"
                     (byte-machine-keyword-step/v1 '(((103 101 116) . 1)) '(9 . reexecute) #t
                                                   '(71) (str->bv "et ") 0 3)
                     '(jump 1 2 byte))))
    (harness-case "a parked prefix that begins no keyword stops the walk where it resumed"
      (lambda ()
        ;; The op directly, since no executor parks such a prefix: the walk never
        ;; stops before the length it resumed at, so it refuses at pos rather
        ;; than reporting a position behind the feed.
        (check-equal "op X|GET"
                     (byte-machine-keyword-step/v1 '(((71 69 84) . 1)) '(9 . reexecute) #f
                                                   '(88) (str->bv "zGET") 1 4)
                     '(jump 9 1 byte))))))

(harness-finish)
