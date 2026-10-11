;;; The public graph façade supplies every constructor these machines need;
;;; the three machine accessors (machine?, machine-entry,
;;; machine-default-eof-error) are deliberately private -- see the
;;; import comment below.
(import (rnrs)
        (byte-machine test harness)
        (byte-machine graph)
        ;; Machine ACCESSORS are private: the public surface is CONSTRUCTION
        ;; and carries no accessors, and the façade is not widened past it "for
        ;; consistency". The matcher predicates below do come through the
        ;; façade, because a grammar author needs to test the matchers they
        ;; just built.
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

(harness-group "the façade builds a sequence machine"
  (lambda ()
    (harness-case "a single-alternative sequence machine builds through the façade"
      (lambda ()
        (let* ((eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
               (rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))
               (m (make-machine
                   'seqnode 'seq '() '() '()
                   (list eof-decl rej-decl)
                   (list (make-sequence-dispatch-node
                          'seq (list (make-sequence-case '(1 2 3 4) 'stop #f))
                          (make-edge 'reject 'reexecute) #f #f)
                         (make-stop-node 'stop #f)
                         (make-error-node 'reject 'rejected #f))
                   'default-eof #f)))
          (check "is a machine" (machine? m))
          (check-equal "entry" (machine-entry m) 'seq))))
    (harness-case "the façade exports the sequence predicates and accessors"
      (lambda ()
        (let ((c (make-sequence-case '(1 2) 'stop #f)))
          (check "sequence-case?" (sequence-case? c))
          (check-equal "bytes" (sequence-case-bytes c) '(1 2))
          (check-equal "target" (sequence-case-target c) 'stop))))))

;; The field descriptor reaches grammar authors through the façade. Its
;; predicates and accessors come through as the matchers' do -- an author needs
;; to test what they just built -- while machine ACCESSORS stay private: the
;; public surface is construction-only.
(harness-group "uint fields through the façade"
  (lambda ()
    (harness-case "a field-declaring machine is built from (byte-machine graph) alone"
      (lambda ()
        ;; This program imports nothing but the façade, so if any of these names
        ;; is missing from EITHER the export list or the mirrored `only` import
        ;; list, this file fails at load rather than here. Editing one list and
        ;; not the other leaves the constructor unreachable -- silently at read
        ;; time and loudly at first use.
        (let* ((f (make-uint-field 'count 16 7 #f))
               (m (make-machine 'fielded 'stop (list f) '() '()
                                (list (make-error-declaration 'e 'c "r" #f))
                                (list (make-stop-node 'stop #f)) 'e #f)))
          (check "the descriptor is a field" (uint-field? f))
          (check-equal "name" (uint-field-name f) 'count)
          (check-equal "width" (uint-field-width f) 16)
          (check-equal "initial" (uint-field-initial f) 7)
          (check-equal "label" (uint-field-source-label f) #f)
          (check "the machine was built" (machine? m)))))))


;; The façade reaches the two zero-width kinds.
;; Both lists in graph.sls are hand-maintained mirrors and a name missing from
;; EITHER makes the constructor unreachable to a grammar author, so both are
;; asserted from outside the library -- which is the only place the mirror is
;; observable.
(harness-group "the field node constructors reach grammar authors"
  (lambda ()
    ;; The witness is EXPAND TIME, not run time: a name missing from either list
    ;; is an unbound identifier and this whole program fails to load. `node?` is
    ;; deliberately not available here -- accessors stay private (the public
    ;; surface is CONSTRUCTION only) -- so the assertion is that a machine carrying both
    ;; kinds builds, which also proves make-machine's node guard admits them.
    (harness-case "a machine carrying both field kinds builds through the facade"
      (lambda ()
        (let ((m (make-machine
                  'm 'act (list (make-uint-field 'count 8 0 #f)) '() '()
                  (list (make-error-declaration 'e 'c "r" #f))
                  (list (make-field-action-node 'act 'increment '(count) 'br 'e #f)
                        (make-field-branch-node 'br 'zero '(count) 'stop 'stop #f)
                        (make-stop-node 'stop #f)
                        (make-error-node 'e 'e #f))
                  'e #f)))
          (check "built" (and m #t)))))))

(harness-group "the counted-consume constructor reaches grammar authors (Milestone 6 Slice ①)"
  (lambda ()
    ;; The same expand-time witness as the field-node group above: the
    ;; constructor is in both lists or this program fails to load, and a machine
    ;; carrying the kind builds through make-machine's node guard.
    (harness-case "a machine carrying a counted consume builds through the facade"
      (lambda ()
        (let ((m (make-machine
                  'm 'start (list (make-uint-field 'len 8 0 #f)) '() '()
                  (list (make-error-declaration 'e 'c "r" #f))
                  (list (make-byte-dispatch-node 'start
                          (list (make-byte-case (make-exact-byte-matcher 0)
                                                (make-edge 'body 'advance) #f))
                          (make-edge 'err 'reexecute) #f #f)
                        (make-counted-consume-node 'body 'len 'stop #f #f)
                        (make-stop-node 'stop #f)
                        (make-error-node 'err 'e #f))
                  'e #f)))
          (check "built" (and m #t)))))))

(harness-finish)
