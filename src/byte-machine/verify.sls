;;; (byte-machine verify): structural verification of a source machine into a
;;; verification-result carrying diagnostics and the machine (parent §16). M1
;;; subset of §16.2/§16.3: schema, name resolution (nodes + error references),
;;; exact-byte overlap, reachability, zero-progress cycles, terminal/EOF shape,
;;; and generated-name safety (reserved-set member 1 — Gate 0 §3.3). Error
;;; references are symbolic names resolved against the error declarations.
;;; Diagnostics are compared by code, never by text.
(library (byte-machine verify)
  (export verify-machine verification-ok? verification-diagnostics
          verification-machine
          diagnostic? diagnostic-code diagnostic-node diagnostic-message)
  (import (rnrs)
          (byte-machine private ir))

  ;; --- diagnostics ---
  (define diagnostic-tag (vector 'byte-machine-diagnostic))
  (define (make-diagnostic code node message) (vector diagnostic-tag code node message))
  (define (diagnostic? x)
    (and (vector? x) (> (vector-length x) 0) (eq? (vector-ref x 0) diagnostic-tag)))
  (define (diagnostic-code d) (vector-ref d 1))
  (define (diagnostic-node d) (vector-ref d 2))
  (define (diagnostic-message d) (vector-ref d 3))

  ;; --- name grammar [a-z][a-z0-9-]* and reserved-set member 1 ---
  (define reserved-member-1
    '(library import export define define-syntax let let* letrec lambda quote
      if begin set! cond case and or when unless do quasiquote unquote))
  (define (lower-alpha? c) (and (char>=? c #\a) (char<=? c #\z)))
  (define (name-char? c)
    (or (lower-alpha? c) (and (char>=? c #\0) (char<=? c #\9)) (char=? c #\-)))
  (define (valid-name? sym)
    (let ((s (symbol->string sym)))
      (and (> (string-length s) 0)
           (lower-alpha? (string-ref s 0))
           (let loop ((i 1))
             (or (>= i (string-length s))
                 (and (name-char? (string-ref s i)) (loop (+ i 1)))))
           (not (memq sym reserved-member-1)))))

  ;; --- helpers ---
  (define (lookup nodes name)
    (cond ((null? nodes) #f)
          ((eq? (node-name (car nodes)) name) (car nodes))
          (else (lookup (cdr nodes) name))))
  (define (error-names m) (map error-declaration-name (machine-errors m)))
  (define (node-out-targets n)
    (cond ((byte-dispatch-node? n)
           (append (map (lambda (c) (edge-target (byte-case-edge c)))
                        (byte-dispatch-node-cases n))
                   (list (edge-target (byte-dispatch-node-fallback n)))))
          ;; A pause's single zero-width out-edge (§10.6): resolution-checked by
          ;; PASS 2 (a malformed continuation is 'missing-target, §16.2:905) and
          ;; walked by reachability. The §16.2:908 dispatch check below filters
          ;; on byte-dispatch-node?, so this arm does not feed it.
          ((pause-node? n) (list (pause-node-continuation n)))
          (else '())))
  ;; byte out-targets PLUS a dispatch node's eof-target (for reachability only).
  (define (all-out-targets n)
    (append (node-out-targets n)
            (if (byte-dispatch-node? n)
                (let ((t (byte-dispatch-node-eof-target n)))
                  (if (symbol? t) (list t) '()))
                '())))

  ;; Visited-set DFS from the machine's entry, following whatever edge
  ;; function `targets` selects (node-out-targets, all-out-targets, ...).
  ;; Returns the reached node names. Shared by pass-reachability and
  ;; byte-reached, which differ only in which edge function they walk.
  (define (reach-from m targets)
    (let ((nodes (machine-nodes m)) (reached '()))
      (let visit ((name (machine-entry m)))
        (let ((n (lookup nodes name)))
          (when (and n (not (memq name reached)))
            (set! reached (cons name reached))
            (for-each visit (targets n)))))
      reached))

  ;; PASS 1: schema.
  (define (pass-schema m)
    (if (machine? m) '() (list (make-diagnostic 'invalid-shape #f "not a machine"))))

  ;; PASS 2: name resolution — duplicate node names; duplicate error names; every
  ;; transition target and error reference resolves.
  (define (pass-names m)
    (let ((nodes (machine-nodes m)) (enames (error-names m)))
      (append
       (let loop ((ns nodes) (seen '()) (out '()))
         (if (null? ns) (reverse out)
             (let ((nm (node-name (car ns))))
               (loop (cdr ns) (cons nm seen)
                     (if (memq nm seen)
                         (cons (make-diagnostic 'duplicate-name nm "duplicate node name") out)
                         out)))))
       (let loop ((es enames) (seen '()) (out '()))
         (if (null? es) (reverse out)
             (loop (cdr es) (cons (car es) seen)
                   (if (memq (car es) seen)
                       (cons (make-diagnostic 'duplicate-error-declaration (car es)
                                              "duplicate error declaration name") out)
                       out))))
       (apply append
              (map (lambda (n)
                     (filter values
                             (map (lambda (t)
                                    (if (lookup nodes t) #f
                                        (make-diagnostic 'missing-target t "no such node")))
                                  (node-out-targets n))))
                   nodes))
       (if (lookup nodes (machine-entry m)) '()
           (list (make-diagnostic 'missing-target (machine-entry m) "entry names no node")))
       (apply append
              (map (lambda (n)
                     (if (and (error-node? n) (not (memq (error-node-error-name n) enames)))
                         (list (make-diagnostic 'missing-error-declaration (node-name n)
                                                "error node names an undeclared error"))
                         '()))
                   nodes)))))

  ;; PASS 3: exact-byte overlap within a dispatch node.
  (define (pass-overlap m)
    (apply append
           (map (lambda (n)
                  (if (byte-dispatch-node? n)
                      (let loop ((cs (byte-dispatch-node-cases n)) (seen '()) (out '()))
                        (if (null? cs) out
                            (let ((b (exact-byte-matcher-byte (byte-case-matcher (car cs)))))
                              (loop (cdr cs) (cons b seen)
                                    (if (memv b seen)
                                        (cons (make-diagnostic 'overlapping-cases (node-name n)
                                                               "two cases match the same byte") out)
                                        out)))))
                      '()))
                (machine-nodes m))))

  ;; PASS 4: reachability from entry.
  (define (pass-reachability m)
    (let ((nodes (machine-nodes m)) (reached (reach-from m all-out-targets)))
      (filter values
              (map (lambda (n)
                     (if (memq (node-name n) reached) #f
                         (make-diagnostic 'unreachable-node (node-name n) "node is unreachable")))
                   nodes))))

  ;; PASS 5: zero-progress cycles — a reexecute-only cycle consumes no byte.
  (define (pass-zero-progress m)
    (let ((nodes (machine-nodes m)))
      (define (reexec-targets n)
        (cond ((byte-dispatch-node? n)
               (append (map (lambda (c) (edge-target (byte-case-edge c)))
                            (filter (lambda (c) (eq? (edge-mode (byte-case-edge c)) 'reexecute))
                                    (byte-dispatch-node-cases n)))
                       (if (eq? (edge-mode (byte-dispatch-node-fallback n)) 'reexecute)
                           (list (edge-target (byte-dispatch-node-fallback n))) '())))
              ;; A pause consumes no input (§12.4, design §6): its continuation
              ;; is a zero-width edge, so a reexecute/pause-only cycle with no
              ;; advance is a zero-progress cycle.
              ((pause-node? n) (list (pause-node-continuation n)))
              (else '())))
      (define (reaches-self? start)
        (let loop ((frontier (reexec-targets (lookup nodes start))) (seen '()))
          (cond ((null? frontier) #f)
                ((eq? (car frontier) start) #t)
                ((memq (car frontier) seen) (loop (cdr frontier) seen))
                (else (let ((n (lookup nodes (car frontier))))
                        (loop (append (if n (reexec-targets n) '()) (cdr frontier))
                              (cons (car frontier) seen)))))))
      (filter values
              (map (lambda (n)
                     (if (and (or (byte-dispatch-node? n) (pause-node? n)) (reaches-self? (node-name n)))
                         (make-diagnostic 'zero-progress-cycle (node-name n)
                                          "a zero-width cycle (reexecute edges/pause continuations) makes no progress")
                         #f))
                   nodes))))

  ;; PASS 6: EOF shape — the machine default eof error names a declared error;
  ;; a dispatch eof-target (when a symbol) resolves to a node.
  (define (pass-eof m)
    (let ((nodes (machine-nodes m)))
      (append
       (if (memq (machine-default-eof-error m) (error-names m)) '()
           (list (make-diagnostic 'invalid-eof-target (machine-default-eof-error m)
                                  "machine default eof error names no declared error")))
       (apply append
              (map (lambda (n)
                     (if (byte-dispatch-node? n)
                         (let ((t (byte-dispatch-node-eof-target n)))
                           (if (or (eq? t #f) (lookup nodes t)) '()
                               (list (make-diagnostic 'invalid-eof-target (node-name n)
                                                      "eof-target names no node"))))
                         '()))
                   nodes)))))

  ;; Walk the eof-target chain from `start`, classifying its terminal.
  (define (eof-terminal m start)
    (let ((nodes (machine-nodes m)))
      (let loop ((name start) (seen '()))
        (if (memq name seen) 'cycle
            (let ((n (lookup nodes name)))
              (cond ((not n) 'unresolved)             ; pass-eof reports missing target
                    ((finish-node? n) 'finish)
                    ((error-node? n) 'error)
                    ((stop-node? n) 'eof-reachable-stop)
                    ((pause-node? n) (loop (pause-node-continuation n) (cons name seen)))
                    ((byte-dispatch-node? n)
                     (let ((t (byte-dispatch-node-eof-target n)))
                       (if (symbol? t) (loop t (cons name seen)) 'default-error)))
                    (else 'unknown)))))))

  ;; Byte-flow reachability (feed can arrive): entry DFS over node-out-targets
  ;; -- dispatch case/fallback edges plus reached-pause continuations --
  ;; excluding eof-targets. An eof-only-reachable pause legally continues into
  ;; a finish node (decision 0011); a byte-reachable one must not (§16.2:908).
  (define (byte-reached m) (reach-from m node-out-targets))

  ;; §16.2:908/:909 and the separate EOF zero-progress-cycle check.
  (define (pass-eof-execution m)
    (let ((nodes (machine-nodes m)))
      (append
       ;; :908 — a byte edge (case or fallback) into a finish terminal.
       (apply append
              (map (lambda (n)
                     (if (byte-dispatch-node? n)
                         (filter values
                                 (map (lambda (t)
                                        (let ((tn (lookup nodes t)))
                                          (if (and tn (finish-node? tn))
                                              (make-diagnostic 'non-eof-into-finish (node-name n)
                                                               "a byte edge targets a finish terminal")
                                              #f)))
                                      (node-out-targets n)))
                         '()))
                   nodes))
       ;; :909 + the EOF-cycle check — walk each dispatch node's eof-target chain.
       (apply append
              (map (lambda (n)
                     (if (byte-dispatch-node? n)
                         (let ((t (byte-dispatch-node-eof-target n)))
                           (if (symbol? t)
                               (case (eof-terminal m t)
                                 ((eof-reachable-stop)
                                  (list (make-diagnostic 'eof-reachable-stop (node-name n)
                                                         "an EOF path reaches a stop terminal")))
                                 ((cycle)
                                  (list (make-diagnostic 'eof-zero-progress-cycle (node-name n)
                                                         "an EOF path cycles without reaching a terminal")))
                                 (else '()))
                               '()))
                         '()))
                   nodes))
       ;; D4(b)/(d): checks keyed on byte-reachability. A feed pause parks
       ;; current on its continuation and resume returns the row to ready, so
       ;; every byte-reachable pause's continuation is both a feed re-entry
       ;; point (:908 -- it must not be a finish terminal) and a possible EOF-
       ;; processing start (:909 -- its chain must reach finish or error,
       ;; never a stop, never a cycle).
       (let ((br (byte-reached m)))
         (append
          (apply append
                 (map (lambda (n)
                        (if (and (pause-node? n) (memq (node-name n) br))
                            (let ((cn (lookup nodes (pause-node-continuation n))))
                              (if (and cn (finish-node? cn))
                                  (list (make-diagnostic 'non-eof-into-finish (node-name n)
                                                         "a pause continuation byte-reaches a finish terminal"))
                                  '()))
                            '()))
                      nodes))
          (apply append
                 (map (lambda (n)
                        (if (and (pause-node? n) (memq (node-name n) br))
                            (case (eof-terminal m (pause-node-continuation n))
                              ((eof-reachable-stop)
                               (list (make-diagnostic 'eof-reachable-stop (node-name n)
                                                      "an EOF path reaches a stop terminal")))
                              ((cycle)
                               (list (make-diagnostic 'eof-zero-progress-cycle (node-name n)
                                                      "an EOF path cycles without reaching a terminal")))
                              (else '()))
                            '()))
                      nodes)))))))

  ;; PASS 7: generated-name safety (member 1) — machine, node, error names/codes.
  (define (pass-names-valid m)
    (append
     (if (valid-name? (machine-name m)) '()
         (list (make-diagnostic 'invalid-name (machine-name m) "machine name is not portable")))
     (filter values
             (map (lambda (n)
                    (if (valid-name? (node-name n)) #f
                        (make-diagnostic 'invalid-name (node-name n) "node name is not portable")))
                  (machine-nodes m)))
     (filter values
             (map (lambda (e)
                    (if (and (valid-name? (error-declaration-name e))
                             (valid-name? (error-declaration-code e)))
                        #f
                        (make-diagnostic 'invalid-name (error-declaration-name e)
                                         "error name or code is not portable")))
                  (machine-errors m)))))

  (define (verify-machine machine)
    (let ((ds (append (pass-schema machine)
                      (if (machine? machine)
                          (append (pass-names machine)
                                  (pass-overlap machine)
                                  (pass-reachability machine)
                                  (pass-zero-progress machine)
                                  (pass-eof machine)
                                  (pass-eof-execution machine)
                                  (pass-names-valid machine))
                          '()))))
      (make-verification-result (null? ds) ds machine)))

  (define (verification-ok? v) (verification-result-ok? v))
  (define (verification-diagnostics v) (verification-result-diagnostics v))
  (define (verification-machine v) (verification-result-machine v)))
