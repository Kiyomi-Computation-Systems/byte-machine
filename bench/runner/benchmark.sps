;;; Milestone 9 Slice ③: the v0.1 compiled-benchmark runner (§23.1, §23.2).
;;;
;;; Produces the committed baseline artefact §23.1 specifies: canonical workload
;;; bytes, deterministic seeds, harness version, exact commands, raw samples,
;;; summarised statistics, and a distinction between required metrics and metrics
;;; unavailable on this runtime. v0.1 RECORDS baselines and has NO noisy CI perf
;;; gate (§23.1); this runner is not a gating lane. The one gated, deterministic
;;; property — no per-byte allocation in the generated path — is asserted
;;; separately by test/common/allocation-audit-tests.sps (decision 0040).
;;;
;;; This slice records and does not act: §23.3's admission rule is not met for
;;; anything in §29 and no optimisation is attempted (§26:1679 "without
;;; speculative optimization").
;;;
;;; Run (the exact command recorded in the artefact):
;;;   chez --script test/support/launchers/chez-source.ss \
;;;     --library-root test/support/harness --library-root src \
;;;     --object-guard build/dev/chez-object-guard \
;;;     --program bench/runner/benchmark.sps
;;; with BYTE_MACHINE_TEST_TMPDIR set (for the emitted generated library) and,
;;; optionally, BYTE_MACHINE_BENCH_OUT (artefact path; default stdout),
;;; BYTE_MACHINE_BENCH_ROUNDS and BYTE_MACHINE_BENCH_INNER (defaults 7 / 200).
(import (rnrs) (rnrs eval)
        (only (chezscheme) load statistics sstats-bytes collect real-time
              compile-file compile-file-message)
        (byte-machine test harness)
        (byte-machine test http-machine)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime)
        (byte-machine compile))

(define (env name default)
  (let ((v (adapter-environment-variable name)))
    (if (and v (not (string=? v ""))) v default)))
(define tmpdir (env "BYTE_MACHINE_TEST_TMPDIR" "/tmp"))
(define rounds (string->number (env "BYTE_MACHINE_BENCH_ROUNDS" "7")))
(define inner  (string->number (env "BYTE_MACHINE_BENCH_INNER" "200")))

