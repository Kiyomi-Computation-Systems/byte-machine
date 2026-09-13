;;; The Milestone 11 Slice ② case-insensitivity proving machines: the brief §2b
;;; HTTP-header demonstration and the folded-collision rejection's witness.
;;; Built only through (byte-machine graph); shared by the header lane.
;;;
;;; TWO shapes, four machines:
;;;
;;; 1. The HEADER recognition pair -- the four case-insensitive HTTP header names
;;;    the consumer needs (Content-Length, Transfer-Encoding, Connection,
;;;    Upgrade), as a case-INSENSITIVE table (make-keyword-header-ci-machine) and
;;;    a case-SENSITIVE one (make-keyword-header-machine) over the SAME names,
;;;    differing only in `case-insensitive?`. The CI table recognizes every
;;;    casing to one target; the CS table recognizes only the canonical bytes.
;;;    This is brief §7 criterion 4. Each name routes to a DISTINCT stop node so
;;;    `parser-state-name` witnesses WHICH name matched.
;;;
;;; 2. The COLLISION pair -- two byte-DISTINCT case variants of one name
;;;    (Content-Length and content-length). As a case-insensitive table
;;;    (make-keyword-collision-ci-machine) they are equal after folding, so the
;;;    verifier refuses the table with `case-insensitive-keyword-collision`
;;;    (decision 0045 item 3). As a case-SENSITIVE table
;;;    (make-keyword-collision-cs-machine) they are two legitimately distinct
;;;    keywords -- byte-different (so not a `duplicate-keyword`) and case-sensitive
;;;    (so no fold collision) -- and the table VERIFIES CLEAN. That contrast is
;;;    the per-table pin: the CI machine must be rejected, the CS machine must
;;;    verify, and a mutant that drops the `case-insensitive?` guard flips the
;;;    second. The CI collision machine is INVALID by design; drive it only
;;;    through `verify-machine` directly, never `make-interpreted-machine` (which
;;;    raises on an unverified machine).
;;;
;;; A no-match routes to a `reject` error node (reexecute: the unmatched byte is
;;; not consumed); the eof-target is a distinct `eof-incomplete` error node (EOF
;;; mid-table takes no keyword, and an EOF path to a stop is itself a verifier
;;; diagnostic, `eof-reachable-stop`).
(library (byte-machine test keyword-header-machine)
  (export make-keyword-header-machine make-keyword-header-ci-machine
          make-keyword-collision-ci-machine make-keyword-collision-cs-machine
          keyword-header-keywords keyword-collision-keywords)
  (import (rnrs) (byte-machine graph))

  ;; The four header names and their stop-node targets, in table order.
  (define keyword-header-keywords
    '(("Content-Length" . got-content-length)
      ("Transfer-Encoding" . got-transfer-encoding)
      ("Connection" . got-connection)
      ("Upgrade" . got-upgrade)))

  ;; The two byte-distinct case variants that collide under folding.
  (define keyword-collision-keywords
    '(("Content-Length" . got-cl-canonical)
      ("content-length" . got-cl-lower)))

  (define (string->bytes s) (map char->integer (string->list s)))
  (define (entry pair) (make-keyword-entry (string->bytes (car pair)) (cdr pair) #f))

  ;; A keyword-table machine over `keywords` (each a (string . stop-name) pair),
  ;; one stop node per keyword, no-match -> reject, eof -> eof-incomplete.
  (define (build name keywords case-insensitive?)
    (make-machine name 'table '() '() '()
      (list (make-error-declaration 'default-eof 'eof "unexpected end of input" #f)
            (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f)
            (make-error-declaration 'incomplete 'truncated-keyword "incomplete keyword at end of input" #f))
      (append
        (list (make-keyword-table-node 'table
                (map entry keywords)
                (make-edge 'reject 'reexecute)  ; no-match: byte not consumed
                'eof-incomplete                 ; eof-target: EOF mid-table is an error
                case-insensitive?
                #f))
        (map (lambda (pair) (make-stop-node (cdr pair) #f)) keywords)
        (list (make-error-node 'eof-incomplete 'incomplete #f)
              (make-error-node 'reject 'rejected #f)))
      'default-eof #f))

  (define (make-keyword-header-machine) (build 'kwheader keyword-header-keywords #f))
  (define (make-keyword-header-ci-machine) (build 'kwheaderci keyword-header-keywords #t))
  (define (make-keyword-collision-ci-machine) (build 'kwcollci keyword-collision-keywords #t))
  (define (make-keyword-collision-cs-machine) (build 'kwcollcs keyword-collision-keywords #f)))
