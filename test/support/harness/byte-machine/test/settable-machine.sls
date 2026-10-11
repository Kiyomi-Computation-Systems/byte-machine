;; A two-mode proving machine: a parser can start in a mode.
;; A SETTABLE `mode` field, and an entry field-branch that reads it: with the
;; embedder's `make-parser` override `mode == 1` the machine accepts 'R' (the
;; "request" arm), and with the declared initial `mode == 0` it accepts 'S' (the
;; "response" arm). So two parsers built from ONE compiled machine start in two
;; different states, and the two arms fork observably (one input stops, the
;; other errors) so a cross-lane disagreement or a lost override is a red
;; differential, not a silent pass.
;;
;; The mode field is a field-branch SELECTOR, never a counted-consume counter, so
;; it verifies clean (the verifier refuses a settable counted-consume counter,
;; not a settable selector). It is the consumer's `type` shape (llhttp request
;; vs response) reduced to one field.
(library (byte-machine test settable-machine)
  (export make-settable-machine)
  (import (rnrs) (byte-machine graph))
  (define (make-settable-machine)
    (make-machine 'settable 'check-mode
      (list (make-uint-field 'mode 8 0 #t #f))   ; SETTABLE, declared initial 0
      '() '()
      (list (make-error-declaration 'eof 'unexpected-eof "unexpected end of input" #f)
            (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))
      (list (make-field-branch-node 'check-mode 'equal (list 'mode 1) 'req 'res #f)
            (make-byte-dispatch-node 'req
              (list (make-byte-case (make-exact-byte-matcher #x52)  ; 'R'
                                    (make-edge 'accept 'advance) #f))
              (make-edge 'reject 'reexecute) 'eof-stop #f)
            (make-byte-dispatch-node 'res
              (list (make-byte-case (make-exact-byte-matcher #x53)  ; 'S'
                                    (make-edge 'accept 'advance) #f))
              (make-edge 'reject 'reexecute) 'eof-stop #f)
            (make-stop-node 'accept #f)
            (make-error-node 'reject 'rejected #f)
            (make-error-node 'eof-stop 'eof #f))
      'eof #f)))