;; --- the two executors ------------------------------------------------------
(define ok (compile-machine (make-http-machine) '()))
(define gen-file (string-append tmpdir "/http-bench-gen.sls"))
(define t-emit-0 (real-time))
(call-with-port (open-file-output-port gen-file (file-options no-fail))
  (lambda (p) (emit-machine ok 'httpreq p)))
(define emit-ms (- (real-time) t-emit-0))
(define generated-source-size (bytevector-length (render-machine ok 'httpreq)))
(load gen-file)
(define generated (eval 'httpreq (environment '(generated httpreq))))
(define interpreted (make-interpreted-machine (verify-machine (make-http-machine))))

;; --- §23.2 workloads, as canonical bytes ------------------------------------
(define (b s) (u8-list->bytevector (map char->integer (string->list s))))
(define (rep-str n s)
  (let loop ((i 0) (acc "")) (if (= i n) acc (loop (+ i 1) (string-append acc s)))))
(define crlf "\r\n")
(define short-normal (string-append "GET / HTTP/1.1" crlf "Host: example.com" crlf crlf))
(define many-headers
  (string-append "GET / HTTP/1.1" crlf
                 (rep-str 30 (string-append "X-Header-Name: value" crlf)) crlf))
(define long-spans
  (string-append "GET /" (rep-str 2000 "a") " HTTP/1.1" crlf "Host: x" crlf crlf))
(define fixed-body
  (string-append "POST / HTTP/1.1" crlf "Content-Length: 256" crlf crlf (rep-str 256 "x")))
(define chunked-body
  (string-append "POST / HTTP/1.1" crlf "Transfer-Encoding: chunked" crlf crlf
                 (rep-str 8 (string-append "10" crlf (rep-str 16 "y") crlf)) "0" crlf crlf))
(define pipelined (rep-str 5 short-normal))
(define early-error "@")                                   ; invalid-method at byte 0
(define late-error (string-append "GET / HTTP/1.1" crlf "Host: a\x01;b" crlf)) ; invalid-header-value
(define dense-dispatch many-headers)                       ; many byte-dispatch decisions
(define sparse-dispatch fixed-body)                        ; a long counted run, few decisions
(define long-exact (rep-str 20 short-normal))              ; the "HTTP/1.1" exact-sequence, repeated

;; A workload is (name canonical-string feed-strategy). feed-strategy is `whole`
;; (one parser-feed! call) or `byte` (one byte per call — the fragmentation case).
(define workloads
  (list (list "short-normal-requests"        short-normal   'whole)
        (list "many-small-headers"           many-headers   'whole)
        (list "long-method-target-header-spans" long-spans  'whole)
        (list "byte-at-a-time-fragmentation" short-normal   'byte)
        (list "fixed-length-bodies"          fixed-body     'whole)
        (list "chunked-bodies"               chunked-body   'whole)
        (list "pipelined-requests"           pipelined      'whole)
        (list "early-error"                  early-error    'whole)
        (list "late-error"                   late-error     'whole)
        (list "dense-byte-dispatch"          dense-dispatch 'whole)
        (list "sparse-byte-dispatch"         sparse-dispatch 'whole)
        (list "long-exact-sequence-matching" long-exact     'whole)))

;; --- running one workload once ----------------------------------------------
(define (run-once cm bv strategy)
  (let ((p (make-parser cm '() #f)) (n (bytevector-length bv)))
    (if (eq? strategy 'byte)
        (do ((i 0 (+ i 1))) ((= i n)) (parser-feed! p bv i (+ i 1)))
        (parser-feed! p bv 0 n))
    (parser-finish! p)))

;; median and dispersion (min, max) over a list of round times (ms).
(define (median xs)
  (let* ((s (list-sort < xs)) (n (length s)))
    (if (odd? n) (list-ref s (div n 2))
        (/ (+ (list-ref s (- (div n 2) 1)) (list-ref s (div n 2))) 2))))

;; R rounds of `inner` iterations; return (median-ms min-ms max-ms alloc-bytes/msg).
(define (measure cm bv strategy)
  ;; warmup: one full round, discarded.
  (do ((i 0 (+ i 1))) ((= i inner)) (run-once cm bv strategy))
  (let loop ((r 0) (samples '()) (alloc0 #f))
    (if (= r rounds)
        (let ((a1 (sstats-bytes (statistics))))
          (list (median samples) (apply min samples) (apply max samples)
                (div (- a1 alloc0) (* rounds inner))))
        (let ((start-alloc (if alloc0 alloc0 (begin (collect) (sstats-bytes (statistics)))))
              (t0 (real-time)))
          (do ((i 0 (+ i 1))) ((= i inner)) (run-once cm bv strategy))
          (loop (+ r 1) (cons (- (real-time) t0) samples) start-alloc)))))

(define (per-executor cm bv strategy input-size)
  (let* ((m (measure cm bv strategy))
         (median-ms (car m)) (min-ms (cadr m)) (max-ms (caddr m)) (alloc (cadddr m))
         ;; median-ms covers `inner` iterations of `input-size` bytes.
         (secs (if (zero? median-ms) 1/1000 (/ median-ms 1000)))
         (reqs/sec (inexact (/ inner secs)))
         (bytes/sec (inexact (/ (* inner input-size) secs))))
    (list (list 'median-ms-per-round median-ms)
          (list 'dispersion-ms (list min-ms max-ms))
          (list 'requests-per-second (round reqs/sec))
          (list 'bytes-per-second (round bytes/sec))
          (list 'allocation-bytes-per-message alloc))))

;; --- the artefact -----------------------------------------------------------
;; AOT-compiled artifact size (§23.1): compile the emitted generated source to an
;; object and size it. compile-file's progress line is suppressed so it cannot
;; land in an artefact written to stdout.
(compile-file-message #f)
(define aot-object-size
  (guard (e (#t 'unavailable))
    (let ((obj (string-append tmpdir "/http-bench-gen.so")))
      (compile-file gen-file obj)
      (bytevector-length (adapter-file-bytes obj)))))

(define artefact
  (list
   (list 'schema "byte-machine v0.1 benchmark baseline")
   (list 'harness-version (harness-fingerprint->string
                           (harness-fingerprint-bytevector (string->utf8 "release-ledger v0.1"))))
   (list 'runtime (list (list 'name (adapter-runtime-name))
                        (list 'version (adapter-runtime-version))
                        (list 'machine-type (adapter-machine-type))
                        (list 'os (adapter-os))
                        (list 'architecture (adapter-architecture))))
   (list 'mode (adapter-execution-mode))
   (list 'compiler-options '())            ; none passed to compile-machine
   (list 'cpu-info 'unavailable)           ; not portably available from Chez
   (list 'warmup (string-append (number->string inner) " iterations, discarded"))
   (list 'rounds rounds)
   (list 'iterations-per-round inner)
   (list 'deterministic-seed 0)            ; workloads are fixed byte sequences; no PRNG
   (list 'exact-command
         "chez --script test/support/launchers/chez-source.ss --library-root test/support/harness --library-root src --object-guard build/dev/chez-object-guard --program bench/runner/benchmark.sps")
   (list 'one-time-metrics
         (list (list 'generated-source-size-bytes generated-source-size)
               (list 'aot-object-size-bytes aot-object-size)
               (list 'generation-time-ms emit-ms)))
   (list 'required-metrics
         '(bytes-per-second requests-per-second allocation-bytes-per-message
           generated-source-size-bytes aot-object-size-bytes generation-time-ms
           median-ms-per-round dispersion-ms))
   (list 'unavailable-metrics
         '((cpu-info "not portably available from Chez Scheme")
           (gc-activity "sstats-bytes gives total allocation; per-collection GC time is not recorded in v0.1")))
   (list 'workloads
         (map (lambda (w)
                (let* ((name (car w)) (bv (b (cadr w))) (strategy (caddr w))
                       (size (bytevector-length bv)))
                  (list (list 'name name)
                        (list 'input-size-bytes size)
                        (list 'feed-strategy strategy)
                        (list 'canonical-bytes (cadr w))
                        (list 'generated (per-executor generated bv strategy size))
                        (list 'interpreted (per-executor interpreted bv strategy size)))))
              workloads))))

(define out (env "BYTE_MACHINE_BENCH_OUT" ""))
(if (string=? out "")
    (begin (write artefact) (newline))
    (begin
      (when (file-exists? out) (delete-file out))
      (let ((p (open-output-file out)))
        (write artefact p) (newline p) (close-output-port p))))
(exit 0)
