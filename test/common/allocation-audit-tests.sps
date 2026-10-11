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
        (byte-machine compile)
        (only (byte-machine graph)
              make-machine make-uint-field make-error-declaration make-edge
              make-integer-accumulate-node make-field-action-node make-error-node
              make-byte-dispatch-node make-byte-case make-exact-byte-matcher
              make-field-branch-node make-pause-node)
        ;; The arm-kind census reads each audited machine's normalized states,
        ;; which no public library exports: a rendered library names its states
        ;; but not their kinds.
        (only (byte-machine private normal-ir)
              normalize-machine normal-machine-states normal-machine-fingerprint
              normal-state-kind normal-state-id normal-field-selector))

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
;;     The twin is the same rendered library with one import changed, to a
;;     library this lane writes that re-exports the runtime with a call counter
;;     in front of every procedure (and, for the arm-kind census, a counter at
;;     the head of each state procedure). Allocation is measured on the real
;;     machine, calls on the twin; the code paths are the same.
;;
;; A witness registers what it reached only from inside a case that asserts
;; its allocation shape -- or, for the HTTP slopes, from a group that feeds the
;; twin exactly the messages those slopes measured -- so deleting a witness
;; group deletes its reach too. The
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
        (export census-counts census-reset! census-enter! census-entered
                ,@runtime-exports)
        (import (rnrs) (prefix (byte-machine runtime) rt:))
        (define counts (make-eq-hashtable))
        ;; The states a twin entered, as (machine . state-id) keys.
        (define entries (make-hashtable equal-hash equal?))
        (define (census-reset!) (hashtable-clear! counts) (hashtable-clear! entries))
        (define (census-counts)
          (let-values (((ks vs) (hashtable-entries counts)))
            (map cons (vector->list ks) (vector->list vs))))
        (define (census-enter! machine id) (hashtable-set! entries (cons machine id) #t))
        (define (census-entered) (vector->list (hashtable-keys entries)))
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
(define census-entered (eval 'census-entered counting-env))

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

;; --- the arm-kind half of the census ------------------------------------------
;;
;; An arm whose cost is all inline code calls no runtime op, so the op census
;; cannot tell whether any audited input runs it: the HTTP fixture's two u64
;; accumulate arms allocated on every digit while it was green, because no
;; audited message had a body. So the twin also counts STATES. Each state of a
;; rendered machine is one procedure `%s<id>` inside `exec`, and the twin gets
;; a call at the head of each one, so an input's reach is read off as the set
;; of states it entered and, through the normalized IR the library was rendered
;; from, as their arm kinds.

;; Per load-pair: (name . shapes), shapes a vector by state id of
;; (kind . selector), the selector being a field arm's operation or predicate
;; or an accumulate arm's base -- each renders different inline code -- and #f
;; for every other kind.
(define audited '())
;; Per load-pair: (name instrumented-ids state-count), for the check that every
;; state procedure carries its counter.
(define instrumented '())

;; The id a state procedure's name carries, or #f for any other form.
(define (state-procedure-id form)
  (and (pair? form) (eq? (car form) 'define) (pair? (cdr form)) (pair? (cadr form))
       (symbol? (car (cadr form)))
       (let ((s (symbol->string (car (cadr form)))))
         (and (> (string-length s) 2) (string=? (substring s 0 2) "%s")
              (string->number (substring s 2 (string-length s)))))))

;; The library datum with `(census-enter! 'name id)` at the head of every state
;; procedure in `exec`, and the ids that received one.
(define (instrument-states lib name)
  (let ((ids '()))
    (define (in-exec form)
      (if (and (pair? form) (eq? (car form) 'define) (pair? (cdr form)) (pair? (cadr form))
               (eq? (car (cadr form)) 'exec))
          (cons* 'define (cadr form)
                 (map (lambda (f)
                        (let ((i (state-procedure-id f)))
                          (if i
                              (begin (set! ids (cons i ids))
                                     (cons* 'define (cadr f)
                                            (list 'census-enter! (list 'quote name) i)
                                            (cddr f)))
                              f)))
                      (cddr form)))
          form))
    (let ((out (map in-exec lib)))
      (values out ids))))

;; The fingerprint a rendered library passes its compiled-machine constructor.
(define (rendered-fingerprint d)
  (cond ((and (pair? d) (eq? (car d) 'byte-machine-make-compiled-machine)) (caddr d))
        ((pair? d) (or (rendered-fingerprint (car d)) (rendered-fingerprint (cdr d))))
        (else #f)))

;; The machine's normalized states as (kind . selector) by id, and the IR's
;; fingerprint, so the caller can check it is the IR the library came from.
(define (state-shapes machine)
  (let* ((n (normalize-machine (verification-machine (verify-machine machine))))
         (states (normal-machine-states n))
         (shapes (make-vector (vector-length states) #f)))
    (vector-for-each
     (lambda (s)
       (vector-set! shapes (normal-state-id s)
                    (cons (normal-state-kind s)
                          (and (memq (normal-state-kind s)
                                     '(field-action field-branch accumulate))
                               (normal-field-selector s)))))
     states)
    (values (normal-machine-fingerprint n) shapes)))

;; Emit `machine` twice: the real library, loaded for allocation, and its
;; counting twin, identical but for its name, the runtime it imports, and the
;; entry counter at the head of each state procedure. (The HTTP witnesses
;; measure `generated`, loaded above from the same machine and emitter; its
;; text differs from this pair's only in the output binding.)
;; Returns (real twin load-calls rendered-datum).
(define (load-pair machine name)
  (let* ((ok (compile-machine machine '()))
         (text (utf8->string (render-machine ok name)))
         (real-file (string-append tmpdir "/" (symbol->string name) "-real.sls"))
         (twin-file (string-append tmpdir "/" (symbol->string name) "-twin.sls"))
         (rendered (read (open-string-input-port text)))
         (lib (cadr rendered)))
    (with-text-file real-file (lambda (p) (put-string p text)))
    (let-values (((twin-lib ids)
                  (instrument-states
                   (read (open-string-input-port
                          (replace-once
                           (replace-once text "(library (generated " "(library (generated-census ")
                           "(byte-machine runtime)" "(byte-machine-census counting-runtime)")))
                   name))
                 ((fp shapes) (state-shapes machine)))
      ;; Loud: kinds read from any other IR would describe a different library.
      (unless (eqv? fp (rendered-fingerprint rendered))
        (assertion-violation 'load-pair "the IR read for arm kinds is not the one rendered"
                             name fp))
      (set! audited (cons (cons name shapes) audited))
      (set! instrumented (cons (list name (list-sort < ids) (vector-length shapes))
                               instrumented))
      (with-text-file twin-file (lambda (p) (write twin-lib p))))
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
;; The states every witness's twin entered, as (machine . state-id) keys.
;; Written only by the witness procedures below, like `witnessed`.
(define entered (make-hashtable equal-hash equal?))
(define (note-entered!)
  (for-each (lambda (k) (hashtable-set! entered k #t)) (census-entered)))
;; Called from inside a witness case: feed the twin what the case measured.
(define (witness! twin bindings req)
  (note-reached! (calls-feeding twin bindings req))
  (note-entered!))
;; The same for a witness that feeds without finishing: an input the machine
;; refuses leaves the parser in `error`, and only the feed's result is asserted.
(define (witness-feed! twin bindings req)
  (witness-run! (lambda () (feed-only twin bindings req))))
;; What one run of `thunk` against a twin reached and entered.
(define (witness-run! thunk)
  (census-reset!)
  (thunk)
  (let ((calls (census-counts)))
    (for-each (lambda (c) (unless (memq (car c) ever-called)
                            (set! ever-called (cons (car c) ever-called))))
              calls)
    (note-reached! calls)
    (note-entered!)))

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

;; --- the fourth dimension, per DIGIT read into a u64 field -------------------
;;
;; The slopes above feed the HTTP machine messages with no body, so none of
;; them runs an integer-accumulate arm; that arm calls no runtime op, so the op
;; census below could not notice, and the arm-kind census below is what asks a
;; witness to enter it. This group is the digits' own dimension. A 64-bit
;; field's maximum, 2^64 - 1,
;; is above the fixnum range on a 64-bit host: an overflow check written as
;; arithmetic on that maximum allocates on every digit, however small the value
;; being read.
;;
;; What "allocates nothing" can mean here is bounded by the value itself. A
;; field value above (greatest-fixnum) IS a heap object, so a digit that stores
;; one allocates it, and no overflow check can avoid that. The gated claim is
;; that a digit allocates nothing while the value it stores is a fixnum,
;; whatever the field's width. The cost of a digit above that range is recorded
;; beside it, and is this group's live control: the same apparatus, the same
;; arm, a positive figure. The boundary is read from the host rather than
;; written down. Every prefix of (greatest-fixnum)'s own digits is a fixnum, so
;; the numbers fed run every magnitude up to it.
;;
;; One u64 field; an accumulate node that is its own digit-target; a `;` (a
;; non-digit, consumed) clears the field and returns to the node. Base 10 and
;; base 16 both, because the HTTP machine reads a u64 in each.
(define (u64-accumulate-machine name base)
  (make-machine name 'n (list (make-uint-field 'v 64 0 #f)) '() '()
                (list (make-error-declaration 'default-eof 'eof "unexpected end of input" #f)
                      (make-error-declaration 'too-big 'unexpected-byte "field overflow" #f))
                (list (make-integer-accumulate-node 'n 'v base 'n (make-edge 'zero 'advance)
                                                    'over #f #f)
                      (make-field-action-node 'zero 'clear '(v) 'n #f #f)
                      (make-error-node 'over 'too-big #f))
                'default-eof #f))

;; `copies` numbers, each ended by `;`, then one more left open, so the field
;; holds `n` when the feed ends: the answer a case reads back.
(define (numbers-request n base copies)
  (let* ((digits (bytes (number->string n base)))
         (one (append digits (list 59))))
    (u8-list->bytevector
     (let loop ((i 0) (acc digits))
       (if (= i copies) acc (loop (+ i 1) (append one acc)))))))
(define few-numbers 10)
(define many-numbers 1010)
(define digit-reps 20)

;; The checks one base owes, in a case that names the base.
(define (u64-digits-check base name)
  (let* ((pair (load-pair (u64-accumulate-machine name base) name))
         (real (car pair)) (twin (cadr pair))
         (top (greatest-fixnum))
         (wide (- (expt 2 64) 1))
         (few (numbers-request top base few-numbers))
         (many (numbers-request top base many-numbers))
         (few-wide (numbers-request wide base few-numbers))
         (many-wide (numbers-request wide base many-numbers))
         (answer (lambda (req)
                   (let* ((p (make-parser real '() #f))
                          (r (parser-feed! p req 0 (bytevector-length req))))
                     (list (parser-result-status r) (parser-field-ref p 'v)))))
         (extra (lambda (more less)
                  (- (alloc-feeding-only real '() more digit-reps)
                     (alloc-feeding-only real '() less digit-reps)))))
    ;; The answers first, so an arm that stopped accumulating could not pass by
    ;; allocating nothing.
    (check-equal "u64 digits: the fixnum-range feed ends holding the largest fixnum"
                 (answer many) (list 'need-input top))
    (check-equal "u64 digits: the wide feed ends holding 2^64 - 1"
                 (answer many-wide) (list 'need-input wide))
    (let ((wide-extra (extra many-wide few-wide)))
      (check "control: digits storing a bignum allocate" (positive? wide-extra))
      (say (string-append "byte-machine-alloc: u64 base " (number->string base)
                          " B/number above the fixnum range="
                          (adapter-value->string (/ wide-extra (* digit-reps
                                                                  (- many-numbers few-numbers))))
                          " (" (number->string (string-length (number->string wide base)))
                          " digits each)")))
    (check-equal "u64 digits: extra bytes for 1000 more fixnum-range numbers"
                 (extra many few) 0)
    (witness-feed! twin '() few)
    (witness-feed! twin '() many)
    ;; The overflow arm, which the arm-kind census asks for: 2^64 after the
    ;; same two runs of numbers, refused at its last digit. Like the error
    ;; witnesses above, the event costs the same however much precedes it.
    (let* ((over (append (list 59) (bytes (number->string (expt 2 64) base))))
           (refused (lambda (req) (u8-list->bytevector (append (bytevector->u8-list req) over))))
           (few-over (refused few)) (many-over (refused many))
           (r (feed-only real '() many-over)))
      (check-equal "u64 overflow: refused at the last digit of 2^64"
                   (list (parser-result-status r) (parser-error-code (parser-result-error r))
                         (- (bytevector-length many-over) (parser-error-offset (parser-result-error r))))
                   '(error unexpected-byte 1))
      (check-equal "u64 overflow: extra bytes when 1000 more numbers precede it"
                   (- (alloc-feeding-only real '() many-over digit-reps)
                      (alloc-feeding-only real '() few-over digit-reps))
                   0)
      (witness-feed! twin '() few-over)
      (witness-feed! twin '() many-over))))

(harness-group "a digit read into a u64 field allocates nothing while its value is a fixnum"
  (lambda ()
    (harness-case "base 10: digits up to the largest fixnum allocate nothing"
      (lambda () (u64-digits-check 10 'acc64dec)))
    (harness-case "base 16: digits up to the largest fixnum allocate nothing"
      (lambda () (u64-digits-check 16 'acc64hex)))))

;; --- the body path, per BODY byte and per CHUNK ------------------------------
;;
;; The arm-kind census below found the HTTP machine's whole body path outside
;; every group above: the Content-Length digits, the framing branches and flag
;; stores, the two counted-consume arms, and the chunked grammar. Its arms call
;; no runtime op the slopes did not already reach, so the op census had nothing
;; to report. These messages take that path, and the claims are the slopes'
;; own: a body's allocation does not depend on its length, nor a chunked body's
;; on how many chunks it has.
;;
;; A count above the fixnum range is asserted too. Counted consume subtracts
;; what a feed consumed from the field, so a bignum count stores a new bignum
;; once per FEED; what it consumes per byte is still nothing, and that is the
;; claim gated here.

(define (cl-request content-length body-len)
  (u8-list->bytevector
   (bytes (string-append "POST / HTTP/1.1\r\nContent-Length: " (number->string content-length)
                         "\r\n\r\n" (make-string body-len #\b)))))
;; `chunks` chunks of `chunk-len` bytes each, then the last chunk and the end of
;; the (empty) trailer section.
(define (chunked-request chunks chunk-len)
  (u8-list->bytevector
   (bytes (string-append "POST / HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n"
                         (let loop ((i 0) (acc ""))
                           (if (= i chunks) acc
                               (loop (+ i 1)
                                     (string-append acc (number->string chunk-len 16) "\r\n"
                                                    (make-string chunk-len #\b) "\r\n"))))
                         "0\r\n\r\n"))))
;; The same body, stopped one byte short of its last chunk's end.
(define (chunked-prefix chunks chunk-len)
  (let ((whole (chunked-request chunks chunk-len)))
    (subbytevector whole 0 (- (bytevector-length whole) 8))))
(define (subbytevector bv from to)
  (let ((out (make-bytevector (- to from))))
    (bytevector-copy! bv from out 0 (- to from))
    out))
(define few-chunks 1)
(define many-chunks 201)
(define chunk-difference 200)

;; The feed and finish statuses of a whole message, and after a prefix of one,
;; the feed status, the named count field and the state it waits in.
(define (whole-answer cm req)
  (let* ((p (make-parser cm '() #f))
         (r (parser-feed! p req 0 (bytevector-length req))))
    (list (parser-result-status r) (parser-result-status (parser-finish! p)))))
(define (prefix-answer cm req field)
  (let* ((p (make-parser cm '() #f))
         (r (parser-feed! p req 0 (bytevector-length req))))
    (list (parser-result-status r) (parser-field-ref p field) (parser-state-name p))))

(define body-bindings
  (let ((ev (lambda (ps ux) callback-continue))
        (dv (lambda (ps ux bv from to) callback-continue)))
    (list (list 'message-begin ev) (list 'message-complete ev) (list 'body-data dv)
          (list 'chunk-header ev) (list 'chunk-complete ev))))

(harness-group "a body allocates nothing per body byte or per chunk"
  (lambda ()
    (harness-case "a fixed body's allocation does not grow with its length"
      (lambda ()
        ;; Two lengths with the same number of digits, so the messages differ in
        ;; body bytes alone and the Content-Length digits' own cost, whatever it
        ;; is, cannot enter this slope.
        (let ((short (cl-request 10044 10044)) (long (cl-request 50044 50044))
              (open (cl-request 50044 50043)))
          ;; The answers first, so a path that stopped consuming the body could
          ;; not pass by allocating nothing.
          (check-equal "fixed body: a whole message completes" (whole-answer generated long)
                       '(need-input finished))
          (check-equal "fixed body: one byte short, the count holds the byte still owed"
                       (prefix-answer generated open 'content-length)
                       '(need-input 1 body-consume))
          (check "control: alloc(40044) > alloc(44)"
                 (> (control-alloc 40044 gen-reps) (control-alloc 44 gen-reps)))
          (check-equal "fixed body: alloc(10044-byte body) = alloc(50044-byte body)"
                       (alloc-feeding generated '() long gen-reps)
                       (alloc-feeding generated '() short gen-reps))
          (check-equal "fixed body, callbacks bound: alloc(10044-byte body) = alloc(50044-byte body)"
                       (alloc-feeding generated body-bindings long gen-reps)
                       (alloc-feeding generated body-bindings short gen-reps))
          (witness! (cadr http-pair) '() short)
          (witness! (cadr http-pair) '() long)
          (witness-feed! (cadr http-pair) '() open))))
    (harness-case "a fixed body whose count is above the fixnum range costs nothing per byte"
      (lambda ()
        ;; Content-Length 2^64 - 1: the count is a bignum before and after the
        ;; feed, which ends inside the body.
        (let* ((top (- (expt 2 64) 1))
               (short (cl-request top 44)) (long (cl-request top 40044)))
          (check-equal "bignum count: the count after 40044 body bytes"
                       (prefix-answer generated long 'content-length)
                       (list 'need-input (- top 40044) 'body-consume))
          (check "control: alloc(40044) > alloc(44)"
                 (> (control-alloc 40044 gen-reps) (control-alloc 44 gen-reps)))
          (check-equal "bignum count: alloc(44 body bytes) = alloc(40044 body bytes)"
                       (alloc-feeding-only generated '() long gen-reps)
                       (alloc-feeding-only generated '() short gen-reps))
          (say (string-append "byte-machine-alloc: fixed body B/message with a count above the fixnum range="
                              (adapter-value->string
                               (div (- (alloc-feeding-only generated '() short gen-reps)
                                       (alloc-feeding-only generated '() (cl-request 44 44) gen-reps))
                                    gen-reps))
                              " more than with a fixnum count"))
          (witness-feed! (cadr http-pair) '() short)
          (witness-feed! (cadr http-pair) '() long))))
    (harness-case "a chunked body's allocation does not grow with its chunk count"
      (lambda ()
        (let ((few (chunked-request few-chunks 44)) (many (chunked-request many-chunks 44))
              (open (chunked-prefix many-chunks 44)))
          (check-equal "chunked body: a whole message completes" (whole-answer generated many)
                       '(need-input finished))
          (check-equal "chunked body: one byte short, the chunk size holds the byte still owed"
                       (prefix-answer generated open 'chunk-size)
                       '(need-input 1 chunk-data-consume))
          (check "control: alloc(201 chunks) > alloc(1)"
                 (> (control-alloc many-chunks gen-reps) (control-alloc few-chunks gen-reps)))
          (let ((disabled (- (alloc-feeding generated '() many gen-reps)
                             (alloc-feeding generated '() few gen-reps)))
                (bound (- (alloc-feeding generated body-bindings many gen-reps)
                          (alloc-feeding generated body-bindings few gen-reps))))
            (say (string-append "byte-machine-alloc: generated B/chunk disabled="
                                (adapter-value->string (/ disabled (* gen-reps chunk-difference)))
                                " bound=" (adapter-value->string (/ bound (* gen-reps chunk-difference)))))
            (check-equal "chunked body: extra bytes for 200 more chunks" disabled 0)
            (check-equal "chunked body, callbacks bound: extra bytes for 200 more chunks" bound 0))
          (witness! (cadr http-pair) '() few)
          (witness! (cadr http-pair) '() many)
          (witness-feed! (cadr http-pair) '() open))))
    (harness-case "a chunk whose size is above the fixnum range costs nothing per byte"
      (lambda ()
        ;; Sixteen hex digits, 2^64 - 1: the size is a bignum while the data is
        ;; consumed, and the feed ends inside it.
        (let* ((top (- (expt 2 64) 1))
               (head "POST / HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\nffffffffffffffff\r\n")
               (req (lambda (n) (u8-list->bytevector (bytes (string-append head (make-string n #\b))))))
               (short (req 44)) (long (req 40044)))
          (check-equal "bignum chunk: the size after 40044 data bytes"
                       (prefix-answer generated long 'chunk-size)
                       (list 'need-input (- top 40044) 'chunk-data-consume))
          (check "control: alloc(40044) > alloc(44)"
                 (> (control-alloc 40044 gen-reps) (control-alloc 44 gen-reps)))
          (check-equal "bignum chunk: alloc(44 data bytes) = alloc(40044 data bytes)"
                       (alloc-feeding-only generated '() long gen-reps)
                       (alloc-feeding-only generated '() short gen-reps))
          (witness-feed! (cadr http-pair) '() short)
          (witness-feed! (cadr http-pair) '() long))))))

;; --- a pause, per byte before it ----------------------------------------------
;;
;; No fixture above has a pause node, so the arm-kind census asks for one. A
;; pause ends the feed, as an error does, and owes the same shape: what the
;; event costs does not depend on how many bytes came before it. One machine,
;; both renderings of the arm: `;` pauses with no reason, `!` with one.
(define pause-machine
  (make-machine 'pausecensus 'loop '() '() '()
                (list (make-error-declaration 'default-eof 'eof "unexpected end of input" #f)
                      (make-error-declaration 'held 'held "held for the application" #f))
                (list (make-byte-dispatch-node
                       'loop
                       (list (make-byte-case (make-exact-byte-matcher 59) (make-edge 'hold 'advance) #f)
                             (make-byte-case (make-exact-byte-matcher 33) (make-edge 'hold-why 'advance) #f))
                       (make-edge 'loop 'advance) #f #f)
                      (make-pause-node 'hold 'loop #f)
                      (make-pause-node 'hold-why 'loop 'held #f))
                'default-eof #f))
(define pause-pair (load-pair pause-machine 'pausecensus))

(harness-group "a pause allocates the same however many bytes precede it"
  (lambda ()
    (harness-case "a pause's outcome does not grow with the offset it reports"
      (lambda ()
        (let* ((real (car pause-pair)) (twin (cadr pause-pair))
               (req (lambda (n end) (u8-list->bytevector
                                     (append (bytes (make-string n #\a)) (list end)))))
               (answer (lambda (bv)
                         (let* ((r (feed-only real '() bv)) (why (parser-result-pause r)))
                           (list (parser-result-status r) (parser-result-stream-offset r)
                                 (and why (parser-error-code why)))))))
          (check-equal "pause: both arms answer, after 40044 bytes"
                       (list (answer (req 40044 59)) (answer (req 40044 33)))
                       '((paused 40045 #f) (paused 40045 held)))
          (check "control: alloc(40044) > alloc(44)"
                 (> (control-alloc 40044 gen-reps) (control-alloc 44 gen-reps)))
          (check-equal "pause: alloc(short prefix) = alloc(long prefix), each arm"
                       (map (lambda (end) (- (alloc-feeding-only real '() (req 40044 end) gen-reps)
                                             (alloc-feeding-only real '() (req 44 end) gen-reps)))
                            '(59 33))
                       '(0 0))
          (for-each (lambda (end)
                      (witness-feed! twin '() (req 44 end))
                      (witness-feed! twin '() (req 40044 end)))
                    '(59 33)))))))

;; --- every field operation and predicate, per EXECUTION, on a u64 field -------
;;
;; The HTTP machine renders three field arms -- `store`, `clear` and `nonzero`
;; -- and the emitter renders fourteen, each its own inline arithmetic on the
;; field's value and the node's constants. A 64-bit field's constants can be
;; bignums, and arithmetic on a bignum at run time allocates: that is how the
;; accumulate arm came to allocate on every digit. So every operation and every
;; predicate runs here, on a u64 field, with bignum constants wherever the
;; value stays a fixnum.
;;
;; The claim is the digit group's, applied to the zero-width arms: an arm
;; executed allocates nothing while every value it computes is a fixnum. Each row runs twice from a
;; settable initial value: once below (greatest-fixnum), gated at zero, and once
;; above it, recorded. Above it, an arm whose result is a bignum allocates that
;; result -- `increment` from (greatest-fixnum) + 1 is this group's live
;; control -- and a comparison against a bignum allocates nothing.
;;
;; One machine: a loop that reads a byte and returns to itself, with byte a, b,
;; ... running one operation each on its own field and A, B, ... testing one
;; predicate each, a hit incrementing that predicate's counter. A fallible
;; operation's failure edge goes back to the loop, so the machine has no error
;; state for a witness to owe.
(define u64-top (- (expt 2 64) 1))
(define bit63 (expt 2 63))
;; (operation constants fixnum-initial above-initial value-after-n)
(define field-op-rows
  (list (list 'store '(5) 0 u64-top (lambda (v n) 5))
        (list 'clear '() 7 u64-top (lambda (v n) 0))
        (list 'increment '() (- (greatest-fixnum) 2000) (+ (greatest-fixnum) 1)
              (lambda (v n) (+ v n)))
        (list 'decrement '() 5000 u64-top (lambda (v n) (- v n)))
        (list 'add '(3) 0 (+ (greatest-fixnum) 1) (lambda (v n) (+ v (* 3 n))))
        (list 'set-mask '(6) 1 bit63 (lambda (v n) (bitwise-ior v 6)))
        (list 'clear-mask (list (+ bit63 6)) 7 u64-top
              (lambda (v n) (bitwise-and v (bitwise-not (+ bit63 6)))))))
;; (predicate constants fixnum-initial above-initial holds?). Every fixnum
;; initial makes its predicate hold, so the counter's increment runs too.
(define field-predicate-rows
  (list (list 'equal '(7) 7 u64-top (lambda (v) (= v 7)))
        (list 'zero '() 0 u64-top (lambda (v) (= v 0)))
        (list 'nonzero '() 7 u64-top (lambda (v) (not (= v 0))))
        (list 'range (list 1 u64-top) 7 u64-top (lambda (v) (and (<= 1 v) (<= v u64-top))))
        (list 'mask-any (list (+ bit63 6)) 7 u64-top
              (lambda (v) (not (= 0 (bitwise-and v (+ bit63 6))))))
        (list 'mask-all '(6) 7 u64-top (lambda (v) (= 6 (bitwise-and v 6))))
        (list 'mask-none (list (+ bit63 8)) 7 u64-top
              (lambda (v) (= 0 (bitwise-and v (+ bit63 8)))))))
(define (sym . parts) (string->symbol (apply string-append parts)))
(define (row-field prefix row) (sym prefix (symbol->string (car row))))
(define (row-byte base rows row)
  (+ base (- (length rows) (length (memq row rows)))))
(define field-machine
  (make-machine
   'fieldcensus 'loop
   (append (map (lambda (r) (make-uint-field (row-field "f-" r) 64 0 #t #f)) field-op-rows)
           (map (lambda (r) (make-uint-field (row-field "p-" r) 64 0 #t #f)) field-predicate-rows)
           (map (lambda (r) (make-uint-field (row-field "t-" r) 64 0 #f)) field-predicate-rows))
   '() '()
   (list (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
   (append
    (list (make-byte-dispatch-node
           'loop
           (append (map (lambda (r) (make-byte-case
                                     (make-exact-byte-matcher (row-byte 97 field-op-rows r))
                                     (make-edge (row-field "do-" r) 'advance) #f))
                        field-op-rows)
                   (map (lambda (r) (make-byte-case
                                     (make-exact-byte-matcher (row-byte 65 field-predicate-rows r))
                                     (make-edge (row-field "test-" r) 'advance) #f))
                        field-predicate-rows))
           (make-edge 'loop 'advance) #f #f))
    (map (lambda (r)
           (make-field-action-node (row-field "do-" r) (car r) (cons (row-field "f-" r) (cadr r))
                                   'loop (and (memq (car r) '(increment decrement add)) 'loop) #f))
         field-op-rows)
    (map (lambda (r)
           (make-field-branch-node (row-field "test-" r) (car r) (cons (row-field "p-" r) (cadr r))
                                   (row-field "hit-" r) 'loop #f))
         field-predicate-rows)
    (map (lambda (r)
           (make-field-action-node (row-field "hit-" r) 'increment (list (row-field "t-" r))
                                   'loop 'loop #f))
         field-predicate-rows))
   'default-eof #f))
(define field-pair (load-pair field-machine 'fieldcensus))
(define few-executions 10)
(define many-executions 1010)

;; One feed of `n` copies of `byte`, from a parser whose field `field` starts at
;; `initial`. The input and the override list are built before the measured
;; loop, so it counts what the parser allocates and nothing of the case's own.
(define (feed-with cm initials bv)
  (let ((p (make-parser cm '() #f initials)))
    (cons p (parser-feed! p bv 0 (bytevector-length bv)))))
(define (alloc-executing cm field initial byte n)
  (let ((initials (list (cons field initial))) (bv (make-bytevector n byte)))
    (collect)
    (let ((before (sstats-bytes (statistics))))
      (do ((i 0 (+ i 1))) ((= i digit-reps))
        (feed-with cm initials bv))
      (- (sstats-bytes (statistics)) before))))

;; Per row and run: what 1000 more executions allocated, and whether the feed
;; answered what the row says it should.
(define (field-row-run real twin field byte initial expected read)
  (let* ((initials (list (cons field initial)))
         (fed (feed-with real initials (make-bytevector many-executions byte)))
         (got (cons (parser-result-status (cdr fed)) (read (car fed)))))
    (witness-run! (lambda () (feed-with twin initials (make-bytevector many-executions byte))))
    (list (equal? got (cons 'need-input expected))
          got
          (- (alloc-executing real field initial byte many-executions)
             (alloc-executing real field initial byte few-executions)))))

(harness-group "a field arm allocates nothing per execution while its values are fixnums"
  (lambda ()
    (harness-case "every operation and predicate, below and above the fixnum range"
      (lambda ()
        (let* ((real (car field-pair)) (twin (cadr field-pair))
               (runs
                (append
                 (map (lambda (r)
                        (let ((f (row-field "f-" r)) (b (row-byte 97 field-op-rows r)))
                          (define (run initial)
                            (field-row-run real twin f b initial
                                           (list ((list-ref r 4) initial many-executions))
                                           (lambda (p) (list (parser-field-ref p f)))))
                          (list (car r) (run (caddr r)) (run (cadddr r)))))
                      field-op-rows)
                 (map (lambda (r)
                        (let ((f (row-field "p-" r)) (t (row-field "t-" r))
                              (b (row-byte 65 field-predicate-rows r)))
                          (define (run initial)
                            (field-row-run real twin f b initial
                                           (list initial (if ((list-ref r 4) initial)
                                                             many-executions 0))
                                           (lambda (p) (list (parser-field-ref p f)
                                                             (parser-field-ref p t)))))
                          (list (car r) (run (caddr r)) (run (cadddr r)))))
                      field-predicate-rows)))
               ;; (arm got) for each run whose answer was not the row's.
               (wrong (apply append
                             (map (lambda (x)
                                    (append (if (car (cadr x)) '() (list (list (car x) (cadr (cadr x)))))
                                            (if (car (caddr x)) '() (list (list (car x) (cadr (caddr x)))))))
                                  runs)))
               (extra-below (map (lambda (x) (cons (car x) (caddr (cadr x)))) runs))
               (extra-above (map (lambda (x) (cons (car x) (caddr (caddr x)))) runs)))
          ;; The answers first, so an arm that stopped computing could not
          ;; pass by allocating nothing.
          (check-equal "field arms that did not answer their row (arm got)" wrong '())
          (check "control: an increment storing a bignum allocates"
                 (positive? (cdr (assq 'increment extra-above))))
          (say (string-append "byte-machine-alloc: field arm B/execution above the fixnum range="
                              (adapter-value->string
                               (map (lambda (x) (cons (car x) (/ (cdr x) (* digit-reps 1000))))
                                    extra-above))))
          (check-equal "field arms that allocated for 1000 more fixnum-range executions (arm . extra bytes)"
                       (filter (lambda (x) (not (zero? (cdr x)))) extra-below)
                       '()))))))

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

;; The closed sets the emitter renders, read from compile.sls the way the op
;; census reads its literals: the labels of the `case` on `key` inside the
;; procedure `proc`. The recogniser is that pair; a dispatch written any other
;; way derives nothing, and the first check below then names every kind the
;; audited machines render.
(define (case-labels proc key)
  (define (find-form match? d)
    (cond ((match? d) d)
          ((pair? d) (or (find-form match? (car d)) (find-form match? (cdr d))))
          (else #f)))
  (let* ((def (find-form (lambda (d) (and (pair? d) (eq? (car d) 'define)
                                          (pair? (cdr d)) (pair? (cadr d))
                                          (eq? (car (cadr d)) proc)))
                         (car compile-src)))
         (c (and def (find-form (lambda (d) (and (pair? d) (eq? (car d) 'case)
                                                 (pair? (cdr d)) (equal? (cadr d) key)))
                                def))))
    (if c
        (fold-left (lambda (acc clause) (if (pair? (car clause)) (append acc (car clause)) acc))
                   '() (cddr c))
        '())))
(define emitted-kinds (case-labels 'render-state-arm '(normal-state-kind s)))
(define emitted-operations (case-labels 'render-operation 'op))
(define emitted-predicates (case-labels 'render-predicate 'pred))

;; The shape of every state some witness entered, and of every state an audited
;; machine renders, each as (machine . shape).
(define (shape-of name id) (vector-ref (cdr (assq name audited)) id))
(define (entered-shapes)
  (let-values (((ks vs) (hashtable-entries entered)))
    (map (lambda (k) (cons (car k) (shape-of (car k) (cdr k)))) (vector->list ks))))
(define (rendered-shapes)
  (apply append (map (lambda (a) (map (lambda (s) (cons (car a) s)) (vector->list (cdr a))))
                     audited)))
;; Each distinct (machine . kind) once, and each distinct (machine . arm), an
;; arm being its kind or, where the kind has a selector, (kind . selector).
(define (distinct xs)
  (fold-left (lambda (acc x) (if (member x acc) acc (cons x acc))) '() xs))
(define (machine-kinds shapes) (distinct (map (lambda (x) (cons (car x) (cadr x))) shapes)))
(define (machine-arms shapes)
  (distinct (map (lambda (x) (cons (car x) (if (cddr x) (cdr x) (cadr x)))) shapes)))
(define (iota-list n)
  (let loop ((i (- n 1)) (acc '())) (if (< i 0) acc (loop (- i 1) (cons i acc)))))
(define (by-name xs)
  (list-sort (lambda (a b) (string<? (adapter-value->string a) (adapter-value->string b))) xs))

(harness-group "the arm census: every arm an audited machine renders has a witness"
  (lambda ()
    (harness-case "every state procedure of every audited twin counts its entries"
      (lambda ()
        ;; The counter's own completeness: a state whose procedure the
        ;; instrumenter did not recognise would read as never entered.
        (check-equal "audited twins whose counters are not exactly their states (name ids states)"
                     (by-name (filter (lambda (x) (not (equal? (cadr x) (iota-list (caddr x)))))
                                      instrumented))
                     '())
        (for-each
         (lambda (a)
           (let ((n (vector-length (cdr a))))
             (say (string-append "byte-machine-alloc: arm census " (symbol->string (car a))
                                 " states entered="
                                 (number->string
                                  (length (filter (lambda (x) (eq? (car x) (car a)))
                                                  (entered-shapes))))
                                 " of " (number->string n)))))
         (reverse audited))))
    (harness-case "every arm kind an audited machine renders is one render-state-arm names"
      (lambda ()
        ;; The recogniser's control. No floor on the derived set's size: one
        ;; that read nothing leaves every kind the machines render outside it.
        (say (string-append "byte-machine-alloc: arm kinds=" (adapter-value->string emitted-kinds)
                            " operations=" (adapter-value->string emitted-operations)
                            " predicates=" (adapter-value->string emitted-predicates)))
        (check-equal "rendered kinds render-state-arm does not name"
                     (by-name (filter (lambda (x) (not (memq (cdr x) emitted-kinds)))
                                      (machine-kinds (rendered-shapes))))
                     '())))
    (harness-case "every arm kind render-state-arm renders is in some audited machine"
      (lambda ()
        ;; What makes the census total over the emitter rather than over the
        ;; fixtures: a new kind fails here until an audited machine renders it.
        (let ((rendered (map cdr (machine-kinds (rendered-shapes)))))
          (check-equal "emitted kinds no audited machine renders"
                       (by-name (filter (lambda (k) (not (memq k rendered))) emitted-kinds))
                       '()))))
    (harness-case "every arm an audited machine renders is entered there by a witness"
      (lambda ()
        ;; The totality row, per machine: an arm a machine renders and no
        ;; witness enters in that machine is code this audit has never run. Per
        ;; ARM, not per kind: the HTTP machine's base-10 accumulate (the
        ;; Content-Length digits) and its base-16 one (the chunk size) are two
        ;; arms, and entering one says nothing about the other.
        (let ((entered-arms (machine-arms (entered-shapes))))
          (check-equal "rendered (machine . arm) no witness entered"
                       (by-name (filter (lambda (x) (not (member x entered-arms)))
                                        (machine-arms (rendered-shapes))))
                       '()))))
    ;; One level down, over the emitter's whole set. A field arm is the
    ;; operation or predicate it renders, and each renders its own inline
    ;; arithmetic, which no census of runtime ops or arm kinds can tell apart.
    ;; These two rows ask for each one in SOME machine; the row above already
    ;; asks for each one an audited machine renders, in that machine.
    (harness-case "every field operation and predicate a witness entered is one the emitter names"
      (lambda ()
        (check-equal "entered field arms render-operation and render-predicate do not name"
                     (by-name (distinct
                               (filter (lambda (s)
                                         (case (car s)
                                           ((field-action) (not (memq (cdr s) emitted-operations)))
                                           ((field-branch) (not (memq (cdr s) emitted-predicates)))
                                           (else #f)))
                                       (map cdr (entered-shapes)))))
                     '())))
    (harness-case "every field operation and predicate the emitter renders is entered by a witness"
      (lambda ()
        (let ((shapes (map cdr (entered-shapes))))
          (check-equal "emitted field arms no witness entered"
                       (by-name (filter (lambda (s) (not (member s shapes)))
                                        (append (map (lambda (o) (cons 'field-action o))
                                                     emitted-operations)
                                                (map (lambda (p) (cons 'field-branch p))
                                                     emitted-predicates))))
                       '()))))))

(harness-finish)
