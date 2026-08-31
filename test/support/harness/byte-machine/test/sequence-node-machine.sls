;;; The Milestone 3 Slice ② sequence-dispatch proving machines, shared by the
;;; absolute interpreter lane and the interpreter≡generated differential so each
;;; graph descriptor is written once. Built only through (byte-machine graph).
;;;
;;; Both accept the same single alternative 1 2 3 4 and differ only in their
;;; mismatch MODE. The reexecute machine is the shape Milestone 2's
;;; sequence-machine.sls built from four chained dispatch nodes, so its behaviour
;;; is pinned by tuples measured before this node kind existed. The advance
;;; machine exists because every shipped fixture in this tree uses reexecute, so
;;; the advance path has no coverage at all -- and §11.5:664 requires the choice
;;; to be explicit, because an advance-mode mismatch shifts every reported
;;; position by one and nothing would look obviously wrong.
;;;
;;; One alternative, not several: what this fixture reproduces is a
;;; single-alternative oracle, and it stays one -- Milestone 3 closed without
;;; widening it. The LOWERING is trie-shaped and multi-alternative-capable, and
;;; Slice ②'s own Tasks 2-3 pin that at unit level: normal-ir-tests.sps asserts
;;; the merge structurally, and interpret-tests.sps executes AB/AC through the
;;; interpreter. Slice ③'s multi-alternative fixture is http-version-machine.sls,
;;; and what it added over the two lanes above is depth (a seven-byte shared
;;; prefix), absolute tuples, both mismatch modes, and the
;;; interpreter≡generated DIFFERENTIAL across a branch -- not the first
;;; execution of a shared prefix, which is Slice ②'s.
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
