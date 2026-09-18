;;; Milestone 9 Slice ③: the allocation audit (decision 0040, §26:1680, §30 q5).
;;; §26:1680 has a prohibition ("no deliberate list/vector/string/result
;;; construction in generated per-byte paths") and a measurement ("fixnum-sized
;;; allocation measurements recorded with callbacks disabled"). Measured as a
;;; SLOPE, not a budget: the same machine fed two messages differing only in the
;;; length of one header value; allocation differenced and divided by the byte
;;; difference. Three properties make it an assertion, not an observation:
;;;   1. a LIVE CONTROL in the same lane (a loop allocating a known amount per
;;;      byte), asserted nonzero — without it, a slope of zero cannot be told
;;;      from a measurement apparatus that cannot move;
;;;   2. BOTH executors measured, only the generated one gated (the interpreter's
;;;      per-byte allocation is recorded — §18 asks nothing of it);
;;;   3. CALLBACKS DISABLED ('() bindings), with the callback-bound figure
;;;      recorded beside it so the difference is visible.
;;; This slice RECORDS and does not act (§26:1679 "without speculative
;;; optimization"; §23.3's admission rule is not met for anything and is not
;;; pursued here). It answers §30 question 5 in a test; the documentation half is
;;; Slice ④. The interpreter allocates ~17 900 B/byte, so it is measured at a low
;;; repetition count to bound its allocation churn; the generated executor is
;;; allocation-free per byte, so equality holds at any count.
(import (rnrs) (rnrs eval)
        (only (chezscheme) load statistics sstats-bytes collect)
        (byte-machine test harness)
        (byte-machine test http-machine)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime)
        (byte-machine compile))

(harness-begin "unit.allocation-audit")

;; Record a measured figure to stdout (informational; not a check).
(define (say line) (display line) (newline))

(define tmpdir
  (let ((d (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")))
    (if (and d (not (string=? d ""))) d
        (assertion-violation 'allocation-audit "BYTE_MACHINE_TEST_TMPDIR is unset" d))))

;; The two executors: the reference interpreter (the oracle) and the generated
;; machine (loaded from emitted source, as determinism-http does).
(define ok (compile-machine (make-http-machine) '()))
(define gen-file (string-append tmpdir "/http-alloc-gen.sls"))
(call-with-port (open-file-output-port gen-file (file-options no-fail))
  (lambda (p) (emit-machine ok 'httpreq p)))
(load gen-file)
(define generated (eval 'httpreq (environment '(generated httpreq))))
(define interpreted (make-interpreted-machine (verify-machine (make-http-machine))))

;; Two valid no-body requests differing only in one header value's length. The
;; overhead ("GET / HTTP/1.1\r\nX-Pad: " + "\r\n\r\n") is 26 bytes; a value of 44
;; gives a 70-byte message, a value of 40044 gives a 40070-byte message — the two
;; sizes design §3.3 P2 measured, 40000 bytes apart.
(define (bytes s) (map char->integer (string->list s)))
(define (request value-len)
  (u8-list->bytevector
   (bytes (string-append "GET / HTTP/1.1\r\nX-Pad: "
                         (make-string value-len #\a) "\r\n\r\n"))))
(define short-req (request 44))
(define long-req  (request 40044))
(define value-byte-difference 40000)
(define gen-reps 40)     ; generated is allocation-free per byte; equality holds at any count
(define interp-reps 3)   ; the interpreter is ~17 900 B/byte — a low count bounds its churn

;; Feed one whole request through a fresh parser and finish it. `bindings` is the
;; callback binding list — '() disables callbacks (§26:1680's wording).
(define (feed-once! cm bindings req)
  (let ((p (make-parser cm bindings #f)))
    (parser-feed! p req 0 (bytevector-length req))
    (parser-finish! p)))

;; Bytes allocated by feeding `req` `reps` times. A GC first, so the delta is the
;; loop's own allocation and not a collection that happened to fall inside it.
(define (alloc-feeding cm bindings req reps)
  (collect)
  (let ((before (sstats-bytes (statistics))))
    (do ((i 0 (+ i 1))) ((= i reps))
      (feed-once! cm bindings req))
    (- (sstats-bytes (statistics)) before)))

;; per-input-byte slope = (alloc(long) - alloc(short)) / (reps * byte-difference)
(define (slope cm bindings reps)
  (/ (- (alloc-feeding cm bindings long-req reps)
        (alloc-feeding cm bindings short-req reps))
     (* reps value-byte-difference)))

;; The live control: a loop whose per-message work IS proportional to length (a
;; make-bytevector of the message's own size). Its slope MUST be positive, or the
;; apparatus cannot see per-byte allocation and a generated slope of zero proves
;; nothing.
(define (control-alloc len reps)
  (collect)
  (let ((before (sstats-bytes (statistics))))
    (do ((i 0 (+ i 1))) ((= i reps))
      (make-bytevector len 0))
    (- (sstats-bytes (statistics)) before)))

;; --- Milestone 14: the second slope, per HEADER ------------------------------
;;
;; The slope above varies one header VALUE's length, so it holds the header
;; count fixed and cannot see a cost paid once per header. There was one: the
;; callback seam returned a freshly consed outcome list on every crossing, and
;; an HTTP grammar crosses it about four times per header. It read as a
;; per-MESSAGE intercept -- decision 0040 item 1 reports that separately and
;; never divides it by anything -- so the audit was green while allocation grew
;; linearly in the one dimension real traffic actually varies.
;;
;; Two requests differing only in header COUNT. They differ in length too, of
;; course; what makes the difference attributable to headers is the slope above
;; being ZERO per byte, asserted in the same lane, with callbacks bound as well
;; as disabled. Without that this would be two confounded variables.
(define (headers-request n)
  (u8-list->bytevector
   (bytes (string-append "GET / HTTP/1.1\r\n"
                         (let loop ((i 0) (acc ""))
                           (if (= i n) acc (loop (+ i 1) (string-append acc "X-H: v\r\n"))))
                         "\r\n"))))
(define few-headers-req  (headers-request 1))
(define many-headers-req (headers-request 201))
(define header-difference 200)

;; per-header slope = (alloc(many) - alloc(few)) / (reps * header-difference)
(define (header-slope cm bindings reps)
  (/ (- (alloc-feeding cm bindings many-headers-req reps)
        (alloc-feeding cm bindings few-headers-req reps))
     (* reps header-difference)))

(harness-group "the generated per-byte path allocates nothing (§26:1680, callbacks disabled)"
  (lambda ()
    (harness-case "the generated executor's allocation does not grow with message length"
      (lambda ()
        ;; The strongest form of a zero slope: feeding 40000 more bytes per
        ;; message allocates the SAME total, to the byte.
        (let ((short (alloc-feeding generated '() short-req gen-reps))
              (long  (alloc-feeding generated '() long-req gen-reps)))
          (check-equal "generated: alloc(short) = alloc(long)" long short)
          (check "generated per-byte slope is zero" (zero? (- long short))))))))

(harness-group "the live control proves the apparatus can see per-byte allocation"
  (lambda ()
    (harness-case "a length-proportional loop allocates strictly more at the larger size"
      (lambda ()
        (let ((short (control-alloc 44 gen-reps)) (long (control-alloc 40044 gen-reps)))
          (check "control: alloc(long) > alloc(short)" (> long short))
          (check "control per-byte slope is nonzero" (positive? (- long short))))))))

(harness-group "both executors measured; only the generated one is gated (§18)"
  (lambda ()
    (harness-case "the interpreter's per-byte allocation is recorded, not asserted"
      (lambda ()
        ;; Recorded so the baseline and §30 q5 can cite it; the interpreter is the
        ;; oracle and §18 asks nothing of its allocation. The only assertion here
        ;; is that the measurement APPARATUS produced a positive number for it —
        ;; the interpreter DOES allocate per byte, unlike the generated executor.
        (let ((interp-slope (slope interpreted '() interp-reps)))
          (check "the interpreter slope is a measured number" (rational? interp-slope))
          (check "the interpreter allocates per byte (unlike generated)" (positive? interp-slope))
          (say
           (string-append "byte-machine-alloc: interpreter B/byte="
                          (adapter-value->string interp-slope))))))))

(harness-group "callbacks-disabled vs callbacks-bound, both recorded (§26:1680 wording)"
  (lambda ()
    (harness-case "the generated slope is zero with callbacks disabled AND with callbacks bound"
      (lambda ()
        ;; A binding list that fires on message-begin/complete but records nothing
        ;; structural. §26:1680 gates the callbacks-disabled figure; the bound
        ;; figure is recorded beside it so the difference is visible.
        (let* ((noop (lambda (ps ux) callback-continue))
               (bound (list (list 'message-begin noop) (list 'message-complete noop)))
               (disabled-short (alloc-feeding generated '() short-req gen-reps))
               (disabled-long  (alloc-feeding generated '() long-req gen-reps))
               (bound-short (alloc-feeding generated bound short-req gen-reps))
               (bound-long  (alloc-feeding generated bound long-req gen-reps)))
          (check-equal "disabled: slope zero" disabled-long disabled-short)
          (check-equal "bound: slope zero" bound-long bound-short)
          (say
           (string-append "byte-machine-alloc: generated per-message disabled="
                          (adapter-value->string (div disabled-short gen-reps))
                          "B bound=" (adapter-value->string (div bound-short gen-reps)) "B")))))))

(harness-group "the generated path allocates nothing per HEADER either"
  (lambda ()
    (harness-case "the live control proves the apparatus can see a per-header cost"
      (lambda ()
        ;; Decision 0040 item 2, applied to the second dimension: a slope of zero
        ;; is indistinguishable from a measurement that cannot move, so the
        ;; control moves first. It allocates in proportion to the header count.
        (let ((few  (control-alloc 1 gen-reps))
              (many (control-alloc 201 gen-reps)))
          (check "control: alloc(many headers) > alloc(few)" (> many few)))))
    (harness-case "the generated executor's allocation does not grow with header count"
      (lambda ()
        ;; Both wordings, as the per-byte group does: §26:1680 gates the
        ;; callbacks-disabled figure, and the bound figure is asserted here too
        ;; because an UNBOUND callback crossed the same seam and paid the same
        ;; cost -- the defect this leg was added for was visible in both.
        (let* ((noop (lambda (ps ux) callback-continue))
               (bound (list (list 'message-begin noop) (list 'message-complete noop)))
               (disabled (header-slope generated '() gen-reps))
               (with-callbacks (header-slope generated bound gen-reps)))
          (say (string-append "byte-machine-alloc: generated B/header disabled="
                              (adapter-value->string disabled)
                              " bound=" (adapter-value->string with-callbacks)))
          (check-equal "disabled: per-header slope zero" disabled 0)
          (check-equal "bound: per-header slope zero" with-callbacks 0))))
    (harness-case "the interpreter's per-header allocation is recorded, not asserted"
      (lambda ()
        ;; §18 asks nothing of the oracle's allocation here either.
        (let ((interp (header-slope interpreted '() interp-reps)))
          (check "the interpreter per-header slope is a measured number" (rational? interp))
          (say (string-append "byte-machine-alloc: interpreter B/header="
                              (adapter-value->string interp))))))))

(harness-finish)
