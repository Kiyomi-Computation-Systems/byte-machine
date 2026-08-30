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

(harness-finish)
