;;; The Milestone 11 Slice ③ size-measurement fixture (brief §7 criterion 7 --
;;; the change's whole justification). The 47 llhttp method names built TWO ways,
;;; so the emitted size and node count of each can be measured through a lane:
;;;
;;;   make-method-keyword-machine  -- ONE keyword-table node (the "after")
;;;   make-method-trie-machine     -- the equivalent trie of byte-dispatch nodes,
;;;                                   one node per distinct prefix (the "before",
;;;                                   the shape the consumer ships today)
;;;
;;; Both route every keyword to an error node (`matched`) reached by REEXECUTING
;;; the non-continuing byte, and both take a distinct error node at EOF; a size
;;; measurement needs no acceptance behaviour, and error-node terminals keep both
;;; machines verifiable without a following grammar. The 47 names are the
;;; consumer's method table (llhttp), embedded here so this repository owns its
;;; own copy; GET ⊂ GET-PARAMETER is the sole proper-prefix pair.
;;;
;;; The trie node COUNT (one per distinct prefix) is what the lane reads off the
;;; BUILT machine -- not off the prefix list it was built from -- so the "242"
;;; assertion is a measurement, not a tautology.
(library (byte-machine test keyword-method-table)
  (export make-method-keyword-machine make-method-trie-machine method-names)
  (import (rnrs) (byte-machine graph))

  (define method-names
    '("ACL" "ANNOUNCE" "BIND" "CHECKOUT" "CONNECT" "COPY" "DELETE" "DESCRIBE"
      "FLUSH" "GET" "GET-PARAMETER" "HEAD" "LINK" "LOCK" "M-SEARCH" "MERGE"
      "MKACTIVITY" "MKCALENDAR" "MKCOL" "MOVE" "NOTIFY" "OPTIONS" "PATCH"
      "PAUSE" "PLAY" "POST" "PRI" "PROPFIND" "PROPPATCH" "PURGE" "PUT" "QUERY"
      "REBIND" "RECORD" "REDIRECT" "REPORT" "SEARCH" "SET-PARAMETER" "SETUP"
      "SOURCE" "SUBSCRIBE" "TEARDOWN" "TRACE" "UNBIND" "UNLINK" "UNLOCK"
      "UNSUBSCRIBE"))

  (define (string->bytes s) (map char->integer (string->list s)))
  ;; R6RS strict AOT has no `iota` (a Chez extension); a local 0..n-1.
  (define (up-to n) (let loop ((i 0) (acc '())) (if (= i n) (reverse acc) (loop (+ i 1) (cons i acc)))))

  (define shared-errors
    (list (make-error-declaration 'default-eof 'eof "unexpected end of input" #f)
          (make-error-declaration 'matched 'unexpected-byte "keyword matched (measurement stub)" #f)
          (make-error-declaration 'rejected 'unexpected-byte "no keyword" #f)
          (make-error-declaration 'incomplete 'truncated-keyword "incomplete at EOF" #f)))
  (define shared-terminals
    (list (make-error-node 'matched 'matched #f)
          (make-error-node 'reject 'rejected #f)
          (make-error-node 'eof-t 'incomplete #f)))

  ;; --- the compact "after": one keyword-table node ---------------------------
  (define (make-method-keyword-machine)
    (make-machine 'methodkw 'kw '() '() '()
      shared-errors
      (cons (make-keyword-table-node 'kw
              (map (lambda (nm) (make-keyword-entry (string->bytes nm) 'matched #f)) method-names)
              (make-edge 'reject 'reexecute) 'eof-t #f #f)
            shared-terminals)
      'default-eof #f))

  ;; --- the "before": a trie of byte-dispatch nodes, one per distinct prefix --
  (define (prefixes-of s)
    (map (lambda (k) (substring s 0 k)) (up-to (+ 1 (string-length s)))))
  (define all-prefixes
    (fold-left (lambda (acc nm)
                 (fold-left (lambda (a p) (if (member p a) a (cons p a))) acc (prefixes-of nm)))
               '() method-names))
  (define prefix-vec (list->vector (reverse all-prefixes)))
  (define (prefix-index p)
    (let loop ((i 0)) (if (string=? (vector-ref prefix-vec i) p) i (loop (+ i 1)))))
  (define (prefix-name p) (string->symbol (string-append "n" (number->string (prefix-index p)))))
  (define (extending-bytes p)
    (filter (lambda (b) (member (string-append p (string (integer->char b))) all-prefixes))
            (up-to 256)))
  (define (trie-node p)
    (let ((cases (map (lambda (b)
                        (make-byte-case (make-exact-byte-matcher b)
                                        (make-edge (prefix-name (string-append p (string (integer->char b)))) 'advance)
                                        #f))
                      (extending-bytes p)))
          (kw? (member p method-names)))
      (make-byte-dispatch-node (prefix-name p) cases
                               (make-edge (if kw? 'matched 'reject) 'reexecute)
                               'eof-t #f)))
  (define (make-method-trie-machine)
    (make-machine 'methodtrie (prefix-name "") '() '() '()
      shared-errors
      (append (map trie-node (vector->list prefix-vec)) shared-terminals)
      'default-eof #f)))
