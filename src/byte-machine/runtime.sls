;;; (byte-machine runtime): parser lifecycle, statuses, callback outcome
;;; singletons, and the compiled-machine ABI. Independent of graph/verify/
;;; compile (parent §7.2). Two executor variants share this one parser API and
;;; the one parser-result contract: the reference interpreter builds an `op`
;;; message closure over the source IR; generated code (Phase 3, decision 0010)
;;; is a direct resumable executor constructed through
;;; byte-machine-make-compiled-machine/v1. The two are deliberately different
;;; implementations, which is what lets the interpreter≡generated differential
;;; catch lowering defects (parent §18, §22.4).
(library (byte-machine runtime)
  (export make-compiled-machine compiled-machine?
          byte-machine-make-compiled-machine/v1 byte-machine-make-feed-outcome/v1
          make-parser parser?
          parser-feed!
          parser-result? parser-result-status parser-result-next
          parser-result-consumed parser-result-stream-offset parser-result-error
          callback-continue callback-pause)
  (import (rnrs))

  (define (tag sym) (vector sym))
  (define (tagged? t x) (and (vector? x) (> (vector-length x) 0) (eq? (vector-ref x 0) t)))

  ;; Allocation-free outcome singletons (parent §13). M1 exercises neither;
  ;; they fix the contract so interpreter and generated callbacks return the
  ;; same objects once callbacks land.
  (define callback-continue (vector 'byte-machine-callback-continue))
  (define callback-pause (vector 'byte-machine-callback-pause))

  ;; --- compiled machine: two variants behind one type ---
  ;; op:  (vector tag 'op op-closure)               -- the reference interpreter
  ;; v1:  (vector tag 'v1 feed entry-state fingerprint) -- generated code
  (define compiled-machine-tag (tag 'byte-machine-compiled-machine))
  (define (make-compiled-machine op)
    (unless (procedure? op)
      (assertion-violation 'make-compiled-machine "op must be a procedure" op))
    (vector compiled-machine-tag 'op op))
  (define (compiled-machine? x) (tagged? compiled-machine-tag x))
  (define (compiled-machine-variant cm) (vector-ref cm 1))

  (define current-abi-version 1)
  (define (byte-machine-make-compiled-machine/v1 abi-version ir-fingerprint entry-state feed)
    (unless (and (integer? abi-version) (= abi-version current-abi-version))
      (assertion-violation 'byte-machine-make-compiled-machine/v1
                           "generated-runtime ABI mismatch" abi-version))
    (unless (procedure? feed)
      (assertion-violation 'byte-machine-make-compiled-machine/v1 "feed must be a procedure" feed))
    (vector compiled-machine-tag 'v1 feed entry-state ir-fingerprint))

  ;; --- feed outcome (the runtime<-generated seam; accessors private) ---
  (define feed-outcome-tag (tag 'byte-machine-feed-outcome))
  (define (byte-machine-make-feed-outcome/v1 status next error next-state offset)
    (vector feed-outcome-tag status next error next-state offset))
  (define (feed-outcome-status o) (vector-ref o 1))
  (define (feed-outcome-next o) (vector-ref o 2))
  (define (feed-outcome-error o) (vector-ref o 3))
  (define (feed-outcome-next-state o) (vector-ref o 4))
  (define (feed-outcome-offset o) (vector-ref o 5))

  ;; --- parser result (immutable snapshot) ---
  (define parser-result-tag (tag 'byte-machine-parser-result))
  (define (make-parser-result status next consumed stream-offset error)
    (vector parser-result-tag status next consumed stream-offset error))
  (define (parser-result? x) (tagged? parser-result-tag x))
  (define (parser-result-status r) (vector-ref r 1))
  (define (parser-result-next r) (vector-ref r 2))
  (define (parser-result-consumed r) (vector-ref r 3))
  (define (parser-result-stream-offset r) (vector-ref r 4))
  (define (parser-result-error r) (vector-ref r 5))

  ;; --- parser (mutable state behind procedures) ---
  ;; (vector tag variant executor current offset sticky)
  (define parser-tag (tag 'byte-machine-parser))
  (define (make-parser compiled-machine callback-bindings user-context)
    (unless (compiled-machine? compiled-machine)
      (assertion-violation 'make-parser "not a compiled machine" compiled-machine))
    (if (eq? (compiled-machine-variant compiled-machine) 'op)
        (let ((op (vector-ref compiled-machine 2)))
          (vector parser-tag 'op op (op 'entry) 0 #f))
        (let ((feed (vector-ref compiled-machine 2))
              (entry-state (vector-ref compiled-machine 3)))
          (vector parser-tag 'v1 feed entry-state 0 #f))))
  (define (parser? x) (tagged? parser-tag x))
  (define (parser-variant p) (vector-ref p 1))
  (define (parser-executor p) (vector-ref p 2))
  (define (parser-current p) (vector-ref p 3))
  (define (parser-set-current! p v) (vector-set! p 3 v))
  (define (parser-offset p) (vector-ref p 4))
  (define (parser-set-offset! p v) (vector-set! p 4 v))
  (define (parser-sticky p) (vector-ref p 5))
  (define (parser-set-sticky! p v) (vector-set! p 5 v))

  (define (parser-feed! parser bv start end)
    (unless (and (bytevector? bv) (<= 0 start end (bytevector-length bv)))
      (assertion-violation 'parser-feed! "invalid slice" (list start end)))
    (or (parser-sticky parser)
        (if (eq? (parser-variant parser) 'op)
            (parser-feed-op! parser bv start end)
            (parser-feed-v1! parser bv start end))))

  ;; The interpreter path, unchanged from Phase 2 (its decisions are witnessed by
  ;; SchemeMutationSuite Pass 32; the three FIND anchors live here).
  (define (parser-feed-op! parser bv start end)
    (let ((op (parser-executor parser)))
      (let loop ((pos start))
        (let ((node (parser-current parser)))
          (case (op 'kind node)
            ((stop)
             (let ((r (make-parser-result 'stopped pos (- pos start)
                                          (parser-offset parser) #f)))
               (parser-set-sticky! parser r) r))
            ((error)
             (let ((r (make-parser-result 'error pos (- pos start)
                                          (parser-offset parser)
                                          (op 'error-value node))))
               (parser-set-sticky! parser r) r))
            ((dispatch)
             (if (>= pos end)
                 (make-parser-result 'need-input pos (- pos start)
                                     (parser-offset parser) #f)
                 (let* ((byte (bytevector-u8-ref bv pos))
                        (trans (op 'dispatch node byte))
                        (target (car trans))
                        (mode (cdr trans)))
                   (parser-set-current! parser target)
                   (if (eq? mode 'advance)
                       (begin
                         (parser-set-offset! parser (+ 1 (parser-offset parser)))
                         (loop (+ pos 1)))
                       (loop pos)))))
            (else (assertion-violation 'parser-feed! "unknown node kind"
                                       (op 'kind node))))))))

  ;; The generated path: the feed owns the dispatch loop and returns one outcome;
  ;; the runtime commits resume state and builds the result (single source of the
  ;; parser-result shape).
  (define (parser-feed-v1! parser bv start end)
    (let* ((feed (parser-executor parser))
           (o (feed (parser-current parser) (parser-offset parser) bv start end))
           (status (feed-outcome-status o))
           (next (feed-outcome-next o)))
      (parser-set-current! parser (feed-outcome-next-state o))
      (parser-set-offset! parser (feed-outcome-offset o))
      (let ((r (make-parser-result status next (- next start)
                                   (feed-outcome-offset o) (feed-outcome-error o))))
        (if (or (eq? status 'stopped) (eq? status 'error)) (parser-set-sticky! parser r))
        r))))
