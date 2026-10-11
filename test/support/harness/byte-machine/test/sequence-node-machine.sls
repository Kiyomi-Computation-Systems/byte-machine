;;; The sequence-dispatch proving machines, shared by the absolute interpreter
;;; lane and the interpreter≡generated differential so each graph descriptor is
;;; written once. Built only through (byte-machine graph).
;;;
;;; Both accept the same single alternative 1 2 3 4 and differ only in their
;;; mismatch MODE. The reexecute machine is the shape sequence-machine.sls
;;; builds from four chained dispatch nodes, so its behaviour is pinned by
;;; tuples measured independently of this node kind. The advance machine gives
;;; the advance path coverage of its own -- the mismatch mode must be an
;;; explicit choice, because an advance-mode mismatch shifts every reported
;;; position by one and nothing would look obviously wrong.
;;;
;;; One alternative, not several: this fixture reproduces a
;;; single-alternative oracle. The LOWERING is trie-shaped and
;;; multi-alternative-capable, and that is pinned at unit level:
;;; normal-ir-tests.sps asserts the merge structurally, and interpret-tests.sps
;;; executes AB/AC through the interpreter. The multi-alternative fixture is
;;; http-version-machine.sls, which adds depth (a seven-byte shared prefix),
;;; absolute tuples, both mismatch modes, and the interpreter≡generated
;;; DIFFERENTIAL across a branch.
(library (byte-machine test sequence-node-machine)
  (export make-sequence-node-machine make-advance-mismatch-machine
          sequence-node-bytes)
  (import (rnrs) (byte-machine graph))

  (define (sequence-node-bytes) '(1 2 3 4))

  (define (build name mismatch-mode)
    (let ((eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
          (rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f)))
      (make-machine name 'seq '() '() '() (list eof-decl rej-decl)
        (list (make-sequence-dispatch-node
               'seq
               (list (make-sequence-case (sequence-node-bytes) 'stop #f))
               (make-edge 'reject mismatch-mode) #f #f)
              (make-stop-node 'stop #f)
              (make-error-node 'reject 'rejected #f))
        'default-eof #f)))

  (define (make-sequence-node-machine) (build 'seqnode 'reexecute))
  (define (make-advance-mismatch-machine) (build 'advseq 'advance)))
