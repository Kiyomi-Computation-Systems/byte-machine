;;; The multi-alternative proving machines: the HTTP grammar production
;;; `version = "HTTP/1.0" / "HTTP/1.1"`. The graph is written once and exported
;;; (pause-machine.sls's convention) for the absolute interpreter lane, the
;;; interpreter≡generated differential and the determinism golden. Built only
;;; through (byte-machine graph).
;;;
;;; The emitter has no dedicated arm for this shape: the normalizer lowers the
;;; two alternatives to a trie before compile.sls sees them, so the BRANCHING
;;; prefix state renders as an ordinary multi-arm
;;; `(case b ((48) ...) ((49) ...) (else ...))` -- indistinguishable in form from
;;; a one-alternative state's single arm. compile.sls's render-state-arm comment
;;; records why.
;;;
;;; Why this fixture: it exercises a shared NONTERMINAL prefix with a
;;; distinguishing terminal byte, it is a real grammar production rather than an
;;; invented one, and its seven-byte shared prefix `HTTP/1.` puts the branch far
;;; enough in that a mismatch position is unambiguous. It is not the SMALLEST
;;; such shape: normal-ir-tests.sps's AB/AC group and interpret-tests.sps's own
;;; AB/AC fixture are both smaller. What the extra depth buys is the seven-byte
;;; walk before the branch -- a one-byte prefix cannot tell a mismatch INSIDE the
;;; prefix apart from one AT the branch, and this file's lane asserts both.
;;;
;;; The machine name is 'http-version because the emitted library is
;;; `(library (generated <machine-name>) ...)` and names must match
;;; [a-z][a-z0-9-]* -- never 'HTTP/1.x.
;;;
;;; Out of scope here: case-insensitive recognition and the grammar's byte
;;; classes (tchar, target-byte, field-value-byte, OWS). This fixture is the
;;; `version` production and nothing more.
(library (byte-machine test http-version-machine)
  (export make-http-version-machine make-http-version-advance-machine
          http-version-bytes http-version-shared-prefix)
  (import (rnrs) (byte-machine graph))

  (define (string-bytes s) (map char->integer (string->list s)))
  ;; `ascii-bytes` would also do here; string-bytes is used instead so this
  ;; fixture exercises no graph helper it is not testing.
  (define (http-version-bytes which)
    (case which
      ((zero) (string-bytes "HTTP/1.0"))
      ((one)  (string-bytes "HTTP/1.1"))
      (else (assertion-violation 'http-version-bytes "no such alternative" which))))
  (define (http-version-shared-prefix) (string-bytes "HTTP/1."))

  (define (build name mismatch-mode)
    (let ((eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
          (rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f)))
      (make-machine name 'ver '() '() '() (list eof-decl rej-decl)
        (list (make-sequence-dispatch-node
               'ver
               (list (make-sequence-case (http-version-bytes 'zero) 'zero #f)
                     (make-sequence-case (http-version-bytes 'one) 'one #f))
               (make-edge 'reject mismatch-mode) #f #f)
              (make-stop-node 'zero #f)
              (make-stop-node 'one #f)
              (make-error-node 'reject 'rejected #f))
        'default-eof #f)))

  (define (make-http-version-machine) (build 'http-version 'reexecute))
  (define (make-http-version-advance-machine) (build 'http-version-advance 'advance)))
