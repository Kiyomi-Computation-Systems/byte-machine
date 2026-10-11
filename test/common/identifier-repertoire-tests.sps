;;; The emitted identifier repertoire, proved exhaustively.
;;; Machine names and output bindings go through ONE [a-z][a-z0-9-]* grammar,
;;; (byte-machine private names)' `portable-name?`, verify adding reserved
;;; member 1 and compile all three reserved sets. Both sites are driven here,
;;; because a shared body proves nothing about a site that stopped calling it.
;;; Diagnostics and conditions are checked by category, never by prose. The LF
;;; proof reads raw emitted bytes; a Windows CRLF trap cannot be exhibited on a
;;; non-Windows host.
(import (rnrs)
        (byte-machine test harness)
        (byte-machine graph)
        (byte-machine verify)
        (byte-machine compile))

(harness-begin "verify.identifier-repertoire")

;; --- a machine whose only variable is its NAME, for the verify-site grammar ---
(define rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))
(define eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
(define (machine-named nm)
  (make-machine nm 'start '() '() '() (list eof-decl rej-decl)
    (list (make-byte-dispatch-node 'start
            (list (make-byte-case (make-exact-byte-matcher 0) (make-edge 'stop 'advance) #f))
            (make-edge 'reject 'reexecute) #f #f)
          (make-stop-node 'stop #f)
          (make-error-node 'reject 'rejected #f))
    'default-eof #f))
(define (name-accepted? nm) (verification-ok? (verify-machine (machine-named nm))))

;; --- the fixed one-byte machine, for the binding-site grammar ---
(define one-byte
  (make-machine 'one-byte 'start '() '() '() (list eof-decl rej-decl)
    (list (make-byte-dispatch-node 'start
            (list (make-byte-case (make-exact-byte-matcher 0) (make-edge 'stop 'advance) #f))
            (make-edge 'reject 'reexecute) #f #f)
          (make-stop-node 'stop #f)
          (make-error-node 'reject 'rejected #f))
    'default-eof #f))
(define ok (compile-machine one-byte '()))
(define (binding-accepted? sym)
  (guard (e (#t #f)) (bytevector? (render-machine ok sym))))

;; Accepted repertoire: leading [a-z], interior [a-z0-9-], including a trailing
;; hyphen (a name-char) and digits after the first position. Both sites agree
;; on this grammar-only core, by construction.
(define accepted '(a z ab a1 a-b abc-123 zzz9 a- one-byte))
;; 'start' satisfies the grammar and is not a member-1 keyword, so it is a
;; valid machine/node NAME (verify-site) -- but compile.sls reserves it as a
;; template identifier (reserved-member-3: the emitted feed loop's own `start`
;; binding), so it is not a valid output BINDING. Tested at the verify site only.
(define accepted-names (cons 'start accepted))
;; Rejected: empty, leading digit, leading hyphen, uppercase anywhere,
;; punctuation other than '-', and a reserved member-1 keyword. Chez's r6rs
;; program reader accepts neither a bare leading-digit/leading-hyphen token
;; (ambiguous with number syntax) nor |...| escape syntax in this mode, so
;; those candidates are built with string->symbol rather than as literals.
;; The empty symbol's rejection is retained as by-inspection coverage, not a
;; mutation witness: `portable-name?` (behind both valid-name? and
;; valid-binding?) short-circuits its `and` on
;; (> (string-length s) 0) before ever indexing into s, so any mutation that
;; relaxes that length guard makes the very next (string-ref s 0) raise on
;; this candidate -- a crash, not an acceptance, i.e. "caught for the wrong
;; reason". No honest witnessing mutation exists.
(define rejected-names
  (list (string->symbol "9a") (string->symbol "-a") 'Ab 'aB
        (string->symbol "a.b") (string->symbol "a_b") (string->symbol "a/b")
        (string->symbol "a+b") (string->symbol "a b") 'define
        (string->symbol "") (string->symbol "a\xe9;b")))
;; Bindings additionally reserve runtime exports (member 2) and template ids
;; (member 3); the grammar-only rejects above still apply. 'start' is a valid
;; verify-site name (see accepted-names) but not a valid binding -- it is
;; reserved-member-3 -- so it belongs here, not in accepted.
(define rejected-bindings
  (list (string->symbol "9a") (string->symbol "-a") 'Ab (string->symbol "a.b")
        'define 'make-compiled-machine 'exec 'start
        (string->symbol "") (string->symbol "a\xe9;b")))

(harness-group "machine names: the verify-site grammar"
  (lambda ()
    (harness-case "every accepted name verifies"
      (lambda ()
        (for-each (lambda (nm) (check (string-append "accept " (symbol->string nm))
                                      (name-accepted? nm)))
                  accepted-names)))
    (harness-case "every rejected name is refused"
      (lambda ()
        (for-each (lambda (nm) (check (string-append "reject " (symbol->string nm))
                                      (not (name-accepted? nm))))
                  rejected-names)))))

(harness-group "output bindings: the compile-site grammar and reserved set"
  (lambda ()
    (harness-case "every accepted binding renders"
      (lambda ()
        (for-each (lambda (sym) (check (string-append "accept " (symbol->string sym))
                                       (binding-accepted? sym)))
                  accepted)))
    (harness-case "every rejected binding is refused"
      (lambda ()
        (for-each (lambda (sym) (check (string-append "reject " (symbol->string sym))
                                       (not (binding-accepted? sym))))
                  rejected-bindings)))))

(harness-group "binary output is LF-only with a final newline"
  (lambda ()
    (harness-case "no carriage return byte appears and the last byte is LF"
      (lambda ()
        (let* ((bytes (render-machine ok 'one-byte-parser))
               (n (bytevector-length bytes)))
          (let loop ((i 0))
            (when (< i n)
              (when (= (bytevector-u8-ref bytes i) 13)
                (check-fail "carriage return present"
                            (string-append "CR byte at offset " (number->string i))))
              (loop (+ i 1))))
          (check-equal "final byte is LF" (bytevector-u8-ref bytes (- n 1)) 10))))))

(harness-finish)
