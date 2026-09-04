;;; Round-trip tests for the private descriptor IR: construct the pieces of the
;;; one-byte machine and read every field back. A name missing from
;;; (byte-machine private ir) is a load failure, not a silent gap.
(import (rnrs)
        (byte-machine test harness)
        (byte-machine private ir)
        (byte-machine private conditions))

(harness-begin "unit.ir")

;; house convention (conditions.sls header): tests compare the code and who,
;; never rendered text -- and, per Fix wave 1, the detail too: two distinct
;; guards can share a who/code pair (or a code/detail pair) and only the third
;; field tells them apart, so a check-raises that stops at
;; byte-machine-contract-condition? alone would not notice a copy-pasted `who`
;; or `detail`. contract-violation? asserts all three; matcher-contract-
;; violation? is the detail='matcher case most call sites want, kept as a
;; named alias rather than inlining 'matcher everywhere.
(define (contract-violation? who detail)
  (lambda (e)
    (and (byte-machine-contract-condition? e)
         (eq? (byte-machine-contract-condition-code e) 'invalid-argument)
         (eq? (byte-machine-contract-condition-who e) who)
         (eq? (byte-machine-contract-condition-detail e) detail))))
(define (matcher-contract-violation? who) (contract-violation? who 'matcher))

(harness-group "matchers and edges"
  (lambda ()
    (harness-case "an exact-byte matcher carries its byte"
      (lambda ()
        (check-equal "byte" (exact-byte-matcher-byte (make-exact-byte-matcher 0)) 0)))
    (harness-case "an edge carries its target and mode"
      (lambda ()
        (let ((e (make-edge 'stop 'advance)))
          (check-equal "target" (edge-target e) 'stop)
          (check-equal "mode" (edge-mode e) 'advance))))))

(harness-group "constructor local-shape validation"
  (lambda ()
    (harness-case "a byte above 255 is rejected"
      (lambda ()
        (check-raises "out of range"
                      byte-machine-contract-condition?
                      (lambda () (make-exact-byte-matcher 256)))))
    (harness-case "an unknown edge mode is rejected"
      (lambda ()
        (check-raises "bad mode"
                      byte-machine-contract-condition?
                      (lambda () (make-edge 'stop 'teleport)))))
    (harness-case "a dispatch node cannot be built without an edge fallback"
      (lambda ()
        (check-raises "no fallback"
                      byte-machine-contract-condition?
                      (lambda () (make-byte-dispatch-node 'start '() 'not-an-edge #f #f)))))))

(harness-group "the one-byte machine descriptor"
  (lambda ()
    (harness-case "the machine reads back its entry, nodes, and default eof error name"
      (lambda ()
        (let* ((accept-edge (make-edge 'stop 'advance))
               (accept-case (make-byte-case (make-exact-byte-matcher 0) accept-edge #f))
               (reject-edge (make-edge 'reject 'reexecute))
               (start (make-byte-dispatch-node 'start (list accept-case) reject-edge #f #f))
               (stop (make-stop-node 'stop #f))
               (eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
               (rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))
               (reject (make-error-node 'reject 'rejected #f))
               (m (make-machine 'one-byte 'start '() '() '() (list eof-decl rej-decl)
                                (list start stop reject) 'default-eof #f)))
          (check-equal "entry" (machine-entry m) 'start)
          (check-equal "node count" (length (machine-nodes m)) 3)
          (check-equal "default eof error name" (machine-default-eof-error m) 'default-eof)
          (check-equal "error node references the reject declaration by name"
                       (error-node-error-name reject) 'rejected)
          (check-equal "start fallback target"
                       (edge-target (byte-dispatch-node-fallback start)) 'reject))))))

(harness-group "matcher canonicalization"
  (lambda ()
    (harness-case "an exact-byte matcher canonicalizes to its one-element set"
      (lambda ()
        (check-equal "set" (matcher-bytes (make-exact-byte-matcher 7)) '(7))))
    (harness-case "the low and high ends of the byte universe canonicalize"
      (lambda ()
        (check-equal "zero" (matcher-bytes (make-exact-byte-matcher 0)) '(0))
        (check-equal "255" (matcher-bytes (make-exact-byte-matcher 255)) '(255))))
    (harness-case "canonicalizing a foreign vector is a contract violation"
      (lambda ()
        (check-raises "refused"
                      (matcher-contract-violation? 'matcher-bytes)
                      (lambda () (matcher-bytes (make-edge 'stop 'advance))))))))

(harness-group "the exact-byte accessor is tag-guarded"
  (lambda ()
    (harness-case "the exact-byte accessor refuses a foreign vector"
      (lambda ()
        (check-raises "refused"
                      (matcher-contract-violation? 'exact-byte-matcher-byte)
                      (lambda () (exact-byte-matcher-byte (make-edge 'stop 'advance))))))))

;; Same guard class as above, one instance per class-matcher accessor
;; (Important 1, Fix wave 1): an unguarded (vector-ref m N) on a matcher of
;; another kind reads the wrong slot and fails far away -- inside arithmetic
;; or a sort predicate -- rather than at the contract boundary. Each accessor
;; gets its own case because each is its own guard at its own source site.
(harness-group "the class-matcher accessors are tag-guarded"
  (lambda ()
    (harness-case "byte-set-matcher-bytes refuses a foreign vector"
      (lambda ()
        (check-raises "refused"
                      (matcher-contract-violation? 'byte-set-matcher-bytes)
                      (lambda () (byte-set-matcher-bytes (make-edge 'stop 'advance))))))
    (harness-case "byte-range-matcher-low refuses a foreign vector"
      (lambda ()
        (check-raises "refused"
                      (matcher-contract-violation? 'byte-range-matcher-low)
                      (lambda () (byte-range-matcher-low (make-edge 'stop 'advance))))))
    (harness-case "byte-range-matcher-high refuses a foreign vector"
      (lambda ()
        (check-raises "refused"
                      (matcher-contract-violation? 'byte-range-matcher-high)
                      (lambda () (byte-range-matcher-high (make-edge 'stop 'advance))))))
    (harness-case "byte-complement-matcher-matcher refuses a foreign vector"
      (lambda ()
        (check-raises "refused"
                      (matcher-contract-violation? 'byte-complement-matcher-matcher)
                      (lambda () (byte-complement-matcher-matcher (make-edge 'stop 'advance))))))))

(harness-group "the three class matchers canonicalize"
  (lambda ()
    (harness-case "a byte set canonicalizes ascending and de-duplicated"
      (lambda ()
        (check-equal "set" (matcher-bytes (make-byte-set-matcher '(254 1 0 1 255 2)))
                     '(0 1 2 254 255))))
    (harness-case "a byte set keeps the caller's order in its own accessor"
      (lambda ()
        (check-equal "as given" (byte-set-matcher-bytes (make-byte-set-matcher '(254 1 0)))
                     '(254 1 0))))
    (harness-case "a range canonicalizes to every byte from low to high inclusive"
      (lambda ()
        (check-equal "digits" (matcher-bytes (make-byte-range-matcher 48 57))
                     '(48 49 50 51 52 53 54 55 56 57))
        (check-equal "count" (length (matcher-bytes (make-byte-range-matcher 0 255))) 256)))
    (harness-case "a range with low = high is a legal one-element set"
      (lambda ()
        (check-equal "single" (matcher-bytes (make-byte-range-matcher 9 9)) '(9))))
    (harness-case "a complement is the universe minus the inner set"
      (lambda ()
        (let ((c (matcher-bytes (make-byte-complement-matcher (make-byte-set-matcher '(10 13))))))
          (check-equal "count" (length c) 254)
          (check-equal "first" (car c) 0)
          (check "10 excluded" (not (memv 10 c)))
          (check "13 excluded" (not (memv 13 c)))
          (check "255 present" (and (memv 255 c) #t)))))
    (harness-case "complements nest: complementing twice returns the inner set"
      (lambda ()
        (check-equal "digits again"
                     (matcher-bytes
                      (make-byte-complement-matcher
                       (make-byte-complement-matcher (make-byte-range-matcher 48 57))))
                     '(48 49 50 51 52 53 54 55 56 57))))
    (harness-case "the complement of the full universe is the empty set"
      (lambda ()
        (check-equal "vacuous"
                     (matcher-bytes
                      (make-byte-complement-matcher (make-byte-range-matcher 0 255)))
                     '())))))

(harness-group "degenerate shapes are constructor contract violations (decision 0017)"
  (lambda ()
    (harness-case "an empty byte set is rejected"
      (lambda ()
        (check-raises "empty set"
                      (contract-violation? 'make-byte-set-matcher 'bytes)
                      (lambda () (make-byte-set-matcher '())))))
    (harness-case "a byte set holding a non-byte is rejected"
      (lambda ()
        (check-raises "out of range"
                      (contract-violation? 'make-byte-set-matcher 'bytes)
                      (lambda () (make-byte-set-matcher '(0 256))))))
    (harness-case "a range with low greater than high is rejected"
      (lambda ()
        (check-raises "reversed"
                      (contract-violation? 'make-byte-range-matcher 'range)
                      (lambda () (make-byte-range-matcher 9 8)))))
    (harness-case "a range rejects a non-byte low"
      (lambda ()
        (check-raises "low out of range"
                      (contract-violation? 'make-byte-range-matcher 'low)
                      (lambda () (make-byte-range-matcher 256 255)))))
    (harness-case "a range rejects a non-byte high"
      (lambda ()
        (check-raises "high out of range"
                      (contract-violation? 'make-byte-range-matcher 'high)
                      (lambda () (make-byte-range-matcher 0 256)))))
    (harness-case "a complement of something that is not a matcher is rejected"
      (lambda ()
        (check-raises "not a matcher"
                      (matcher-contract-violation? 'make-byte-complement-matcher)
                      (lambda () (make-byte-complement-matcher (make-edge 'stop 'advance))))))
    (harness-case "duplicate bytes inside one set are NOT a constructor error"
      (lambda ()
        (check "constructs" (byte-set-matcher? (make-byte-set-matcher '(3 3 3))))))))

(harness-group "ascii-bytes (parent §9.1:299)"
  (lambda ()
    (harness-case "a string becomes its code points in string order"
      (lambda ()
        (check-equal "GET" (ascii-bytes "GET") '(71 69 84))))
    (harness-case "repeated characters are kept, not de-duplicated"
      (lambda ()
        (check-equal "aa" (ascii-bytes "aa") '(97 97))))
    (harness-case "the empty string yields the empty list, which is not a matcher"
      (lambda ()
        (check-equal "empty" (ascii-bytes "") '())
        (check-raises "and cannot become a byte set"
                      (contract-violation? 'make-byte-set-matcher 'bytes)
                      (lambda () (make-byte-set-matcher (ascii-bytes ""))))))
    (harness-case "a non-ASCII character is rejected"
      (lambda ()
        (check-raises "non-ascii"
                      (contract-violation? 'ascii-bytes 'non-ascii)
                      (lambda () (ascii-bytes "caf\xe9;")))))
    (harness-case "code point 127 is ASCII and 128 is not"
      (lambda ()
        (check-equal "delete" (ascii-bytes (string (integer->char 127))) '(127))
        (check-raises "128"
                      (contract-violation? 'ascii-bytes 'non-ascii)
                      (lambda () (ascii-bytes (string (integer->char 128)))))))
    (harness-case "a non-string is rejected"
      (lambda ()
        (check-raises "not a string"
                      (contract-violation? 'ascii-bytes 'string)
                      (lambda () (ascii-bytes 42)))))))

(harness-group "make-byte-case accepts every matcher kind"
  (lambda ()
    (harness-case "a byte-set case constructs and reads back its matcher"
      (lambda ()
        (let* ((m (make-byte-set-matcher '(1 2)))
               (c (make-byte-case m (make-edge 'stop 'advance) #f)))
          (check "byte-set matcher" (byte-set-matcher? (byte-case-matcher c))))))
    (harness-case "a range case and a complement case construct"
      (lambda ()
        (check "range" (byte-case? (make-byte-case (make-byte-range-matcher 1 2)
                                                   (make-edge 'stop 'advance) #f)))
        (check "complement"
               (byte-case? (make-byte-case
                            (make-byte-complement-matcher (make-exact-byte-matcher 0))
                            (make-edge 'stop 'advance) #f)))))
    (harness-case "an edge handed in as a matcher is still refused"
      (lambda ()
        (check-raises "not a matcher"
                      (matcher-contract-violation? 'make-byte-case)
                      (lambda () (make-byte-case (make-edge 'stop 'advance)
                                                 (make-edge 'stop 'advance) #f)))))))

(harness-group "the sequence node and its cases (parent §9.1:297-298)"
  (lambda ()
    (harness-case "a sequence case carries its bytes and target"
      (lambda ()
        (let ((c (make-sequence-case '(1 2 3) 'stop #f)))
          (check "is a sequence case" (sequence-case? c))
          (check-equal "bytes" (sequence-case-bytes c) '(1 2 3))
          (check-equal "target" (sequence-case-target c) 'stop))))
    (harness-case "the bytes accessor returns a copy, not the stored chain"
      (lambda ()
        (let ((c (make-sequence-case '(1 2 3) 'stop #f)))
          (check "not eq" (not (eq? (sequence-case-bytes c) (sequence-case-bytes c))))
          (check-equal "still equal" (sequence-case-bytes c) '(1 2 3)))))
    (harness-case "a length-1 sequence is legal (decision 0017 point 2)"
      (lambda ()
        (check-equal "single" (sequence-case-bytes (make-sequence-case '(7) 'stop #f)) '(7))))
    (harness-case "duplicate bytes inside one alternative are legal"
      (lambda ()
        (check-equal "aa" (sequence-case-bytes (make-sequence-case '(97 97) 'stop #f)) '(97 97))))
    (harness-case "an empty sequence is rejected (decision 0017 point 1)"
      (lambda ()
        (check-raises "empty" (contract-violation? 'make-sequence-case 'bytes)
                      (lambda () (make-sequence-case '() 'stop #f)))))
    (harness-case "a non-byte inside a sequence is rejected"
      (lambda ()
        (check-raises "256" (contract-violation? 'make-sequence-case 'bytes)
                      (lambda () (make-sequence-case '(1 256) 'stop #f)))))
    (harness-case "a non-symbol target is rejected"
      (lambda ()
        (check-raises "target" (contract-violation? 'make-sequence-case 'target)
                      (lambda () (make-sequence-case '(1) 42 #f)))))
    (harness-case "a sequence node carries its cases, mismatch edge and eof-target"
      (lambda ()
        (let* ((c (make-sequence-case '(1 2) 'stop #f))
               (mm (make-edge 'reject 'reexecute))
               (n (make-sequence-dispatch-node 'seq (list c) mm 'done #f)))
          (check "is a sequence node" (sequence-dispatch-node? n))
          (check-equal "name" (sequence-dispatch-node-name n) 'seq)
          (check-equal "case count" (length (sequence-dispatch-node-cases n)) 1)
          (check-equal "mismatch target" (edge-target (sequence-dispatch-node-mismatch n)) 'reject)
          (check-equal "mismatch mode" (edge-mode (sequence-dispatch-node-mismatch n)) 'reexecute)
          (check-equal "eof-target" (sequence-dispatch-node-eof-target n) 'done))))
    (harness-case "an eof-target of #f is legal and means the default eof error"
      (lambda ()
        (check-equal "false"
                     (sequence-dispatch-node-eof-target
                      (make-sequence-dispatch-node
                       'seq (list (make-sequence-case '(1) 'stop #f))
                       (make-edge 'reject 'reexecute) #f #f))
                     #f)))
    ;; Fix wave 1 (Minor 2): the eof-target guard had a "legal #f" case above
    ;; but no case proving it actually REJECTS a bad shape.
    (harness-case "a non-symbol, non-#f eof-target is rejected"
      (lambda ()
        (check-raises "bad eof-target" (contract-violation? 'make-sequence-dispatch-node 'eof-target)
                      (lambda () (make-sequence-dispatch-node
                                  'seq (list (make-sequence-case '(1) 'stop #f))
                                  (make-edge 'reject 'reexecute) 42 #f)))))
    (harness-case "an empty case list is rejected"
      (lambda ()
        (check-raises "no cases" (contract-violation? 'make-sequence-dispatch-node 'cases)
                      (lambda () (make-sequence-dispatch-node
                                  'seq '() (make-edge 'reject 'reexecute) #f #f)))))
    (harness-case "a bare target handed in as the mismatch edge is rejected"
      (lambda ()
        (check-raises "not an edge" (contract-violation? 'make-sequence-dispatch-node 'mismatch)
                      (lambda () (make-sequence-dispatch-node
                                  'seq (list (make-sequence-case '(1) 'stop #f))
                                  'reject #f #f)))))
    (harness-case "a sequence node is a node, and reports its own name"
      (lambda ()
        (let ((n (make-sequence-dispatch-node
                  'seq (list (make-sequence-case '(1) 'stop #f))
                  (make-edge 'reject 'reexecute) #f #f)))
          (check "node?" (node? n))
          (check-equal "node-name" (node-name n) 'seq))))))

;; Milestone 4 Slice ①b task 1: the uint field descriptor (§9.1:283, §10.2:488-491).
;; Validation is decision 0020's CONSTRUCTOR half -- closed-set membership and
;; the local shape of the one value being built -- so these are contract
;; violations, never diagnostics: a machine whose field failed construction
;; never exists, and re-checking any of them in the verifier would ship an arm
;; no public API can reach (0020's one-rejection-site rule).
(harness-group "callback and span declarations (Milestone 5 Slice ①b)"
  (lambda ()
    (harness-case "a callback declaration carries its six parts"
      (lambda ()
        (let ((d (make-callback-declaration 'on-header 'decision #t
                                            '(keep skip) 'keep 'the-label)))
          (check "predicate" (callback-declaration? d))
          (check-equal "name" (callback-declaration-name d) 'on-header)
          (check-equal "kind" (callback-declaration-kind d) 'decision)
          (check-equal "required?" (callback-declaration-required? d) #t)
          (check-equal "branch keys" (callback-declaration-branch-keys d) '(keep skip))
          (check-equal "default branch" (callback-declaration-default-branch d) 'keep)
          (check-equal "label" (callback-declaration-source-label d) 'the-label))))
    (harness-case "a span declaration carries its four parts"
      (lambda ()
        (let ((d (make-span-declaration 'body 'on-data 'on-done 'the-label)))
          (check "predicate" (span-declaration? d))
          (check-equal "name" (span-declaration-name d) 'body)
          (check-equal "data callback" (span-declaration-data-callback d) 'on-data)
          (check-equal "complete callback" (span-declaration-complete-callback d) 'on-done)
          (check-equal "label" (span-declaration-source-label d) 'the-label))))
    (harness-case "the completion callback is optional and #f is its absence"
      (lambda ()
        (check-equal "absent" (span-declaration-complete-callback
                               (make-span-declaration 'body 'on-data #f #f))
                     #f)))
    (harness-case "each predicate refuses the other family"
      (lambda ()
        (let ((c (make-callback-declaration 'c 'event #f '() #f #f))
              (p (make-span-declaration 's 'd #f #f)))
          (check "callback is not a span" (not (span-declaration? c)))
          (check "span is not a callback" (not (callback-declaration? p)))
          (check "neither is a uint field"
                 (and (not (uint-field? c)) (not (uint-field? p))))
          (check "a bare vector is neither"
                 (and (not (callback-declaration? (vector 'c 'event #f '() #f #f)))
                      (not (span-declaration? (vector 's 'd #f #f))))))))
    (harness-case "the kind set is closed at the four §10.3:502 names"
      (lambda ()
        ;; Sentinel over OBSERVED constructions, on the uint-field precedent.
        (let ((built 0))
          (for-each (lambda (k)
                      (set! built (+ built 1))
                      (check-equal (string-append "kind " (symbol->string k))
                                   (callback-declaration-kind
                                    (make-callback-declaration 'c k #f '() #f #f))
                                   k))
                    '(event decision span-data span-complete))
          (check-equal "four kinds built" built 4))
        (for-each (lambda (k)
                    (check-raises "refused"
                                  (contract-violation? 'make-callback-declaration 'kind)
                                  (lambda () (make-callback-declaration 'c k #f '() #f #f))))
                  '(callback span data complete event-callback #f))))
    (harness-case "every other local shape is refused, by who + code + detail"
      (lambda ()
        (check-raises "name" (contract-violation? 'make-callback-declaration 'name)
                      (lambda () (make-callback-declaration "c" 'event #f '() #f #f)))
        (check-raises "required?" (contract-violation? 'make-callback-declaration 'required?)
                      (lambda () (make-callback-declaration 'c 'event 'yes '() #f #f)))
        (check-raises "branch-keys not a list"
                      (contract-violation? 'make-callback-declaration 'branch-keys)
                      (lambda () (make-callback-declaration 'c 'decision #f 'keep #f #f)))
        (check-raises "branch-keys not all symbols"
                      (contract-violation? 'make-callback-declaration 'branch-keys)
                      (lambda () (make-callback-declaration 'c 'decision #f '(keep "skip") #f #f)))
        (check-raises "default-branch" (contract-violation? 'make-callback-declaration
                                                            'default-branch)
                      (lambda () (make-callback-declaration 'c 'decision #f '(k) 7 #f)))
        (check-raises "span name" (contract-violation? 'make-span-declaration 'name)
                      (lambda () (make-span-declaration "s" 'd #f #f)))
        (check-raises "span data callback"
                      (contract-violation? 'make-span-declaration 'data-callback)
                      (lambda () (make-span-declaration 's #f #f #f)))
        (check-raises "span complete callback"
                      (contract-violation? 'make-span-declaration 'complete-callback)
                      (lambda () (make-span-declaration 's 'd 7 #f)))))
    (harness-case "what the constructor deliberately ACCEPTS, because pass 6a owns it"
      (lambda ()
        ;; Each of these is a machine the VERIFIER must reject and the
        ;; constructor must not. ir.sls's own comment says why: a check here
        ;; makes the verifier arm unreachable through the public API, and its
        ;; permissive mutation then survives while the suite reports it caught.
        ;; When pass 6a lands (task 2), these three become positive diagnostic
        ;; fixtures; here they only prove construction succeeds.
        (check "an optional decision callback with NO default branch is built"
               (callback-declaration?
                (make-callback-declaration 'c 'decision #f '(keep skip) #f #f)))
        (check "a default branch outside the declared keys is built"
               (callback-declaration?
                (make-callback-declaration 'c 'decision #f '(keep) 'other #f)))
        (check "a branch key colliding with a reserved outcome is built"
               (callback-declaration?
                (make-callback-declaration 'c 'decision #f '(continue pause) #f #f)))
        (check "a nonportable name is built"
               (callback-declaration?
                (make-callback-declaration 'Not-Portable 'event #f '() #f #f)))))))

(harness-group "make-machine guards its callback and span collections"
  (lambda ()
    (harness-case "a well-formed declaration table is accepted"
      (lambda ()
        (check "built"
               (machine?
                (make-machine 'm 'start '()
                              (list (make-callback-declaration 'c 'event #f '() #f #f))
                              (list (make-span-declaration 's 'c #f #f))
                              (list (make-error-declaration 'e 'code "reason" #f))
                              (list (make-stop-node 'start #f))
                              'e #f)))))
    (harness-case "junk in either collection is refused, and named"
      (lambda ()
        ;; *** THE POINT OF THIS TASK. *** Before these guards, `machine-callbacks`
        ;; and `machine-spans` had been constructor parameters, vector slots and
        ;; exported accessors with NO reader anywhere in the tree, so a proper
        ;; list of junk was a valid declaration table. The detail must be
        ;; `callbacks`/`spans`, not `collection`: the collection loop above
        ;; already accepts any proper list and answers `collection`.
        (let ((ok-nodes (list (make-stop-node 'start #f)))
              (ok-errs (list (make-error-declaration 'e 'code "reason" #f))))
          (check-raises "callbacks" (contract-violation? 'make-machine 'callbacks)
                        (lambda () (make-machine 'm 'start '() (list 'junk) '()
                                                 ok-errs ok-nodes 'e #f)))
          (check-raises "spans" (contract-violation? 'make-machine 'spans
                                                     )
                        (lambda () (make-machine 'm 'start '() '() (list 42)
                                                 ok-errs ok-nodes 'e #f)))
          ;; A span declaration in the callbacks slot is junk too -- the guard is
          ;; per-family, not merely "is a declaration".
          (check-raises "a span in the callbacks slot"
                        (contract-violation? 'make-machine 'callbacks)
                        (lambda () (make-machine 'm 'start '()
                                                 (list (make-span-declaration 's 'd #f #f))
                                                 '() ok-errs ok-nodes 'e #f))))))
    (harness-case "the accessors read back what was declared"
      (lambda ()
        ;; Slice ①b is the FIRST reader of these two accessors; they have been
        ;; exported and dead since the descriptor was written.
        (let* ((c (make-callback-declaration 'c 'event #f '() #f #f))
               (p (make-span-declaration 's 'c #f #f))
               (m (make-machine 'm 'start '() (list c) (list p)
                                (list (make-error-declaration 'e 'code "r" #f))
                                (list (make-stop-node 'start #f)) 'e #f)))
          (check-equal "callbacks" (machine-callbacks m) (list c))
          (check-equal "spans" (machine-spans m) (list p)))))))

(harness-group "uint field descriptors"
  (lambda ()
    (harness-case "a field carries its four parts"
      (lambda ()
        (let ((f (make-uint-field 'count 16 7 'the-label)))
          (check "predicate" (uint-field? f))
          (check-equal "name" (uint-field-name f) 'count)
          (check-equal "width" (uint-field-width f) 16)
          (check-equal "initial" (uint-field-initial f) 7)
          (check-equal "label" (uint-field-source-label f) 'the-label))))
    (harness-case "the predicate refuses everything else"
      (lambda ()
        (check "not a symbol" (not (uint-field? 'count)))
        (check "not a vector" (not (uint-field? (vector 'count 8 0 #f))))
        (check "not an error declaration"
               (not (uint-field? (make-error-declaration 'e 'c "r" #f))))))
    (harness-case "the width set is closed at 8, 16, 32 and 64"
      (lambda ()
        ;; Sentinel over OBSERVED constructions, not over the list this case
        ;; wrote: a loop that never ran would otherwise pass vacuously.
        (let ((built 0))
          (for-each (lambda (w)
                      (set! built (+ built 1))
                      (check-equal (string-append "width " (number->string w))
                                   (uint-field-width (make-uint-field 'f w 0 #f)) w))
                    '(8 16 32 64))
          (check-equal "four widths built" built 4))
        (for-each (lambda (w)
                    (check-raises "refused" (contract-violation? 'make-uint-field 'width)
                                  (lambda () (make-uint-field 'f w 0 #f))))
                  '(0 1 7 9 24 63 65 128))))
    (harness-case "the initial is an exact integer inside the declared width"
      (lambda ()
        ;; §25:1568's DECLARATION-time share, at every width: 0 and 2^w-1
        ;; accepted, 2^w rejected. The u64 row runs at 2^64-1, which is above
        ;; (greatest-fixnum) = 2^60-1 on the only supported runtime -- a matrix
        ;; that stops at u32 says nothing about bignums.
        (let ((checked 0))
          (for-each
           (lambda (w)
             (set! checked (+ checked 1))
             (let ((top (- (expt 2 w) 1)))
               (check-equal (string-append "zero at " (number->string w))
                            (uint-field-initial (make-uint-field 'f w 0 #f)) 0)
               (check-equal (string-append "max at " (number->string w))
                            (uint-field-initial (make-uint-field 'f w top #f)) top)
               (check-raises "over the top"
                             (contract-violation? 'make-uint-field 'initial)
                             (lambda () (make-uint-field 'f w (+ top 1) #f)))
               (check-raises "negative"
                             (contract-violation? 'make-uint-field 'initial)
                             (lambda () (make-uint-field 'f w -1 #f)))))
           '(8 16 32 64))
          (check-equal "four widths checked" checked 4))
        (check-raises "inexact" (contract-violation? 'make-uint-field 'initial)
                      (lambda () (make-uint-field 'f 8 1.0 #f)))
        (check-raises "not a number" (contract-violation? 'make-uint-field 'initial)
                      (lambda () (make-uint-field 'f 8 'seven #f)))))
    (harness-case "the name must be a symbol"
      (lambda ()
        (check-raises "string" (contract-violation? 'make-uint-field 'name)
                      (lambda () (make-uint-field "count" 8 0 #f)))))))

(harness-group "the machine guard over fields"
  (lambda ()
    (harness-case "a machine accepts a list of field descriptors"
      (lambda ()
        (let ((m (make-machine 'm 'stop (list (make-uint-field 'count 8 0 #f))
                               '() '() (list (make-error-declaration 'e 'c "r" #f))
                               (list (make-stop-node 'stop #f)) 'e #f)))
          (check-equal "one field" (length (machine-fields m)) 1))))
    (harness-case "and refuses a list of anything else"
      (lambda ()
        ;; This guard is what makes the descriptor load-bearing. Before it,
        ;; make-machine checked only list? over the collections, so a machine
        ;; could carry (junk 42 "string") as its fields and nothing noticed.
        (check-raises "junk fields" (contract-violation? 'make-machine 'fields)
                      (lambda ()
                        (make-machine 'm 'stop (list 'junk 42) '() '()
                                      (list (make-error-declaration 'e 'c "r" #f))
                                      (list (make-stop-node 'stop #f)) 'e #f)))))))


;; Milestone 4 Slice ② task 1: the two zero-width node kinds (§9.1:301-306,
;; §10.6:550 and :575). Decision 0020 fixes the constructor/verifier boundary and
;; this group asserts the CONSTRUCTOR half only -- everything here is evaluable
;; from the one node being built.
;;
;; *** `arguments` is checked as a proper list AND NO FURTHER. *** 0020 item 2:
;; "Everything that requires the §9.1:326-346 schema -- which position holds the
;; field, how many positions there are, what each one means -- is the verifier's,
;; because §9.1:348 assigns exact arity to it and nothing can be read out of
;; `arguments` before arity is known." The consequence 0020 itself flags as
;; looking wrong to a reader of 0017: `low <= high` for `range` is the
;; VERIFIER's here, though 0017 rejects `low > high` in
;; `make-byte-range-matcher` -- there they are named parameters, here they are
;; the second and third elements of a list whose length the constructor may not
;; assume. So there is deliberately no arity case in this group.
(harness-group "field-action nodes"
  (lambda ()
    (harness-case "a field action carries its six parts"
      (lambda ()
        ;; A FALLIBLE operation, so `error` carries a target -- the six parts are
        ;; read off the shape the error-slot rule below actually permits.
        (let ((n (make-field-action-node 'bump 'increment '(count) 'next 'oops 'lbl)))
          (check "predicate" (field-action-node? n))
          (check-equal "name" (field-action-node-name n) 'bump)
          (check-equal "operation" (field-action-node-operation n) 'increment)
          (check-equal "arguments" (field-action-node-arguments n) '(count))
          (check-equal "next" (field-action-node-next n) 'next)
          (check-equal "error" (field-action-node-error n) 'oops)
          (check-equal "label" (field-action-node-source-label n) 'lbl))
        ;; and the #f half, on an operation that cannot fail.
        (check-equal "no error target"
                     (field-action-node-error
                      (make-field-action-node 'z 'clear '(count) 'next #f #f))
                     #f)))
    (harness-case "it is a node and answers node-name"
      (lambda ()
        (let ((n (make-field-action-node 'bump 'clear '(count) 'next #f #f)))
          (check "node?" (node? n))
          (check-equal "node-name" (node-name n) 'bump))))
    (harness-case "every one of the seven operations is accepted"
      (lambda ()
        ;; A loop with a sentinel reading the OBSERVED count: a closed
        ;; enumeration asserted by naming three of seven is not asserted.
        (let ((seen 0))
          (for-each (lambda (spec)
                      (set! seen (+ seen 1))
                      (check-equal (symbol->string (car spec))
                                   (field-action-node-operation
                                    (make-field-action-node 'a (car spec) (cadr spec)
                                                            'next (caddr spec) #f))
                                   (car spec)))
                    '((store (count 1) #f) (clear (count) #f)
                      (increment (count) oops) (decrement (count) oops)
                      (add (count 1) oops) (set-mask (count 1) #f)
                      (clear-mask (count 1) #f)))
          (check-equal "all seven were built" seen 7))))
    (harness-case "an operation outside the closed set is refused"
      (lambda ()
        ;; §9.1:348's "it rejects arbitrary operation names" -- the one clause of
        ;; that sentence pass 6a does NOT carry (0020 item 4), because a closed
        ;; set is evaluable from the node alone.
        (check-raises "not an operation" (contract-violation? 'make-field-action-node 'operation)
                      (lambda () (make-field-action-node 'a 'multiply '(count 2) 'next #f #f)))))
    (harness-case "arguments must be a proper list, and nothing more is read"
      (lambda ()
        (check-raises "improper" (contract-violation? 'make-field-action-node 'arguments)
                      (lambda () (make-field-action-node 'a 'store '(count . 1) 'next #f #f)))
        ;; The other half of 0020 item 2, asserted so a later reader does not
        ;; "fix" the constructor into reading the schema: a WRONG ARITY builds
        ;; fine here and is pass 6a's to reject.
        (check "wrong arity is accepted at construction"
               (field-action-node? (make-field-action-node 'a 'store '() 'next #f #f)))))
    (harness-case "the error slot is #f exactly when the operation cannot fail"
      (lambda ()
        ;; Design §4.4's error-slot rule. Permitting a target on a safe
        ;; operation would NOT fail loudly: node-out-targets feeds `error` into
        ;; the reachability walk unconditionally, so the target is reached and no
        ;; pass checks whether the operation can fail. The constructor is the
        ;; only place that can.
        (check-raises "safe op with a target"
                      (contract-violation? 'make-field-action-node 'error)
                      (lambda () (make-field-action-node 'a 'store '(count 1) 'next 'oops #f)))
        (check-raises "failing op without one"
                      (contract-violation? 'make-field-action-node 'error)
                      (lambda () (make-field-action-node 'a 'increment '(count) 'next #f #f)))))))

(harness-group "field-branch nodes"
  (lambda ()
    (harness-case "a field branch carries its six parts"
      (lambda ()
        (let ((n (make-field-branch-node 'test 'zero '(count) 'yes 'no 'lbl)))
          (check "predicate" (field-branch-node? n))
          (check-equal "name" (field-branch-node-name n) 'test)
          (check-equal "predicate" (field-branch-node-predicate n) 'zero)
          (check-equal "arguments" (field-branch-node-arguments n) '(count))
          (check-equal "true-target" (field-branch-node-true-target n) 'yes)
          (check-equal "false-target" (field-branch-node-false-target n) 'no)
          (check-equal "label" (field-branch-node-source-label n) 'lbl))))
    (harness-case "it is a node and answers node-name"
      (lambda ()
        (let ((n (make-field-branch-node 'test 'zero '(count) 'yes 'no #f)))
          (check "node?" (node? n))
          (check-equal "node-name" (node-name n) 'test))))
    (harness-case "every one of the seven predicates is accepted"
      (lambda ()
        (let ((seen 0))
          (for-each (lambda (p)
                      (set! seen (+ seen 1))
                      (check-equal (symbol->string p)
                                   (field-branch-node-predicate
                                    (make-field-branch-node 'a p '(count) 'y 'n #f))
                                   p))
                    '(equal zero nonzero range mask-any mask-all mask-none))
          (check-equal "all seven were built" seen 7))))
    (harness-case "a predicate outside the closed set is refused"
      (lambda ()
        (check-raises "not a predicate" (contract-violation? 'make-field-branch-node 'predicate)
                      (lambda () (make-field-branch-node 'a 'greater '(count 2) 'y 'n #f)))))
    (harness-case "low > high builds fine -- it is the verifier's"
      (lambda ()
        ;; 0020 item 2 names this exact case as the one that "will look wrong to
        ;; a reader of 0017". Asserted rather than merely absent, so the boundary
        ;; is witnessed instead of assumed.
        (check "accepted at construction"
               (field-branch-node? (make-field-branch-node 'a 'range '(count 9 2) 'y 'n #f)))))))


;; Milestone 4 Slice ③ task 1: the integer-accumulate node (§9.1:301-306,
;; §10.6:566-571, §11.4:652). The last node kind of the milestone, and the only
;; INPUT-READING one -- it consumes a byte and makes progress, which is what
;; separates it from Slice ②'s two zero-width kinds at every verifier site.
;;
;; *** The constructor/verifier boundary here is 0017's, NOT 0020's. *** 0020
;; item 2 keeps the constructor out of `arguments` because that is a LIST whose
;; length it may not assume; this kind has no `arguments` -- its operands are
;; NAMED PARAMETERS, exactly the situation 0017 point 1 addresses when it rejects
;; `low > high` inside `make-byte-range-matcher`. So `base` is closed here (the
;; base half of §16.2:904), and only the FIELD REFERENCE -- which needs a second
;; object, the declaration list -- is the verifier's.
(harness-group "integer-accumulate nodes"
  (lambda ()
    (harness-case "an accumulate node carries its seven parts"
      (lambda ()
        (let ((n (make-integer-accumulate-node 'acc 'count 10 'acc
                                               (make-edge 'done 'reexecute)
                                               'over 'eofward 'lbl)))
          (check "predicate" (integer-accumulate-node? n))
          (check-equal "name" (integer-accumulate-node-name n) 'acc)
          (check-equal "field" (integer-accumulate-node-field n) 'count)
          (check-equal "base" (integer-accumulate-node-base n) 10)
          (check-equal "digit-target" (integer-accumulate-node-digit-target n) 'acc)
          (check-equal "nondigit-edge target"
                       (edge-target (integer-accumulate-node-nondigit-edge n)) 'done)
          (check-equal "overflow-error" (integer-accumulate-node-overflow-error n) 'over)
          (check-equal "eof-target" (integer-accumulate-node-eof-target n) 'eofward)
          (check-equal "label" (integer-accumulate-node-source-label n) 'lbl))))
    (harness-case "it is a node and answers node-name"
      (lambda ()
        (let ((n (make-integer-accumulate-node 'acc 'count 16 'acc
                                               (make-edge 'done 'reexecute) 'over #f #f)))
          (check "node?" (node? n))
          (check-equal "node-name" (node-name n) 'acc))))
    (harness-case "both bases are accepted and nothing else is"
      (lambda ()
        ;; §16.2:904's "unsupported base", discharged HERE rather than as a
        ;; diagnostic: a base is evaluable from the one node being built, so a
        ;; verifier arm for it would be dead code whose permissive mutation
        ;; survives -- 0020's one-rejection-site rule.
        (let ((seen 0))
          (for-each (lambda (b)
                      (set! seen (+ seen 1))
                      (check-equal (number->string b)
                                   (integer-accumulate-node-base
                                    (make-integer-accumulate-node 'a 'count b 'a
                                                                  (make-edge 'd 'reexecute)
                                                                  'o #f #f))
                                   b))
                    '(10 16))
          (check-equal "both bases" seen 2))
        (check-raises "base 8" (contract-violation? 'make-integer-accumulate-node 'base)
                      (lambda () (make-integer-accumulate-node 'a 'count 8 'a
                                                               (make-edge 'd 'reexecute) 'o #f #f)))
        (check-raises "base 2" (contract-violation? 'make-integer-accumulate-node 'base)
                      (lambda () (make-integer-accumulate-node 'a 'count 2 'a
                                                               (make-edge 'd 'reexecute) 'o #f #f)))))
    (harness-case "the nondigit edge must be an edge"
      (lambda ()
        ;; It is an EDGE, not a bare target: §10.6:567 says the non-digit "takes
        ;; an explicit fallback edge, normally reexecuting the delimiter", so its
        ;; MODE is the whole point and a bare symbol could not carry one.
        (check-raises "a bare symbol"
                      (contract-violation? 'make-integer-accumulate-node 'nondigit-edge)
                      (lambda () (make-integer-accumulate-node 'a 'count 10 'a 'done 'o #f #f)))))
    (harness-case "the eof-target is a symbol or #f"
      (lambda ()
        ;; #f means the machine default-eof error, the same convention
        ;; byte-dispatch uses (§9.1:318).
        (check-equal "absent"
                     (integer-accumulate-node-eof-target
                      (make-integer-accumulate-node 'a 'count 10 'a (make-edge 'd 'reexecute)
                                                    'o #f #f))
                     #f)
        (check-raises "a number"
                      (contract-violation? 'make-integer-accumulate-node 'eof-target)
                      (lambda () (make-integer-accumulate-node 'a 'count 10 'a
                                                               (make-edge 'd 'reexecute) 'o 7 #f)))))
    (harness-case "the overflow-error is a mandatory symbol"
      (lambda ()
        ;; Unlike a field action's `error`, this is never #f: §10.6:568 says
        ;; overflow "takes an explicit error edge", and accumulation can ALWAYS
        ;; overflow -- there is no base or width at which it cannot.
        (check-raises "absent"
                      (contract-violation? 'make-integer-accumulate-node 'overflow-error)
                      (lambda () (make-integer-accumulate-node 'a 'count 10 'a
                                                               (make-edge 'd 'reexecute) #f #f #f)))))
    (harness-case "the field reference is NOT checked here"
      (lambda ()
        ;; The half that needs a second object -- the declaration list -- and so
        ;; cannot be a constructor contract. Asserted rather than merely absent,
        ;; so the boundary is witnessed instead of assumed.
        (check "an undeclared field name builds fine"
               (integer-accumulate-node?
                (make-integer-accumulate-node 'a 'nosuch 10 'a (make-edge 'd 'reexecute)
                                              'o #f #f)))))))

(harness-finish)
