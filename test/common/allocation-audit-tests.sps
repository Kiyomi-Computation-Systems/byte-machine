;;; The allocation audit. It checks a prohibition ("no deliberate
;;; list/vector/string/result construction in generated per-byte paths") and
;;; records a measurement ("fixnum-sized allocation measurements recorded with
;;; callbacks disabled"). Measured as a
;;; SLOPE, not a budget: the same machine fed two messages differing only in the
;;; length of one header value; allocation differenced and divided by the byte
;;; difference. Three properties make it an assertion, not an observation:
;;;   1. a LIVE CONTROL in the same lane (a loop allocating a known amount per
;;;      byte), asserted nonzero — without it, a slope of zero cannot be told
;;;      from a measurement apparatus that cannot move;
;;;   2. BOTH executors measured, only the generated one gated (the interpreter's
;;;      per-byte allocation is recorded, not constrained);
;;;   3. CALLBACKS DISABLED ('() bindings), with the callback-bound figure
;;;      recorded beside it so the difference is visible.
;;; The audit RECORDS and does not optimize. The interpreter allocates
;;; ~17 900 B/byte, so it is measured at a low
;;; repetition count to bound its allocation churn; the generated executor is
;;; allocation-free per byte, so equality holds at any count.
(import (rnrs) (rnrs eval)
        (only (chezscheme) load statistics sstats-bytes collect environment-symbols)
        (byte-machine test harness)
        (byte-machine test http-machine)
        (byte-machine test keyword-header-machine)
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
;; gives a 70-byte message, a value of 40044 gives a 40070-byte message — two
;; sizes 40000 bytes apart.
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
;; callback binding list — '() disables callbacks.
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

;; --- the second slope, per HEADER --------------------------------------------
;;
;; The slope above varies one header VALUE's length, so it holds the header
;; count fixed and cannot see a cost paid once per header. An HTTP grammar
;; crosses the callback seam about four times per header, so a seam that
;; allocated on every crossing would read as a per-MESSAGE intercept -- which
;; the per-byte slope reports separately and never divides by anything -- while
;; allocation grew linearly in the one dimension real traffic actually varies.
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

(harness-group "the generated per-byte path allocates nothing (callbacks disabled)"
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

(harness-group "both executors measured; only the generated one is gated"
  (lambda ()
    (harness-case "the interpreter's per-byte allocation is recorded, not asserted"
      (lambda ()
        ;; Recorded so the baseline can cite it; the interpreter is the oracle
        ;; and nothing constrains its allocation. The only assertion here
        ;; is that the measurement APPARATUS produced a positive number for it —
        ;; the interpreter DOES allocate per byte, unlike the generated executor.
        (let ((interp-slope (slope interpreted '() interp-reps)))
          (check "the interpreter slope is a measured number" (rational? interp-slope))
          (check "the interpreter allocates per byte (unlike generated)" (positive? interp-slope))
          (say
           (string-append "byte-machine-alloc: interpreter B/byte="
                          (adapter-value->string interp-slope))))))))

(harness-group "callbacks-disabled vs callbacks-bound, both recorded"
  (lambda ()
    (harness-case "the generated slope is zero with callbacks disabled AND with callbacks bound"
      (lambda ()
        ;; A binding list that fires on message-begin/complete but records nothing
        ;; structural. The audit gates the callbacks-disabled figure; the bound
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
        ;; The live control, applied to the second dimension: a slope of zero
        ;; is indistinguishable from a measurement that cannot move, so the
        ;; control moves first. It allocates in proportion to the header count.
        (let ((few  (control-alloc 1 gen-reps))
              (many (control-alloc 201 gen-reps)))
          (check "control: alloc(many headers) > alloc(few)" (> many few)))))
    (harness-case "the generated executor's allocation does not grow with header count"
      (lambda ()
        ;; Both bindings, as the per-byte group does: the callbacks-disabled
        ;; figure is the gated one, and the bound figure is asserted here too
        ;; because an UNBOUND callback crosses the same seam and would pay the
        ;; same per-crossing cost.
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
        ;; Nothing constrains the oracle's allocation here either.
        (let ((interp (header-slope interpreted '() interp-reps)))
          (check "the interpreter per-header slope is a measured number" (rational? interp))
          (say (string-append "byte-machine-alloc: interpreter B/header="
                              (adapter-value->string interp))))))))

;; --- the third dimension, per MATCHED keyword byte ---------------------------
;;
;; Neither slope above can see a keyword table: the HTTP fixture machine has
;; none. A walk (`byte-machine-keyword-step/v1`) that copied the whole matched
;; prefix for every byte it consumed would allocate about k²/2 pairs for a
;; header name matching k bytes of a keyword. The claim here
;; is a SHAPE, not a number: what one walk allocates does not depend on how much
;; of a keyword it matched, on how long a prefix it resumed with, or on how long
;; a prefix it parks unchanged. The op is driven directly, as the generated arm
;; calls it, so the figure is the walk's own and no executor's.
;;
;; The table is the five header names chez-httparse's parser reads by name,
;; case-insensitive, with a reexecute no-match.
(define kw-entries
  (let loop ((ns '("connection" "content-length" "proxy-connection"
                   "transfer-encoding" "upgrade"))
             (id 0) (acc '()))
    (if (null? ns) (reverse acc)
        (loop (cdr ns) (+ id 1) (cons (cons (bytes (car ns)) id) acc)))))
(define kw-no-match '(99 . reexecute))
(define kw-reps 1000)

;; A 17-byte field name whose first k bytes are `Transfer-Encoding` and whose
;; rest is `x`, then the `:` that ends it.
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

;; The live control: a walk that copies its prefix on every consumed byte. Kept
;; here so the apparatus is shown able to see the defect it guards against.
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

(harness-group "the keyword walk allocates nothing per matched byte"
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

;; --- the runtime op census ---------------------------------------------------
;;
;; Every slope above is a claim about the code its fixture RUNS, and a runtime
;; op no fixture runs is outside all of them -- the keyword walk, for one, is
;; called from an arm the HTTP machine does not have. So the claim "generated per-byte paths allocate
;; nothing" is a census over the `(byte-machine runtime)` procedures emitted code
;; can call, and the lane must reach each one. Both halves are measured here,
;; neither declared:
;;
;;   DERIVED -- the runtime's live exports that occur as a token in some string
;;     literal of compile.sls. The emitter writes generated code ONLY as string
;;     literals (render-machine builds text), so a new op any lowering calls is
;;     in this set the moment its template is written, whether or not any
;;     fixture renders it. compile.sls is read as a datum from the tree that is
;;     running (BYTE_MACHINE_SOURCE_ROOT), so comments and the quoted
;;     reserved-member-2 list are not strings and do not count.
;;   REACHED -- the ops a COUNTING TWIN of each audited machine actually calls.
;;     The twin is the same rendered text with one import changed, to a library
;;     this lane writes that re-exports the runtime with a call counter in front
;;     of every procedure. Allocation is measured on the real machine, calls on
;;     the twin; the code paths are the same text.
;;
;; A witness registers what it reached only from inside the case that asserts
;; its allocation shape, so deleting a witness group deletes its reach too. The
;; totality row at the end then fails for a future node kind whose lowering
;; calls an op no witness runs, naming the op, until a witness is added.
;;
;; Scope, stated as measured: the census covers calls EMITTED code makes. The
;; runtime's own per-feed work (parser-feed!'s boundary flush, make-parser) is
;; not in it; the per-byte and per-header slopes above run those paths on every
;; feed.

(define source-root
  (let ((r (adapter-environment-variable "BYTE_MACHINE_SOURCE_ROOT")))
    (if (and r (not (string=? r ""))) r
        ;; Loud, not defaulted: under the mutation suite a census reading the
        ;; pristine tree would compare the running mutant against a file it is
        ;; not executing (diagnostic-census-tests.sps records the same trap).
        (assertion-violation 'allocation-audit "BYTE_MACHINE_SOURCE_ROOT is unset" r))))

;; A .sls file is exactly one datum; the second value guards against a walk
;; that silently stops at the first form.
(define compile-src
  (call-with-input-file (string-append source-root "/byte-machine/compile.sls")
    (lambda (p) (let* ((d (read p)) (clean (eof-object? (read p)))) (cons d clean)))))

(define (string-literals d acc)
  (cond ((string? d) (cons d acc))
        ((pair? d) (string-literals (cdr d) (string-literals (car d) acc)))
        ((vector? d) (fold-left (lambda (a x) (string-literals x a)) acc (vector->list d)))
        (else acc)))

;; Split on whitespace and parentheses: the delimiters of the emitted text.
(define (tokens s)
  (let loop ((cs (string->list s)) (cur '()) (acc '()))
    (define (flush) (if (null? cur) acc (cons (list->string (reverse cur)) acc)))
    (cond ((null? cs) (reverse (flush)))
          ((memv (car cs) '(#\space #\newline #\tab #\( #\)))
           (loop (cdr cs) '() (flush)))
          (else (loop (cdr cs) (cons (car cs) cur) acc)))))

(define runtime-env (environment '(byte-machine runtime)))
(define runtime-exports
  (list-sort (lambda (a b) (string<? (symbol->string a) (symbol->string b)))
             (environment-symbols runtime-env)))

(define literal-tokens
  (let ((h (make-hashtable string-hash string=?)))
    (for-each (lambda (s) (for-each (lambda (t) (hashtable-set! h t #t)) (tokens s)))
              (string-literals (car compile-src) '()))
    h))

;; The derived census, split by what the export IS: a procedure is an op emitted
;; code calls; anything else (`callback-pause`, compared by `eq?`) is a
;; constant it reads and cannot allocate.
(define derived
  (filter (lambda (x) (hashtable-contains? literal-tokens (symbol->string x)))
          runtime-exports))
(define derived-ops (filter (lambda (x) (procedure? (eval x runtime-env))) derived))
(define derived-constants (remp (lambda (x) (procedure? (eval x runtime-env))) derived))

;; The counting runtime, written as a datum from the LIVE export list, so it
;; cannot drift from the runtime it stands in for.
(define (with-text-file path proc)
  (let ((p (open-file-output-port path (file-options no-fail) (buffer-mode block)
                                   (native-transcoder))))
    (proc p)
    (close-port p)))
(define counting-library-file (string-append tmpdir "/counting-runtime.sls"))
(with-text-file counting-library-file
  (lambda (p)
    (write
     `(library (byte-machine-census counting-runtime)
        (export census-counts census-reset! ,@runtime-exports)
        (import (rnrs) (prefix (byte-machine runtime) rt:))
        (define counts (make-eq-hashtable))
        (define (census-reset!) (hashtable-clear! counts))
        (define (census-counts)
          (let-values (((ks vs) (hashtable-entries counts)))
            (map cons (vector->list ks) (vector->list vs))))
        ,@(map (lambda (x)
                 (let ((rt (string->symbol (string-append "rt:" (symbol->string x)))))
                   (if (procedure? (eval x runtime-env))
                       `(define (,x . args)
                          (hashtable-update! counts ',x (lambda (n) (+ n 1)) 0)
                          (apply ,rt args))
                       `(define ,x ,rt))))
               runtime-exports))
     p)))
(load counting-library-file)
(define counting-env (environment '(byte-machine-census counting-runtime)))
(define census-counts (eval 'census-counts counting-env))
(define census-reset! (eval 'census-reset! counting-env))

;; Replace the one occurrence of `old` in `s`; raise unless there is exactly one,
;; because a twin still importing the real runtime anywhere would undercount.
(define (replace-once s old new)
  (let ((n (string-length s)) (m (string-length old)))
    (let loop ((i 0) (hits '()))
      (cond ((> (+ i m) n)
             (unless (= (length hits) 1)
               (assertion-violation 'replace-once "expected exactly one occurrence" old hits))
             (let ((at (car hits)))
               (string-append (substring s 0 at) new (substring s (+ at m) n))))
            ((string=? (substring s i (+ i m)) old) (loop (+ i 1) (cons i hits)))
            (else (loop (+ i 1) hits))))))

;; Emit `machine` twice: the real library, loaded for allocation, and its
;; counting twin, identical but for its name and the runtime it imports. (The
;; HTTP witnesses measure `generated`, loaded above from the same machine and
;; emitter; its text differs from this pair's only in the output binding.)
;; Returns (real twin load-calls rendered-datum).
(define (load-pair machine name)
  (let* ((ok (compile-machine machine '()))
         (text (utf8->string (render-machine ok name)))
         (real-file (string-append tmpdir "/" (symbol->string name) "-real.sls"))
         (twin-file (string-append tmpdir "/" (symbol->string name) "-twin.sls"))
         (lib (cadr (read (open-string-input-port text)))))
    (with-text-file real-file (lambda (p) (put-string p text)))
    (with-text-file twin-file
      (lambda (p)
        (put-string p (replace-once
                       (replace-once text "(library (generated " "(library (generated-census ")
                       "(byte-machine runtime)" "(byte-machine-census counting-runtime)"))))
    (load real-file)
    (load twin-file)
    (census-reset!)
    (let* ((twin (eval name (environment (cons 'generated-census (cdr lib)))))
           (load-calls (census-counts)))
      (list (eval name (environment lib)) twin load-calls
            (read (open-string-input-port text))))))

(define http-pair (load-pair (make-http-machine) 'httpcensus))
(define kw-pair (load-pair (make-keyword-header-ci-machine) 'kwcensus))

;; What the audited inputs reached, and the load-time calls, both observed.
(define witnessed '())
(define (note-reached! calls)
  (for-each (lambda (c)
              (when (and (> (cdr c) 0) (not (memq (car c) witnessed)))
                (set! witnessed (cons (car c) witnessed))))
            calls))
(note-reached! (caddr http-pair))
(note-reached! (caddr kw-pair))
;; Every call the twin saw, across every feed, for the derivation's control.
(define ever-called '())
(define (calls-feeding twin bindings req)
  (census-reset!)
  (feed-once! twin bindings req)
  (let ((calls (census-counts)))
    (for-each (lambda (c) (unless (memq (car c) ever-called)
                            (set! ever-called (cons (car c) ever-called))))
              calls)
    calls))
;; Called from inside a witness case: feed the twin what the case measured.
(define (witness! twin bindings req) (note-reached! (calls-feeding twin bindings req)))
;; The same for a witness that feeds without finishing: an input the machine
;; refuses leaves the parser in `error`, and only the feed's result is asserted.
(define (witness-feed! twin bindings req)
  (census-reset!)
  (feed-only twin bindings req)
  (let ((calls (census-counts)))
    (for-each (lambda (c) (unless (memq (car c) ever-called)
                            (set! ever-called (cons (car c) ever-called))))
              calls)
    (note-reached! calls)))

;; One feed and nothing after it; the result is what an error witness reads.
(define (feed-only cm bindings req)
  (parser-feed! (make-parser cm bindings #f) req 0 (bytevector-length req)))
(define (alloc-feeding-only cm bindings req reps)
  (collect)
  (let ((before (sstats-bytes (statistics))))
    (do ((i 0 (+ i 1))) ((= i reps))
      (feed-only cm bindings req))
    (- (sstats-bytes (statistics)) before)))

;; --- the error, callback-failure and emitted-keyword witnesses ---------------
;;
;; The HTTP slopes feed only valid messages, and the keyword group drives its op
;; directly, so without these three witnesses six ops would never run under this
;; lane -- `byte-machine-make-parser-error/v1`, `byte-machine-make-callback-error/v1`,
;; the three `callback-failure` readers, and the keyword walk as EMITTED code
;; calls it. Each is an event, not a per-byte step: an error or a callback
;; failure ends the feed, and the walk is entered once per table. So the shape
;; each asserts is the per-byte one -- what the event costs does not depend on
;; how many bytes came before it -- which is exactly what a copy of the input,
;; or of a prefix, into the record would break.

;; A request refused inside a header value (NUL is not a field-value byte), after
;; `value-len` good value bytes: the same 40000-byte difference the first slope
;; takes, ending at an error arm instead of the message's end.
(define (bad-value-request value-len)
  (u8-list->bytevector
   (append (bytes (string-append "GET / HTTP/1.1\r\nX-Pad: " (make-string value-len #\a)))
           (list 0))))
(define short-bad-req (bad-value-request 44))
(define long-bad-req (bad-value-request 40044))

;; The application's failure, built ONCE: what the callback allocates is the
;; application's, and the claim is about what the seam does with it.
(define audit-failure (make-callback-failure 'audit-refused 'audit-detail))
(define failing-bindings
  (list (list 'message-complete (lambda (ps ux) audit-failure))))

(harness-group "an error arm allocates the same however many bytes precede it"
  (lambda ()
    (harness-case "a machine error's record does not grow with the offset it reports"
      (lambda ()
        (let* ((r-short (feed-only generated '() short-bad-req))
               (r-long (feed-only generated '() long-bad-req))
               (e (parser-result-error r-long)))
          ;; The answer first, so an arm that stopped erroring could not pass by
          ;; allocating nothing.
          (check-equal "machine error: status" (parser-result-status r-long) 'error)
          (check-equal "machine error: domain and code"
                       (list (parser-error-domain e) (parser-error-code e))
                       '(machine invalid-header-value))
          (check-equal "machine error: the offsets differ by the value bytes"
                       (- (parser-error-offset e)
                          (parser-error-offset (parser-result-error r-short)))
                       value-byte-difference)
          (check "control: alloc(40044) > alloc(44)"
                 (> (control-alloc 40044 gen-reps) (control-alloc 44 gen-reps)))
          (check-equal "machine error: alloc(short prefix) = alloc(long prefix)"
                       (alloc-feeding-only generated '() long-bad-req gen-reps)
                       (alloc-feeding-only generated '() short-bad-req gen-reps))
          (witness-feed! (cadr http-pair) '() short-bad-req)
          (witness-feed! (cadr http-pair) '() long-bad-req))))
    (harness-case "a callback failure's record does not grow with the offset it reports"
      (lambda ()
        ;; message-complete answers the prebuilt failure, so the seam reads its
        ;; code and detail and builds the callback-domain error at the message's
        ;; end, 40000 bytes later in the long request.
        (let* ((r (feed-only generated failing-bindings long-req))
               (e (parser-result-error r)))
          (check-equal "callback failure: status" (parser-result-status r) 'error)
          (check-equal "callback failure: domain and code"
                       (list (parser-error-domain e) (parser-error-code e))
                       '(callback audit-refused))
          (check "callback failure: the application's detail passes through"
                 (eq? (parser-error-detail e) 'audit-detail))
          (check "control: alloc(40044) > alloc(44)"
                 (> (control-alloc 40044 gen-reps) (control-alloc 44 gen-reps)))
          (check-equal "callback failure: alloc(short) = alloc(long)"
                       (alloc-feeding-only generated failing-bindings long-req gen-reps)
                       (alloc-feeding-only generated failing-bindings short-req gen-reps))
          (witness-feed! (cadr http-pair) failing-bindings short-req)
          (witness-feed! (cadr http-pair) failing-bindings long-req))))))

(harness-group "an emitted keyword arm allocates the same however much it matched"
  (lambda ()
    (harness-case "the arm around the walk adds nothing per matched byte"
      (lambda ()
        ;; The keyword group above drives the op directly; this drives the
        ;; EMITTED arm that calls it, in the four-header case-insensitive
        ;; machine. Every k below 17 is refused at byte k by the no-match route
        ;; (reexecute), so every one ends at the same error arm, and its record
        ;; reports offset k. k = 17 takes the keyword.
        (let* ((kw-real (car kw-pair)) (kw-twin (cadr kw-pair))
               (base (alloc-feeding-only kw-real '() (kw-field 0) kw-reps))
               (hit-parser (make-parser kw-real '() #f))
               (hit (parser-feed! hit-parser (kw-field 17) 0 18)))
          (check "control: a copying walk allocates more at k=16 than at k=1"
                 (> (alloc-walking copying-keyword-step '() (kw-field 16) kw-reps)
                    (alloc-walking copying-keyword-step '() (kw-field 1) kw-reps)))
          (check-equal "k=17 takes transfer-encoding"
                       (list (parser-result-status hit) (parser-state-name hit-parser))
                       '(stopped got-transfer-encoding))
          (let loop ((k 0) (measured 0) (grew '()) (wrong '()))
            (if (<= k 16)
                (let* ((r (feed-only kw-real '() (kw-field k)))
                       (e (parser-result-error r))
                       (got (list (parser-result-status r) (and e (parser-error-offset e))))
                       (a (alloc-feeding-only kw-real '() (kw-field k) kw-reps)))
                  (loop (+ k 1) (+ measured 1)
                        (if (= a base) grew (cons (cons k (- a base)) grew))
                        (if (equal? got (list 'error k)) wrong (cons (cons k got) wrong))))
                (begin
                  (check-equal "every k from 0 to 16 was fed through the arm" measured 17)
                  (check-equal "every k was refused at byte k" (reverse wrong) '())
                  (check-equal "no emitted k allocated more than k=0 (k . extra bytes)"
                               (reverse grew) '()))))
          (witness-feed! kw-twin '() (kw-field 0))
          (witness-feed! kw-twin '() (kw-field 16))
          (witness-feed! kw-twin '() (kw-field 17)))))))

(define (sorted xs)
  (list-sort (lambda (a b) (string<? (symbol->string a) (symbol->string b))) xs))

(harness-group "the per-byte and per-header slopes reach the ops they claim"
  (lambda ()
    (harness-case "the HTTP slopes' messages drive the counting twin"
      (lambda ()
        (let ((twin (cadr http-pair))
              (noop (lambda (ps ux) callback-continue)))
          (for-each (lambda (req) (witness! twin '() req))
                    (list short-req long-req few-headers-req many-headers-req))
          (witness! twin (list (list 'message-begin noop) (list 'message-complete noop))
                    short-req))))))

(harness-group "the runtime op census: every op emitted code can call has a witness"
  (lambda ()
    (harness-case "the census is derived from compile.sls's emitted text"
      (lambda ()
        (check "compile.sls is exactly one datum" (cdr compile-src))
        ;; No floor on the census's size: a derivation that read nothing leaves
        ;; every op the twins call outside it, and the called-ops case below
        ;; names them.
        (say (string-append "byte-machine-alloc: census ops="
                            (adapter-value->string (sorted derived-ops))
                            " constants=" (adapter-value->string (sorted derived-constants))))))
    (harness-case "every runtime export a rendered machine names is in the derived census"
      (lambda ()
        ;; The second method: the symbols actually present in the two rendered
        ;; libraries, read as data. A name the emitter assembles from two
        ;; literals would be missing from the derivation and present here.
        (let walk ((ds (list (cadddr http-pair) (cadddr kw-pair))) (missing '()))
          (define (syms d acc)
            (cond ((symbol? d) (if (and (memq d runtime-exports) (not (memq d derived))
                                        (not (memq d acc)))
                                   (cons d acc) acc))
                  ((pair? d) (syms (cdr d) (syms (car d) acc)))
                  ((vector? d) (fold-left (lambda (a x) (syms x a)) acc (vector->list d)))
                  (else acc)))
          (if (null? ds)
              (check-equal "rendered runtime names absent from the census" (sorted missing) '())
              (walk (cdr ds) (syms (car ds) missing))))))
    (harness-case "every op the twins were seen calling is in the derived census"
      (lambda ()
        ;; The third method, over what ran: a call the derivation cannot see.
        (check-equal "called ops absent from the census"
                     (sorted (filter (lambda (x) (not (memq x derived-ops)))
                                     (append ever-called
                                             (map car (caddr http-pair))
                                             (map car (caddr kw-pair)))))
                     '())))
    (harness-case "each op is entered per event, never per byte of a header value"
      (lambda ()
        ;; The "per byte or per event" question, answered by call counts on the
        ;; twin rather than by reading the arms: 40000 more value bytes, 200
        ;; more headers, and 16 more matched keyword bytes. An op whose count
        ;; moved with the value bytes would be on the per-byte path itself; the
        ;; slopes above gate what it ALLOCATES, this records where it SITS.
        (let* ((twin (cadr http-pair)) (kw-twin (cadr kw-pair))
               (count-of (lambda (calls op) (cond ((assq op calls) => cdr) (else 0))))
               (short (calls-feeding twin '() short-req))
               (long (calls-feeding twin '() long-req))
               (few (calls-feeding twin '() few-headers-req))
               (many (calls-feeding twin '() many-headers-req))
               (k0 (begin (census-reset!) (feed-only kw-twin '() (kw-field 0)) (census-counts)))
               (k16 (begin (census-reset!) (feed-only kw-twin '() (kw-field 16)) (census-counts)))
               (per-byte (filter (lambda (op) (not (= (count-of short op) (count-of long op))))
                                 derived-ops))
               (per-matched (filter (lambda (op) (not (= (count-of k0 op) (count-of k16 op))))
                                    derived-ops)))
          (check-equal "ops whose calls grow with a header value's length" per-byte '())
          (check-equal "ops whose calls grow with bytes matched in a keyword" per-matched '())
          ;; Recorded, not asserted: which ops the per-header slope enters, and
          ;; how often. Its zero is a claim about these ops only because they
          ;; appear here with a nonzero rate.
          (for-each
           (lambda (op)
             (say (string-append
                   "byte-machine-alloc: op " (symbol->string op)
                   " calls/short-message=" (adapter-value->string (count-of short op))
                   " calls/header=" (adapter-value->string
                                     (/ (- (count-of many op) (count-of few op)) header-difference))
                   " calls/load=" (adapter-value->string
                                   (+ (count-of (caddr http-pair) op)
                                      (count-of (caddr kw-pair) op))))))
           (sorted derived-ops)))))
    (harness-case "every derived op is reached by an audited input"
      (lambda ()
        ;; The totality row. An op here and not witnessed is code the allocation
        ;; audit has never run.
        ;; One direction only: a witnessed op outside the census is a called op
        ;; outside it, which the called-ops case reports by name.
        (check-equal "census ops no witness reached"
                     (sorted (filter (lambda (x) (not (memq x witnessed))) derived-ops))
                     '())))))

(harness-finish)
