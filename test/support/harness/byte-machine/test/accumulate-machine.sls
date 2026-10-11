;;; A proving machine for the integer-accumulate node, an INPUT-READING kind,
;;; in the shape whose EMISSION is worth pinning against a committed golden.
;;;
;;; Base 16 rather than base 10, deliberately. The emitter renders the digit
;;; test as a range comparison per base, and base 16 is the shape with three
;;; disjoint ASCII ranges -- so the golden carries the whole rendered arm rather
;;; than the one-range fast path a base 10 machine would produce.
;;;
;;; Both EOF routes appear, which is what makes the golden cover the routing the
;;; emitter chooses per state rather than per machine: the accumulate node names
;;; `done` explicitly, while the entry dispatch declares none and falls to the
;;; machine default. A golden showing only one of the two would miss a defect
;;; that lives exactly in that difference -- e.g. compile.sls's
;;; reached-declaration walk crediting only dispatch states with the default
;;; route.
(library (byte-machine test accumulate-machine)
  (export make-accumulate-machine)
  (import (rnrs)
          (byte-machine graph))

  (define (make-accumulate-machine)
    (let ((errs (list (make-error-declaration 'default-eof 'eof
                                              "unexpected end of input" #f)
                      (make-error-declaration 'too-big 'unexpected-byte
                                              "field overflow" #f)
                      (make-error-declaration 'rejected 'unexpected-byte
                                              "unexpected byte" #f))))
      (make-machine 'accm 'start
                    (list (make-uint-field 'value 16 0 #f))
                    '() '() errs
                    (list
                     ;; `#` opens the number and is CONSUMED; everything else is
                     ;; rejected. An advance here (rather than the reexecute the
                     ;; property generator needs) keeps the opener out of the
                     ;; accumulated value.
                     (make-byte-dispatch-node
                      'start
                      (list (make-byte-case (make-exact-byte-matcher 35)
                                            (make-edge 'acc 'advance) #f))
                      (make-edge 'reject 'reexecute)
                      #f #f)
                     (make-integer-accumulate-node
                      'acc 'value 16 'acc
                      (make-edge 'stopped 'advance)
                      'over
                      ;; Named explicitly: input ending mid-number is a complete
                      ;; number here, not a truncation.
                      'done #f)
                     (make-finish-node 'done #f)
                     (make-stop-node 'stopped #f)
                     (make-error-node 'over 'too-big #f)
                     (make-error-node 'reject 'rejected #f))
                    'default-eof #f))))
