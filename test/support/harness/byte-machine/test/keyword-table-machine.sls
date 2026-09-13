;;; The Milestone 11 Slice ① keyword-table proving machines, shared by the
;;; absolute interpreter lane and the interpreter≡generated differential so each
;;; graph descriptor is written once. Built only through (byte-machine graph).
;;;
;;; Both machines carry the SAME keyword set -- GET, GET-PARAMETER, close,
;;; closed -- and differ only in `case-insensitive?`. That is deliberate: it is
;;; the one difference decision 0045 item 5 says must move the fingerprint, and
;;; it lets the differential lane show the case-sensitive table refusing a
;;; mixed-case name that the case-insensitive one accepts, with nothing else
;;; changed. The set itself is the brief's shape: GET is a proper prefix of
;;; GET-PARAMETER (§7 criterion 1-2), and close is a proper prefix of closed
;;; (criterion 3) -- longest-match, not first-match, and no backtracking.
;;;
;;; Each keyword routes to a DISTINCT stop node, so `parser-state-name` at the
;;; terminal witnesses WHICH keyword matched -- an identity a shared stop node
;;; could not carry. A no-match routes to an error node (reexecute: the
;;; unmatched byte is not consumed, so the span closes at the keyword length,
;;; criterion 5). The keyword-table node's own eof-target is a distinct error
;;; node `eof-incomplete`: EOF mid-table takes no keyword, and reaching a stop
;;; terminal by an EOF path is itself a verifier diagnostic
;;; (`eof-reachable-stop`), so an incomplete keyword at EOF is an error, routed
;;; distinctly from the machine-level default EOF an empty parser finishes
;;; through and from the no-match error a wrong byte takes.
;;;
;;; This is the fold-mechanism fixture (Slice ①). The brief §2b HTTP-header
;;; case-insensitivity demonstration and the folded-collision rejection are
;;; Slice ②'s (decision 0045, amended 2026-09-13).
(library (byte-machine test keyword-table-machine)
  (export make-keyword-table-machine make-keyword-table-ci-machine
          keyword-table-keywords)
  (import (rnrs) (byte-machine graph))

  ;; The four keywords and their stop-node targets, in table order. The two
  ;; proper-prefix pairs (GET/GET-PARAMETER, close/closed) are what make this a
  ;; longest-match oracle rather than a flat set.
  (define keyword-table-keywords
    '(("GET" . got-get)
      ("GET-PARAMETER" . got-gp)
      ("close" . got-close)
      ("closed" . got-closed)))

  (define (string->bytes s) (map char->integer (string->list s)))

  (define (entry pair)
    (make-keyword-entry (string->bytes (car pair)) (cdr pair) #f))

  (define (build name case-insensitive?)
    (make-machine name 'table '() '() '()
      (list (make-error-declaration 'default-eof 'eof "unexpected end of input" #f)
            (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f)
            (make-error-declaration 'incomplete 'truncated-keyword "incomplete keyword at end of input" #f))
      (list (make-keyword-table-node 'table
              (map entry keyword-table-keywords)
              (make-edge 'reject 'reexecute)  ; no-match: byte not consumed
              'eof-incomplete                 ; eof-target: EOF mid-table is an error
              case-insensitive?
              #f)
            (make-stop-node 'got-get #f)
            (make-stop-node 'got-gp #f)
            (make-stop-node 'got-close #f)
            (make-stop-node 'got-closed #f)
            (make-error-node 'eof-incomplete 'incomplete #f)
            (make-error-node 'reject 'rejected #f))
      'default-eof #f))

  (define (make-keyword-table-machine) (build 'kwtable #f))
  (define (make-keyword-table-ci-machine) (build 'kwtableci #t)))
