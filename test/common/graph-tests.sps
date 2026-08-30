;;; The public graph façade supplies every constructor these machines need;
;;; the three machine accessors (machine?, machine-entry,
;;; machine-default-eof-error) are deliberately still private -- see the
;;; import comment below.
(import (rnrs)
        (byte-machine test harness)
        (byte-machine graph)
        ;; Machine ACCESSORS are still private: §9.1 fixes the public
        ;; CONSTRUCTION surface and lists no accessors, and Milestone 3 Slice ①
        ;; declined to widen the façade past that list "for consistency" -- the
        ;; same argument design §8 rejects for source-label. The matcher
        ;; predicates below do come through the façade, because a grammar author
        ;; needs to test the matchers they just built.
        (only (byte-machine private ir) machine? machine-entry machine-default-eof-error))

(harness-begin "unit.graph")

(harness-group "graph façade"
  (lambda ()
    (harness-case "the one-byte machine is constructible through (byte-machine graph)"
      (lambda ()
        (let* ((eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
               (rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))
               (m (make-machine
                   'one-byte 'start '() '() '()
                   (list eof-decl rej-decl)
                   (list (make-byte-dispatch-node
                          'start
                          (list (make-byte-case (make-exact-byte-matcher 0)
                                                (make-edge 'stop 'advance) #f))
                          (make-edge 'reject 'reexecute) #f #f)
                         (make-stop-node 'stop #f)
                         (make-error-node 'reject 'rejected #f))
                   'default-eof #f)))
          (check "is a machine" (machine? m))
          (check-equal "entry" (machine-entry m) 'start)
          (check-equal "default eof name" (machine-default-eof-error m) 'default-eof))))))

(harness-group "the façade builds class matchers"
  (lambda ()
    (harness-case "a set, range, complement and ASCII machine build through the façade's constructors (machine accessors still private)"
      (lambda ()
        (let* ((eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
               (rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))
               (m (make-machine
                   'classes 'start '() '() '()
                   (list eof-decl rej-decl)
                   (list (make-byte-dispatch-node
                          'start
                          (list (make-byte-case (make-byte-set-matcher (ascii-bytes "GET"))
                                                (make-edge 'stop 'advance) #f)
                                (make-byte-case (make-byte-range-matcher 48 57)
                                                (make-edge 'stop 'advance) #f)
                                (make-byte-case (make-byte-complement-matcher
                                                 (make-byte-range-matcher 0 200))
                                                (make-edge 'stop 'advance) #f))
                          (make-edge 'reject 'reexecute) #f #f)
                         (make-stop-node 'stop #f)
                         (make-error-node 'reject 'rejected #f))
                   'default-eof #f)))
          (check "is a machine" (machine? m))
          (check-equal "entry" (machine-entry m) 'start))))
    (harness-case "the façade exports the matcher predicates and accessors"
      (lambda ()
        (check "matcher?" (matcher? (make-byte-range-matcher 1 2)))
        (check-equal "range low" (byte-range-matcher-low (make-byte-range-matcher 1 2)) 1)
        (check-equal "range high" (byte-range-matcher-high (make-byte-range-matcher 1 2)) 2)
        (check-equal "set bytes" (byte-set-matcher-bytes (make-byte-set-matcher '(5 6))) '(5 6))
        (check "complement inner"
               (exact-byte-matcher?
                (byte-complement-matcher-matcher
                 (make-byte-complement-matcher (make-exact-byte-matcher 3)))))))))

(harness-finish)
