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

;; --- Issue #139: the third dimension, per MATCHED keyword byte ---------------
;;
;; Neither slope above can see a keyword table: the HTTP fixture machine has
;; none. The walk (`byte-machine-keyword-step/v1`, decision 0044) once copied the
;; whole matched prefix for every byte it consumed, so a header name matching k
;; bytes of a keyword allocated about k²/2 pairs -- measured downstream at 138
;; times a request's own size for 97 `Transfer-Encodinx` fields. The claim here
;; is a SHAPE, not a number: what one walk allocates does not depend on how much
;; of a keyword it matched, on how long a prefix it resumed with, or on how long
;; a prefix it parks unchanged. The op is driven directly, as the generated arm
;; calls it, so the figure is the walk's own and no executor's.
;;
;; The table is the five header names chez-httparse's parser reads by name,
;; case-insensitive (decision 0045), with a reexecute no-match.
(define kw-entries
  (let loop ((ns '("connection" "content-length" "proxy-connection"
                   "transfer-encoding" "upgrade"))
             (id 0) (acc '()))
    (if (null? ns) (reverse acc)
        (loop (cdr ns) (+ id 1) (cons (cons (bytes (car ns)) id) acc)))))
(define kw-no-match '(99 . reexecute))
(define kw-reps 1000)

;; A 17-byte field name whose first k bytes are `Transfer-Encoding` and whose
;; rest is `x`, then the `:` that ends it -- the downstream brief's k table.
(define (kw-field k)
  (u8-list->bytevector
   (bytes (string-append (substring "Transfer-Encoding" 0 k)
                         (make-string (- 17 k) #\x) ":"))))

;; Bytes allocated by `reps` walks of `step` over all of `bv` from `path`.
(define (alloc-walking step path bv reps)
  (collect)
  (let ((before (sstats-bytes (statistics))))
    (do ((i 0 (+ i 1))) ((= i reps))
      (step kw-entries kw-no-match #t path bv 0 (bytevector-length bv)))
    (- (sstats-bytes (statistics)) before)))

;; The live control: the walk as it stood before issue #139, copying its prefix
;; on every consumed byte. Kept here verbatim so the apparatus is shown able to
;; see the defect it guards against -- decision 0040 item 2, a third time.
(define (copying-keyword-step entries no-match ci? path bv pos end)
  (define (fold b) (if (and ci? (>= b 65) (<= b 90)) (+ b 32) b))
  (define (prefix? p bs)
    (cond ((null? p) #t)
          ((null? bs) #f)
          ((= (fold (car p)) (fold (car bs))) (prefix? (cdr p) (cdr bs)))
          (else #f)))
  (let walk ((p path) (i pos))
    (if (>= i end)
        (list 'need p i)
        (let ((np (append p (list (bytevector-u8-ref bv i)))))
          (if (exists (lambda (e) (prefix? np (car e))) entries)
              (walk np (+ i 1))
              (let ((term (find (lambda (e) (and (= (length (car e)) (length p))
                                                 (prefix? p (car e))))
                                entries)))
                (cond (term (list 'jump (cdr term) i 'byte))
                      ((eq? (cdr no-match) 'advance)
                       (list 'jump (car no-match) (+ i 1) 'boundary))
                      (else (list 'jump (car no-match) i 'byte)))))))))

(harness-group "the keyword walk allocates nothing per matched byte (issue #139)"
  (lambda ()
    (harness-case "the live control proves the apparatus can see a prefix copy"
      (lambda ()
        (let ((k1  (alloc-walking copying-keyword-step '() (kw-field 1) kw-reps))
              (k16 (alloc-walking copying-keyword-step '() (kw-field 16) kw-reps)))
          (check "control: a copying walk allocates more at k=16 than at k=1" (> k16 k1)))))
    (harness-case "a walk's allocation does not grow with how much of a keyword it matched"
      (lambda ()
        ;; Every k from 0 to 17, each walk's answer read back, so a table that
        ;; stopped matching could not pass by allocating nothing.
        (let ((base (alloc-walking byte-machine-keyword-step/v1 '() (kw-field 0) kw-reps)))
          (let loop ((k 0) (measured 0) (grew '()) (wrong '()))
            (if (<= k 17)
                (let* ((bv (kw-field k))
                       (r (byte-machine-keyword-step/v1 kw-entries kw-no-match #t '()
                                                        bv 0 (bytevector-length bv)))
                       (want (if (= k 17) '(jump 3 17 byte) (list 'jump 99 k 'byte)))
                       (a (alloc-walking byte-machine-keyword-step/v1 '() bv kw-reps)))
                  (loop (+ k 1) (+ measured 1)
                        (if (= a base) grew (cons (cons k (- a base)) grew))
                        (if (equal? r want) wrong (cons (cons k r) wrong))))
                (begin
                  (check-equal "every k from 0 to 17 was walked" measured 18)
                  (check-equal "every walk answered its expected jump" (reverse wrong) '())
                  (check-equal "no k allocated more than k=0 (k . extra bytes)"
                               (reverse grew) '())
                  (say (string-append "byte-machine-alloc: keyword walk B/call="
                                      (adapter-value->string (div base kw-reps))))))))))
    (harness-case "a resumed walk allocates what a fresh one does, however long its prefix"
      (lambda ()
        ;; `transfer-encod` parked, `ing:` fed: the same answer as a fresh walk
        ;; over the whole name, and the same allocation as a fresh one-byte miss.
        (let* ((parked (bytes "transfer-encod"))
               (rest (u8-list->bytevector (bytes "ing:")))
               (r (byte-machine-keyword-step/v1 kw-entries kw-no-match #t parked
                                                rest 0 (bytevector-length rest))))
          (check-equal "the resumed walk takes transfer-encoding" r '(jump 3 3 byte))
          (check-equal "resumed alloc = fresh alloc"
                       (alloc-walking byte-machine-keyword-step/v1 parked rest kw-reps)
                       (alloc-walking byte-machine-keyword-step/v1 '() (kw-field 0) kw-reps)))))
    (harness-case "a walk that consumes nothing parks its prefix without copying it"
      (lambda ()
        ;; The finish path enters the arm at pos = end; so does a feed that ends
        ;; exactly at the table. The parked prefix is handed back as it came, so
        ;; the call costs its answer and nothing in proportion to the prefix.
        (let* ((parked (bytes "transfer-encod"))
               (none (make-bytevector 0))
               (r (byte-machine-keyword-step/v1 kw-entries kw-no-match #t parked none 0 0)))
          (check "the prefix comes back as the same object" (eq? (cadr r) parked))
          (check-equal "alloc with a 14-byte prefix = alloc with none"
                       (alloc-walking byte-machine-keyword-step/v1 parked none kw-reps)
                       (alloc-walking byte-machine-keyword-step/v1 '() none kw-reps)))))
    (harness-case "a walk the feed interrupts parks exactly the bytes it consumed"
      (lambda ()
        ;; The one answer that must build a list: the prefix plus this feed's
        ;; bytes, in order, and a position at the end of the feed.
        (let* ((bv (u8-list->bytevector (bytes "ing")))
               (r (byte-machine-keyword-step/v1 kw-entries kw-no-match #t
                                                (bytes "transfer-encod") bv 0 3)))
          (check-equal "need with the grown prefix at the feed's end"
                       r (list 'need (bytes "transfer-encoding") 3)))))))

(harness-finish)
