;;; The normalizer lowers a verified machine to numeric-state normalized IR and a
;;; deterministic IR fingerprint. The one-byte machine pins the fingerprint
;;; algorithm (a golden value); a second, out-of-order machine pins the entry
;;; assignment and transition sort, which one dispatch case cannot witness.
(import (rnrs)
        (byte-machine test harness)
        (byte-machine test eof-machine)
        (byte-machine test pause-machine)
        (byte-machine graph)
        (byte-machine verify)
        (byte-machine private normal-ir))

(harness-begin "unit.normal-ir")

(define eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
(define rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))

(define one-byte
  (make-machine 'one-byte 'start '() '() '() (list eof-decl rej-decl)
    (list (make-byte-dispatch-node 'start
            (list (make-byte-case (make-exact-byte-matcher 0) (make-edge 'stop 'advance) #f))
            (make-edge 'reject 'reexecute) #f #f)
          (make-stop-node 'stop #f)
          (make-error-node 'reject 'rejected #f))
    'default-eof #f))

(define (normalize m) (normalize-machine (verification-machine (verify-machine m))))
(define n1 (normalize one-byte))

(harness-group "the one-byte machine"
  (lambda ()
    (harness-case "entry is the first node's id"
      (lambda () (check-equal "entry" (normal-machine-entry n1) 0)))
    (harness-case "three states, in declaration order"
      (lambda ()
        (let ((s (normal-machine-states n1)))
          (check-equal "count" (vector-length s) 3)
          (check-equal "state 0 kind" (normal-state-kind (vector-ref s 0)) 'dispatch)
          (check-equal "state 1 kind" (normal-state-kind (vector-ref s 1)) 'stop)
          (check-equal "state 2 kind" (normal-state-kind (vector-ref s 2)) 'error))))
    (harness-case "state ids are the declaration indices"
      (lambda ()
        (let ((s (normal-machine-states n1)))
          (check-equal "id 0" (normal-state-id (vector-ref s 0)) 0)
          (check-equal "id 1" (normal-state-id (vector-ref s 1)) 1)
          (check-equal "id 2" (normal-state-id (vector-ref s 2)) 2))))
    (harness-case "the dispatch state lowers its case and fallback to ids"
      (lambda ()
        (let ((d (vector-ref (normal-machine-states n1) 0)))
          (check-equal "transitions" (normal-dispatch-transitions d) '((0 1 advance)))
          (check-equal "fallback" (normal-dispatch-fallback d) '(2 . reexecute)))))
    (harness-case "the error state carries the resolved error CODE, not its name"
      (lambda ()
        (check-equal "code" (normal-error-code (vector-ref (normal-machine-states n1) 2))
                     'unexpected-byte)))
    ;; Golden value: measured against this exact encoding (format tag 1; entry and
    ;; state-count as u32be; per dispatch state u16be transition count then each
    ;; (u8 byte, u32be target, u8 mode) ascending by byte, then u32be fallback
    ;; target + u8 mode, then eof routing (tag 0 + u32be node id, or tag 1 +
    ;; u16be code-length + UTF-8 default-eof code bytes); stop = one tag byte;
    ;; error = tag byte + u16be code-length + UTF-8 code bytes; finish = one tag
    ;; byte) run through FNV-1a. A change to any FNV constant, the XOR/multiply,
    ;; or the field layout (eof routing included) moves this number.
    (harness-case "the IR fingerprint is the measured golden value"
      (lambda ()
        (check-equal "fingerprint" (normal-machine-fingerprint n1)
                     4236938459847922092)))
    (harness-case "normalization is deterministic"
      (lambda ()
        (check-equal "same fingerprint twice"
                     (normal-machine-fingerprint (normalize one-byte))
                     (normal-machine-fingerprint n1))))))

;; Entry is the second node; the dispatch node lists byte 5 before byte 2.
(define two
  (make-machine 'two 'go '() '() '() (list eof-decl rej-decl)
    (list (make-stop-node 'halt #f)
          (make-byte-dispatch-node 'go
            (list (make-byte-case (make-exact-byte-matcher 5) (make-edge 'halt 'advance) #f)
                  (make-byte-case (make-exact-byte-matcher 2) (make-edge 'halt 'advance) #f))
            (make-edge 'bad 'reexecute) #f #f)
          (make-error-node 'bad 'rejected #f))
    'default-eof #f))
(define n2 (normalize two))

(harness-group "entry and transition order"
  (lambda ()
    (harness-case "entry is the id of the entry node, not node 0"
      (lambda () (check-equal "entry" (normal-machine-entry n2) 1)))
    (harness-case "transitions are sorted ascending by byte"
      (lambda ()
        (check-equal "bytes"
                     (map car (normal-dispatch-transitions (vector-ref (normal-machine-states n2) 1)))
                     '(2 5))))))

;; The one-byte machine's eof routes to the machine default-eof error (encode
;; tag 1 + code symbol), so its fingerprint cannot witness the NODE-eof arm
;; (tag 0 + u32be node id). The shared eof-machine's two dispatch states BOTH
;; route eof to named nodes -- s0 -> finish 'done, s1 -> error 'trunc -- so its
;; fingerprint is the only golden that moves when the node-routing payload is
;; dropped from the canonical encoding. Same measured-golden discipline as the
;; one-byte case above; normalized identically through `normalize`.
(define eofm (make-eof-machine))
(define n-eof (normalize eofm))

(harness-group "node-routing eof encoding"
  (lambda ()
    (harness-case "both dispatch states route eof to a node, not the default error"
      (lambda ()
        (let ((s (normal-machine-states n-eof)))
          (check-equal "s0 eof" (car (normal-dispatch-eof (vector-ref s 0))) 'node)
          (check-equal "s1 eof" (car (normal-dispatch-eof (vector-ref s 1))) 'node))))
    (harness-case "the IR fingerprint of the node-routing machine is the measured golden value"
      (lambda ()
        (check-equal "fingerprint" (normal-machine-fingerprint n-eof)
                     9098559711816935340)))))

;; The pause tag (4) plus its u32be continuation id (D5) is not exercised by
;; the one-byte or node-routing goldens above -- neither fixture has a pause
;; node -- so this is the only golden that moves when the pause encode arm's
;; bytes change. Same measured-golden discipline as those two cases; node
;; order s0 p1 s1 pe stop done trunc reject -> ids 0..7, normalized
;; identically through `normalize`.
(define pausem (make-pause-machine))
(define n-pause (normalize pausem))

(harness-group "pause normalization (Slice 3)"
  (lambda ()
    (harness-case "pause states lower to kind pause with the continuation id"
      (lambda ()
        (let* ((states (normal-machine-states n-pause))
               (p1 (vector-ref states 1))
               (pe (vector-ref states 3)))
          (check-equal "p1 kind" (normal-state-kind p1) 'pause)
          (check-equal "p1 target" (normal-pause-target p1) 2)
          (check-equal "pe kind" (normal-state-kind pe) 'pause)
          (check-equal "pe target" (normal-pause-target pe) 5))))
    (harness-case "the pause encoding is pinned by a fingerprint golden"
      (lambda ()
        (check-equal "pause fingerprint" (normal-machine-fingerprint n-pause)
                     15725897457025557005)))))

(harness-finish)
