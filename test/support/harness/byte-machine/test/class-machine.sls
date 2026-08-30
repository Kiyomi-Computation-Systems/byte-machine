;;; The Milestone 3 Slice ① byte-class proving machines, shared by the absolute
;;; all-256 interpreter lane and the interpreter≡generated differential so each
;;; graph descriptor is written once. Built only through (byte-machine graph).
;;;
;;; Each machine has the same shape as the M1 one-byte machine -- one dispatch
;;; node, one accepting case, a reexecute fallback into the reject error -- so
;;; the only variable under test is the matcher. Every fallback REEXECUTES, so a
;;; rejected byte's `next` points AT the offending byte (parent §11.5).
;;;
;;; The five cover the matcher repertoire and its two hazards: a set given in
;;; non-ascending order WITH a duplicate (canonicalization must sort and
;;; de-duplicate, or the node overlaps itself); and a complement of a complement
;;; (§9.1:294 complements a MATCHER, so canonicalization is recursive -- a
;;; single-level complement cannot witness that).
(library (byte-machine test class-machine)
  (export make-byte-set-machine make-byte-range-machine
          make-byte-complement-machine make-nested-complement-machine
          make-ascii-machine class-machines)
  (import (rnrs) (byte-machine graph))

  (define (class-machine name matcher)
    (let ((eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
          (rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f)))
      (make-machine name 'start '() '() '() (list eof-decl rej-decl)
        (list (make-byte-dispatch-node 'start
                (list (make-byte-case matcher (make-edge 'stop 'advance) #f))
                (make-edge 'reject 'reexecute) #f #f)
              (make-stop-node 'stop #f)
              (make-error-node 'reject 'rejected #f))
        'default-eof #f)))

  ;; Deliberately unsorted and holding a duplicate: decision 0017 point 3 leaves
  ;; both to canonicalization rather than to the constructor.
  (define (make-byte-set-machine)
    (class-machine 'byte-set (make-byte-set-matcher '(254 1 0 1 255 2))))
  (define (make-byte-range-machine)
    (class-machine 'byte-range (make-byte-range-matcher 97 122)))
  (define (make-byte-complement-machine)
    (class-machine 'byte-complement
                   (make-byte-complement-matcher (make-byte-set-matcher '(10 13)))))
  (define (make-nested-complement-machine)
    (class-machine 'nested-complement
                   (make-byte-complement-matcher
                    (make-byte-complement-matcher (make-byte-range-matcher 48 57)))))
  (define (make-ascii-machine)
    (class-machine 'ascii-set (make-byte-set-matcher (ascii-bytes "GET"))))

  (define (range-list low high)
    (let loop ((b high) (acc '())) (if (< b low) acc (loop (- b 1) (cons b acc)))))
  (define (universe-without excluded)
    (let loop ((b 255) (acc '()))
      (cond ((< b 0) acc)
            ((memv b excluded) (loop (- b 1) acc))
            (else (loop (- b 1) (cons b acc))))))

  ;; (name machine accepted-bytes); accepted-bytes ascending, duplicate-free.
  (define (class-machines)
    (list (list 'byte-set (make-byte-set-machine) '(0 1 2 254 255))
          (list 'byte-range (make-byte-range-machine) (range-list 97 122))
          (list 'byte-complement (make-byte-complement-machine) (universe-without '(10 13)))
          (list 'nested-complement (make-nested-complement-machine) (range-list 48 57))
          (list 'ascii-set (make-ascii-machine) '(69 71 84)))))
