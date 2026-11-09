;;; The run loop, interpreter against generated. A dispatch state that advances
;;; back to itself renders a loop beside it (compile.sls, `render-run-loop`),
;;; and the loop machine ((byte-machine test loop-machine)) has one of each
;;; shape: a class of one byte, of one run, of several runs (a table), two
;;; states sharing one table, a fallback that loops, a class of every byte, an
;;; exit byte through each kind of clause, and three spans open across a loop.
;;;
;;; What is compared:
;;;   - the emitted loops themselves, read back from the rendered library as a
;;;     datum: one loop per qualifying state and no other, each testing exactly
;;;     the class the fixture declares by hand, one table per distinct class;
;;;   - every two-way feed split of each input, each feed copied behind its own
;;;     padding so a slice index is never its stream offset, with bytes after
;;;     the slice a loop reading past `end` would take;
;;;   - each input a byte at a time, and two parsers fed interleaved;
;;;   - `finish?` with the input ending inside each loop;
;;;   - the bytes either side of every class edge, read by the state's arm and
;;;     by its loop;
;;;   - each input's whole trace against an expected value, in both lanes,
;;;     since two lanes can agree on a wrong one.
;;;
;;; Every feed runs in an explicit left-to-right loop, never `map`.
(import (rnrs) (rnrs eval)
        (only (chezscheme) load)
        (byte-machine test harness)
        (byte-machine test error-projection)
        (byte-machine test loop-machine)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime)
        (byte-machine compile)
        (only (byte-machine private normal-ir)
              normalize-machine normal-machine-states normal-machine-debug-map
              normal-state-kind normal-state-id
              normal-dispatch-transitions normal-dispatch-fallback))

(harness-begin "differential.loop")

(define tmpdir
  (let ((d (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")))
    (if (and d (not (string=? d ""))) d
        (assertion-violation 'differential-loop "BYTE_MACHINE_TEST_TMPDIR is unset" d))))

(define machine (make-loop-machine))
(define v (verify-machine machine))
(define compiled (compile-machine machine '()))
(define rendered (render-machine compiled 'loopm-parser))
(define genfile (string-append tmpdir "/differential-loop.sls"))
(call-with-port (open-file-output-port genfile (file-options no-fail))
  (lambda (p) (put-bytevector p rendered)))
(load genfile)
(define cm-gen (eval 'loopm-parser (environment '(generated loopm))))
(define cm-ref (make-interpreted-machine v))

;; --- the emitted loops, read back ---------------------------------------------

(define normal (normalize-machine (verification-machine v)))
(define names (normal-machine-debug-map normal))
(define (name-of id) (cdr (assv id names)))
(define (sorted-names xs)
  (list-sort (lambda (a b) (string<? (symbol->string a) (symbol->string b))) xs))

;; The class the normalized IR gives a dispatch state: every byte a transition
;; sends back to it by advance, and, when its fallback advances back to it,
;; every byte no transition names. A state loops when that holds a byte; an
;; edge back to it is not enough, since a looping fallback on a state whose
;; cases name every byte is never taken. Derived here, beside the emitter's own
;; reading, so the two meet.
(define (ir-class s)
  (let* ((id (normal-state-id s)) (fb (normal-dispatch-fallback s))
         (fb-self? (and (= (car fb) id) (eq? (cdr fb) 'advance)))
         (trs (normal-dispatch-transitions s)))
    (let loop ((b 255) (acc '()))
      (if (< b 0) acc
          (loop (- b 1)
                (let ((t (assv b trs)))
                  (if (if t (and (= (cadr t) id) (eq? (caddr t) 'advance)) fb-self?)
                      (cons b acc) acc)))))))
(define (qualifying-of normal)
  (let loop ((ss (vector->list (normal-machine-states normal))) (acc '()))
    (if (null? ss) (sorted-names acc)
        (let ((s (car ss)))
          (loop (cdr ss)
                (if (and (eq? (normal-state-kind s) 'dispatch) (pair? (ir-class s)))
                    (cons (cdr (assv (normal-state-id s) (normal-machine-debug-map normal))) acc)
                    acc))))))
(define qualifying (qualifying-of normal))

(define lib (read (open-string-input-port (utf8->string rendered))))
(define (prefixed-id sym prefix)
  (let ((s (symbol->string sym)) (n (string-length prefix)))
    (and (> (string-length s) n) (string=? (substring s 0 n) prefix)
         (string->number (substring s n (string-length s))))))
;; The library-level tables, as (k . bytevector).
(define tables
  (let loop ((fs (cddddr lib)) (acc '()))
    (if (null? fs) (reverse acc)
        (let ((f (car fs)))
          (loop (cdr fs)
                (if (and (pair? f) (eq? (car f) 'define) (symbol? (cadr f))
                         (prefixed-id (cadr f) "%c"))
                    (cons (cons (prefixed-id (cadr f) "%c") (cadr (caddr f))) acc)
                    acc))))))
;; The loops inside `exec`, as (id . form).
(define loops
  (let* ((exec (find (lambda (f) (and (pair? f) (eq? (car f) 'define) (pair? (cadr f))
                                      (eq? (car (cadr f)) 'exec)))
                     (cddddr lib))))
    (filter (lambda (x) x)
            (map (lambda (f)
                   (and (pair? f) (eq? (car f) 'define) (pair? (cadr f))
                        (prefixed-id (car (cadr f)) "%r")
                        (cons (prefixed-id (car (cadr f)) "%r") f)))
                 (cddr exec)))))
;; The class a loop tests, as ascending runs, read off its form:
;;   (define (%rN n pos off) (if (fx<? n end) BODY LEAVE))
;; BODY is the step itself when the class is every byte, or
;;   (let ((b (bytevector-u8-ref bv n))) (if TEST STEP EXIT)).
(define (runs-of bv-or-bytes)
  (let walk ((b 0) (lo #f) (acc '()))
    (cond ((= b 256) (reverse (if lo (cons (cons lo 255) acc) acc)))
          ((memv b bv-or-bytes) (walk (+ b 1) (or lo b) acc))
          (else (walk (+ b 1) #f (if lo (cons (cons lo (- b 1)) acc) acc))))))
(define (table-bytes k)
  (let ((t (cdr (assv k tables))))
    (let loop ((b 255) (acc '()))
      (if (< b 0) acc (loop (- b 1) (if (= 1 (bytevector-u8-ref t b)) (cons b acc) acc))))))
(define (span-bytes lo hi) (let loop ((b hi) (acc '())) (if (< b lo) acc (loop (- b 1) (cons b acc)))))
(define (tested-class form)
  (let ((body (caddr (caddr form))))
    (cond ((and (pair? body) (eq? (car body) 'let))
           (let ((test (cadr (caddr body))))
             (cond ((and (eq? (car test) 'fx=?) (eq? (cadr test) 'b)) (list (caddr test)))
                   ((eq? (car test) 'and) (span-bytes (caddr (cadr test)) (caddr (caddr test))))
                   ((eq? (car test) 'fx=?)
                    (table-bytes (prefixed-id (cadr (caddr test)) "%c")))
                   (else (list 'unread test)))))
          (else (span-bytes 0 255)))))
(define (tables-used form)
  (let ((body (caddr (caddr form))))
    (if (and (pair? body) (eq? (car body) 'let))
        (let ((test (cadr (caddr body))))
          (if (and (eq? (car test) 'fx=?) (pair? (caddr test)))
              (list (prefixed-id (cadr (caddr test)) "%c"))
              '()))
        '())))

(harness-group "the machine and its emitted loops"
  (lambda ()
    (harness-case "the machine verifies with no diagnostics"
      (lambda ()
        (check-equal "diagnostics" (map diagnostic-code (verification-diagnostics v)) '())))
    (harness-case "the declared classes name exactly the states the IR says loop"
      (lambda ()
        ;; The fixture's table is keyed by state name: assert the keys are
        ;; the qualifying states, so a row cannot describe a state that does
        ;; not loop, or miss one that does.
        (check-equal "qualifying states" qualifying
                     '(comment key num start text val ws))
        (check-equal "declared states" (sorted-names (map car (loop-classes))) qualifying)))
    (harness-case "every qualifying state renders one loop, and no other state does"
      (lambda ()
        (check-equal "states with a loop" (sorted-names (map (lambda (l) (name-of (car l))) loops))
                     qualifying)
        (check-equal "one loop each" (length loops) (length qualifying))))
    (harness-case "each loop tests the class the fixture declares"
      (lambda ()
        (let ((seen 0))
          (for-each
           (lambda (l)
             (set! seen (+ seen 1))
             (check-equal (string-append "class of " (symbol->string (name-of (car l))))
                          (runs-of (tested-class (cdr l)))
                          (cdr (assq (name-of (car l)) (loop-classes)))))
           loops)
          (check-equal "loops read" seen 7))))
    (harness-case "one table per distinct class of several runs, shared by the states with it"
      (lambda ()
        ;; ws, key and val, text: three classes of several runs, key and val
        ;; sharing one.
        (check-equal "tables" (map car tables) '(0 1 2))
        (check-equal "tables a loop reads, by state"
                     (list-sort (lambda (a b) (string<? (symbol->string (car a)) (symbol->string (car b))))
                                (filter (lambda (x) (pair? (cdr x)))
                                        (map (lambda (l) (cons (name-of (car l)) (tables-used (cdr l))))
                                             loops)))
                     '((key 1) (text 2) (val 1) (ws 0)))
        (check "no two tables hold one class"
               (let pairs ((ts tables))
                 (or (null? ts)
                     (and (for-all (lambda (u) (not (equal? (cdr (car ts)) (cdr u)))) (cdr ts))
                          (pairs (cdr ts))))))))))

;; --- running a schedule in one lane --------------------------------------------

(define (str->bytes s) (map char->integer (string->list s)))

;; A recorder per run: each fragment as (span . bytes), in order.
(define (make-recorder)
  (let ((since '()) (all '()))
    (define (cb span)
      (lambda (ps ux bv from to)
        (let ((e (cons span (let loop ((i (- to 1)) (acc '()))
                              (if (< i from) acc (loop (- i 1) (cons (bytevector-u8-ref bv i) acc)))))))
          (set! since (cons e since)) (set! all (cons e all)))
        callback-continue))
    (list (list (list 'on-key (cb 'key)) (list 'on-val (cb 'val)) (list 'on-text (cb 'text)))
          (lambda () (let ((t (reverse since))) (set! since '()) t))
          (lambda () (reverse all)))))

;; One step's observation: the result's status, consumed, stream offset and
;; projected error, the parser's lifecycle, parked state and active span, and
;; the fragments delivered during the step.
(define (observe r p events)
  (list (parser-result-status r) (parser-result-consumed r) (parser-result-stream-offset r)
        (project-error (parser-result-error r))
        (parser-lifecycle p) (parser-state-name p) (parser-active-span p)
        (events)))

;; Pads around every feed. BEFORE differs per feed, so no slice starts at its
;; stream offset. AFTER holds a byte of each class, so a loop that read past
;; the slice's end would consume or dispatch one.
(define pad-after (str->bytes "\n a5\t\"#"))
(define (padded bytes k)
  (let* ((before (+ 1 (* 3 k)))
         (bv (u8-list->bytevector (append (make-list before 255) bytes pad-after))))
    (values bv before (+ before (length bytes)))))
(define (make-list n x) (let loop ((i 0) (acc '())) (if (= i n) acc (loop (+ i 1) (cons x acc)))))

;; Feed each list of bytes in turn, then finish (unless the parser has already
;; left `ready`), observing every step. Returns (observations . all-fragments).
(define (run cm feeds) (run-bound cm feeds #t))
;; BIND? #f for a machine that declares none of the loop machine's callbacks.
(define (run-bound cm feeds bind?)
  (let* ((rec (make-recorder)) (p (make-parser cm (if bind? (car rec) '()) #f)))
    (let loop ((fs feeds) (k 0) (out '()))
      (cond ((null? fs)
             (let ((r (if (eq? (parser-lifecycle p) 'ready) (parser-finish! p) #f)))
               (cons (reverse (if r (cons (observe r p (cadr rec)) out) out))
                     ((caddr rec)))))
            ((not (eq? (parser-lifecycle p) 'ready))
             (loop '() k out))
            (else
             (let-values (((bv s e) (padded (car fs) k)))
               (let ((r (parser-feed! p bv s e)))
                 (loop (cdr fs) (+ k 1) (cons (observe r p (cadr rec)) out)))))))))

;; What a schedule cannot change: the last result's status, stream offset and
;; error (but its span offset, which a boundary flush moves), the parked state,
;; and each span's bytes -- the fragments delivered, then, for a span an error
;; abandoned, the input from the error's span offset to its offset. Which of
;; those bytes were delivered and which abandoned depends on where the feeds
;; broke; together they do not.
(define (invariant result bytes)
  (let* ((obs (car result)) (last (car (reverse obs))) (e (list-ref last 3)))
    (list (list-ref last 0) (list-ref last 2)
          (if (pair? e) (list (list-ref e 1) (list-ref e 3) (list-ref e 4) (list-ref e 5) (list-ref e 6)) e)
          (list-ref last 5)
          (map (lambda (span)
                 (cons span
                       (append (apply append (map cdr (filter (lambda (f) (eq? (car f) span)) (cdr result))))
                               (if (and (pair? e) (eq? (list-ref e 6) span))
                                   (take (drop bytes (list-ref e 7)) (- (list-ref e 4) (list-ref e 7)))
                                   '()))))
               '(key val text)))))

(define (take xs k) (if (= k 0) '() (cons (car xs) (take (cdr xs) (- k 1)))))
(define (drop xs k) (if (= k 0) xs (drop (cdr xs) (- k 1))))
(define (bytes-each xs) (map list xs))

;; --- the inputs -----------------------------------------------------------------
;; Each with the whole-feed trace both lanes must produce: one observation for
;; the feed, one for the finish (none when the feed already ended the parse),
;; then every fragment.
(define inputs
  (list
   ;; key, val, the newline loop, blanks, a number, and the newline loop again.
   (list "ab=cd\n\n  \t12\n"
         '(((need-input 13 13 #f ready start #f ((key 97 98) (val 99 100)))
            (finished 0 13 #f finished fin #f ()))
           (key 97 98) (val 99 100)))
   ;; a text with a named `x`, an escape and its close, then a comment to EOF.
   (list "\"hix\\\"yo\"\n#c!"
         '(((need-input 13 13 #f ready comment #f ((text 104 105 120 92 34 121 111)))
            (finished 0 13 #f finished fin #f ()))
           (text 104 105 120 92 34 121 111)))
   ;; a number ended by `.`: the error state is entered by an advance, so it
   ;; reports a boundary after the dot.
   (list "k_9=V_8\n123.4"
         '(((error 12 12 (machine unexpected-byte "malformed number" numerr 12 boundary #f #f)
                   error numerr #f ((key 107 95 57) (val 86 95 56))))
           (key 107 95 57) (val 86 95 56)))
   ;; a control byte inside a text: reexecuted into the error state, so it
   ;; reports the byte itself. The text span is abandoned, not delivered: the
   ;; error records it from offset 1, and the parser still reports it active.
   (list "\"ab\x1;cd\""
         '(((error 3 3 (machine unexpected-byte "control byte in text" tctl 3 byte text 1)
                   error tctl text ()))))
   ;; the input ends inside the key loop: the feed's end delivers the run so
   ;; far, and finishing is the span's own truncation, from where that left it.
   (list "abc"
         '(((need-input 3 3 #f ready key key ((key 97 98 99)))
            (error 0 3 (machine eof "truncated" ktrunc 3 eof key 3) error ktrunc key ()))
           (key 97 98 99)))
   ;; the input ends inside the newline loop.
   (list "\n\n\n"
         '(((need-input 3 3 #f ready start #f ())
            (finished 0 3 #f finished fin #f ()))))
   ;; blanks, a number, then a byte the number's fallback refuses.
   (list "  9x"
         '(((error 3 3 (machine unexpected-byte "unexpected byte" bad 3 byte #f #f)
                   error bad #f ()))))
   ;; a key ended by a byte only its fallback takes.
   (list "ab;"
         '(((error 2 2 (machine unexpected-byte "unexpected byte" kbad 2 byte key 0)
                   error kbad key ()))))))

(harness-group "each input's whole trace is the expected one, in both lanes"
  (lambda ()
    (let ((n 0))
      (for-each
       (lambda (in)
         (set! n (+ n 1))
         (let ((feeds (list (str->bytes (car in)))))
           (harness-case (string-append "whole feed: " (adapter-value->string (car in)))
             (lambda ()
               (let ((a (run cm-ref feeds)) (b (run cm-gen feeds)))
                 (check-equal "interpreter" a (cadr in))
                 (check-equal "generated" b (cadr in)))))))
       inputs)
      (harness-case "every input ran"
        (lambda () (check-equal "inputs" n 8))))))

(harness-group "every two-way feed split agrees across lanes, and with the whole feed"
  (lambda ()
    (for-each
     (lambda (in)
       (let* ((bytes (str->bytes (car in))) (len (length bytes)))
         (harness-case (string-append "every split: " (adapter-value->string (car in)))
           (lambda ()
             (let ((whole (invariant (run cm-ref (list bytes)) bytes))
                   (disagree 'none) (moved 'none) (splits 0))
               (let loop ((k 0))
                 (when (<= k len)
                   (let* ((feeds (list (take bytes k) (drop bytes k)))
                          (a (run cm-ref feeds)) (b (run cm-gen feeds)))
                     (set! splits (+ splits 1))
                     (when (and (eq? disagree 'none) (not (equal? a b)))
                       (set! disagree (list k a b)))
                     (when (and (eq? moved 'none) (not (equal? (invariant b bytes) whole)))
                       (set! moved (list k (invariant b bytes)))))
                   (loop (+ k 1))))
               (check-equal "no split where the lanes disagree" disagree 'none)
               (check-equal "no split that moves the outcome" moved 'none)
               (check-equal "splits run" splits (+ len 1)))))))
     inputs)))

(harness-group "a byte at a time, and two parsers fed interleaved"
  (lambda ()
    (for-each
     (lambda (in)
       (let ((bytes (str->bytes (car in))))
         (harness-case (string-append "a byte at a time: " (adapter-value->string (car in)))
           (lambda ()
             (let ((a (run cm-ref (bytes-each bytes))) (b (run cm-gen (bytes-each bytes))))
               (check-equal "the lanes agree" b a)
               (check-equal "the outcome is the whole feed's"
                            (invariant b bytes) (invariant (run cm-ref (list bytes)) bytes)))))))
     inputs)
    ;; Two parsers on one compiled machine, fed a byte each in turn: neither
    ;; loop may see the other's input or position. Each parser's trace must be
    ;; the one it produces alone.
    (harness-case "two parsers fed interleaved each see only their own input"
      (lambda ()
        (define (interleaved cm x y)
          (let* ((rx (make-recorder)) (ry (make-recorder))
                 (px (make-parser cm (car rx) #f)) (py (make-parser cm (car ry) #f)))
            (define (step! p rec bytes k)
              (if (and (pair? bytes) (eq? (parser-lifecycle p) 'ready))
                  (let-values (((bv s e) (padded (list (car bytes)) k)))
                    (list (observe (parser-feed! p bv s e) p (cadr rec))))
                  '()))
            (let loop ((xs x) (ys y) (k 0) (ox '()) (oy '()))
              (if (and (null? xs) (null? ys))
                  (let ((fx (if (eq? (parser-lifecycle px) 'ready)
                                (list (observe (parser-finish! px) px (cadr rx))) '()))
                        (fy (if (eq? (parser-lifecycle py) 'ready)
                                (list (observe (parser-finish! py) py (cadr ry))) '())))
                    (list (cons (append (reverse ox) fx) ((caddr rx)))
                          (cons (append (reverse oy) fy) ((caddr ry)))))
                  (let* ((sx (step! px rx xs k)) (sy (step! py ry ys k)))
                    (loop (if (pair? xs) (cdr xs) xs) (if (pair? ys) (cdr ys) ys) (+ k 1)
                          (append (reverse sx) ox) (append (reverse sy) oy)))))))
        (let ((x (str->bytes "ab=cd\n\"hix\\\"yo\"\n123\n"))
              (y (str->bytes "\n\nxyz_9=q\n  \t#tail")))
          (for-each
           (lambda (cm label)
             (let ((both (interleaved cm x y)))
               (check-equal (string-append label ": the first parser's trace is its own")
                            (car both) (run cm (bytes-each x)))
               (check-equal (string-append label ": the second parser's trace is its own")
                            (cadr both) (run cm (bytes-each y)))))
           (list cm-ref cm-gen) '("interpreter" "generated"))
          (check-equal "the lanes agree interleaved" (interleaved cm-gen x y) (interleaved cm-ref x y)))))))

(harness-group "finish? with the input ending inside each loop"
  (lambda ()
    ;; (input . (status stream-offset error-code parked-state)) after the finish.
    (let ((cases '(("\n\n" finished 2 #f fin)
                   (" \t " finished 3 #f fin)
                   ("4096" finished 4 #f fin)
                   ("abc" error 3 eof ktrunc)
                   ("a=bc" error 4 eof vtrunc)
                   ("\"xyz" error 4 eof ttrunc)
                   ("#anything \xff;" finished 11 #f fin)))
          (n 0))
      (for-each
       (lambda (c)
         (set! n (+ n 1))
         (harness-case (string-append "finish inside a loop: " (adapter-value->string (car c)))
           (lambda ()
             (let* ((feeds (list (str->bytes (car c))))
                    (a (run cm-ref feeds)) (b (run cm-gen feeds))
                    (last (car (reverse (car b)))))
               (check-equal "the lanes agree" b a)
               (check-equal "outcome"
                            (list (list-ref last 0) (list-ref last 2)
                                  (let ((e (list-ref last 3))) (and (pair? e) (list-ref e 1)))
                                  (list-ref last 5))
                            (cdr c))))))
       cases)
      (harness-case "every finish case ran"
        (lambda () (check-equal "cases" n 7))))))

;; Each loop, entered, then fed one byte either side of each edge of its class.
;; The first prefix leaves the parser in the state with no byte of the run
;; read, so the edge byte is the state's own arm's; the second adds one class
;; byte, so the edge byte is the loop's. `num` and `key` are entered only by
;; reexecuting the byte that starts them, so their arm always reads that byte
;; and every edge byte after it is the loop's: they have the second prefix
;; only.
(define entries
  '((start "" "\n")
    (ws " " " \t")
    (num "1")
    (key "a")
    (val "a=" "a=b")
    (text "\"" "\"y")
    (comment "#" "#z")))

(define (edge-bytes runs)
  (let loop ((rs runs) (acc '()))
    (if (null? rs) (list-sort < (fold-left (lambda (a b) (if (memv b a) a (cons b a))) '() acc))
        (let ((lo (car (car rs))) (hi (cdr (car rs))))
          (loop (cdr rs)
                (append (filter (lambda (b) (and (>= b 0) (<= b 255)))
                                (list (- lo 1) lo hi (+ hi 1)))
                        acc))))))

(harness-group "the bytes either side of every class edge"
  (lambda ()
    (check-equal "every entry names a declared loop"
                 (map car entries) (map car (loop-classes)))
    (for-each
     (lambda (entry)
       (let* ((state (car entry))
              (runs (cdr (assq state (loop-classes))))
              (class (apply append (map (lambda (r) (span-bytes (car r) (cdr r))) runs))))
         (harness-case (string-append "class edges: " (symbol->string state))
           (lambda ()
             (let ((disagree 'none) (wrong 'none) (tried 0))
               (for-each
                (lambda (prefix)
                  (for-each
                   (lambda (e)
                     (set! tried (+ tried 1))
                     (let* ((bytes (append (str->bytes prefix) (list e)))
                            (a (run cm-ref (list bytes))) (b (run cm-gen (list bytes)))
                            (fed (car (car b))))
                       (when (and (eq? disagree 'none) (not (equal? a b)))
                         (set! disagree (list prefix e a b)))
                       ;; Absolute: a class byte leaves the parser parked in
                       ;; the state, the whole feed consumed; any other byte
                       ;; does not.
                       (unless (eq? (and (memv e class) #t)
                                    (and (eq? (list-ref fed 0) 'need-input)
                                         (eq? (list-ref fed 5) state)
                                         (= (list-ref fed 1) (length bytes))))
                         (when (eq? wrong 'none) (set! wrong (list prefix e fed))))))
                   (edge-bytes runs)))
                (cdr entry))
               (check-equal "no edge byte where the lanes disagree" disagree 'none)
               (check-equal "no edge byte the class misplaces" wrong 'none)
               (check-equal "edge bytes tried" tried (* (length (cdr entry)) (length (edge-bytes runs)))))))))
     entries)))

;; The callback after a loop's exit pausing, or failing. Every span here closes
;; on a byte a loop has just left on, so the first data callback is the first
;; thing after a loop exit; it answers ANSWER, and every later one continues.
;; A pause is resumed and the feed's unconsumed bytes fed again, bounded so a
;; parser that never stops pausing ends the run instead of the lane.
(define (run-answering cm bytes answer)
  (let* ((first? #t) (since '())
         (cb (lambda (span)
               (lambda (ps ux bv from to)
                 (set! since (cons (cons span (let loop ((i (- to 1)) (acc '()))
                                                (if (< i from) acc
                                                    (loop (- i 1) (cons (bytevector-u8-ref bv i) acc)))))
                                   since))
                 (if first? (begin (set! first? #f) answer) callback-continue))))
         (events (lambda () (let ((e (reverse since))) (set! since '()) e)))
         (p (make-parser cm (list (list 'on-key (cb 'key)) (list 'on-val (cb 'val))
                                  (list 'on-text (cb 'text)))
                         #f)))
    (let loop ((start 0) (k 0) (out '()))
      (let-values (((bv s e) (padded (drop bytes start) k)))
        (let* ((r (parser-feed! p bv s e)) (o (observe r p events)))
          (cond ((and (eq? (parser-result-status r) 'paused) (< k 8))
                 (parser-resume! p)
                 (loop (+ start (parser-result-consumed r)) (+ k 1) (cons o out)))
                ((eq? (parser-lifecycle p) 'ready)
                 (reverse (cons (observe (parser-finish! p) p events) (cons o out))))
                (else (reverse (cons o out)))))))))

(define refusal (make-callback-failure 'refused 'after-a-run))

;; Feed IN cut at C, with `on-val` pausing the first time; resume after a pause
;; and feed what the paused feed left. One (status offset state) per feed, then
;; the finish's status. Bounded at 12 feeds.
;; The first paused feed of a cut-and-pause trace.
(define (first-pause trace) (find (lambda (o) (and (pair? o) (eq? (car o) 'paused))) trace))
(define (cut-and-pause cm in c)
  (let* ((first? #t)
         (p (make-parser cm (list (list 'on-key (lambda (ps ux bv f to) callback-continue))
                                  (list 'on-val (lambda (ps ux bv f to)
                                                  (if first? (begin (set! first? #f) callback-pause)
                                                      callback-continue))))
                         #f)))
    (let feed ((start 0) (k 0) (out '()))
      (if (or (>= start (length in)) (> k 12))
          (reverse (cons (parser-result-status (parser-finish! p)) out))
          (let ((end (if (< start c) c (length in))))
            (let-values (((bv s e) (padded (take (drop in start) (- end start)) k)))
              (let ((r (parser-feed! p bv s e)))
                (when (eq? (parser-result-status r) 'paused) (parser-resume! p))
                (feed (+ start (parser-result-consumed r)) (+ k 1)
                      (cons (list (parser-result-status r) (parser-result-stream-offset r)
                                  (parser-state-name p))
                            out)))))))))

(harness-group "the callback after a loop exit pauses, or fails"
  (lambda ()
    (harness-case "a pause at the first span end after a loop, resumed, and the rest fed"
      (lambda ()
        (let* ((in (str->bytes "ab=cd\n\"hix\\\"yo\"\n#c!"))
               (a (run-answering cm-ref in callback-pause))
               (b (run-answering cm-gen in callback-pause)))
          (check-equal "the lanes agree" b a)
          ;; key's run leaves on `=`, which the span end reexecutes: the
          ;; pause comes back with it unconsumed and the span still open.
          (check-equal "the trace"
                       b
                       '((paused 2 2 #f paused-feed kclose key ((key 97 98)))
                         (need-input 17 19 #f ready comment #f ((val 99 100) (text 104 105 120 92 34 121 111)))
                         (finished 0 19 #f finished fin #f ()))))))
    ;; `k=abcdef\n#`: val's run is `abcdef`, bytes 2 to 7, and its loop leaves
    ;; on the newline at 8, which val's span end reexecutes. Cut the input once,
    ;; with `on-val` pausing the first time it is called, and two things can
    ;; call it first, depending on where the cut falls.
    (harness-case "a cut before the run, or after its exit: the pause is the callback after the exit"
      (lambda ()
        ;; At 1 and 2 the run has not begun when the first feed ends, and at 9
        ;; it has ended: either way the first call is the span end after the
        ;; loop's exit, at offset 8, parked in vclose.
        (let ((in (str->bytes "k=abcdef\n#")) (cuts '(1 2 9)))
          (check-equal "the lanes agree at each cut"
                       (map (lambda (c) (cut-and-pause cm-gen in c)) cuts)
                       (map (lambda (c) (cut-and-pause cm-ref in c)) cuts))
          (check-equal "where each cut's first pause lands"
                       (map (lambda (c) (first-pause (cut-and-pause cm-gen in c))) cuts)
                       '((paused 8 vclose) (paused 8 vclose) (paused 8 vclose))))))
    (harness-case "a cut inside the run: the pause is the end of the feed, with the run open"
      (lambda ()
        ;; At 3 to 8 the first feed ends inside the run. The boundary flush
        ;; delivers what the loop has read so far, and that call pauses: at the
        ;; cut, parked in val, the loop's own state.
        (let ((in (str->bytes "k=abcdef\n#")) (cuts '(3 4 5 6 7 8)))
          (check-equal "the lanes agree at each cut"
                       (map (lambda (c) (cut-and-pause cm-gen in c)) cuts)
                       (map (lambda (c) (cut-and-pause cm-ref in c)) cuts))
          (check-equal "where each cut's first pause lands"
                       (map (lambda (c) (first-pause (cut-and-pause cm-gen in c))) cuts)
                       '((paused 3 val) (paused 4 val) (paused 5 val) (paused 6 val)
                         (paused 7 val) (paused 8 val))))))
    (harness-case "a failure at the first span end after a loop"
      (lambda ()
        (let* ((in (str->bytes "\"hix\\\"yo\"\n"))
               (a (run-answering cm-ref in refusal))
               (b (run-answering cm-gen in refusal)))
          (check-equal "the lanes agree" b a)
          ;; text's run leaves on the closing quote, reexecuted into the span
          ;; end, whose data callback refuses: a callback error at that byte.
          ;; The fragment was delivered before the refusal, so the span the
          ;; error abandons begins where that fragment ended.
          (check-equal "the trace"
                       b
                       '((error 8 8 (callback refused "callback failure" tclose 8 boundary text 8)
                                error tclose text ((text 104 105 120 92 34 121 111))))))))))

(harness-group "a byte no exit clause names goes where the interpreter sends it"
  (lambda ()
    ;; Each loop, left on a byte none of its other clauses names, so the exit
    ;; dispatch's last resort decides it: the fallback for start, ws, num, key
    ;; and val, and for text, whose fallback is the loop, the class itself. The
    ;; generated run is caught in a guard, so a byte that falls off the end of
    ;; the exit's `cond` is a difference this names, not a raise out of the
    ;; case. One entry per input whose generated run is not the interpreter's.
    (harness-case "each loop's exit on a byte its clauses do not name"
      (lambda ()
        (let loop ((ins '("\n\n!" "  !" "12x" "ab;" "a=b;" "\"hi\"" "#xyz")) (wrong '()) (n 0))
          (if (null? ins)
              (begin
                (check-equal "inputs whose generated run is not the interpreter's" (reverse wrong) '())
                (check-equal "inputs tried" n 7))
              (let* ((bytes (str->bytes (car ins)))
                     (a (run cm-ref (list bytes)))
                     (b (guard (e (#t 'raised)) (run cm-gen (list bytes)))))
                (loop (cdr ins)
                      (cond ((eq? b 'raised) (cons (cons (car ins) 'raised) wrong))
                            ((equal? a b) wrong)
                            (else (cons (cons (car ins) 'differs) wrong)))
                      (+ n 1)))))))))

(harness-group "a fallback that loops on a state no byte brings back"
  (lambda ()
    ;; `s` names every byte, so the fallback that advances back to it is never
    ;; taken: its class is empty and it gets no loop, beside `w`, which loops.
    (let* ((m (make-unreachable-fallback-machine))
           (mv (verify-machine m))
           (text (guard (e (#t 'raised))
                   (render-machine (compile-machine m '()) 'deadfb-parser)))
           (gen (and (bytevector? text)
                     (let ((f (string-append tmpdir "/differential-loop-deadfb.sls")))
                       (call-with-port (open-file-output-port f (file-options no-fail))
                         (lambda (p) (put-bytevector p text)))
                       (load f)
                       (eval 'deadfb-parser (environment '(generated deadfb))))))
           (ref (make-interpreted-machine mv)))
      (harness-case "it verifies, renders, and loops only where a byte comes back"
        (lambda ()
          (check-equal "diagnostics" (map diagnostic-code (verification-diagnostics mv)) '())
          (check-equal "the machine renders" (if (bytevector? text) 'rendered text) 'rendered)
          (check-equal "states that loop, by the IR"
                       (qualifying-of (normalize-machine (verification-machine mv))) '(w))
          (check-equal "states with a loop, as rendered"
                       (if (bytevector? text)
                           (let* ((l (read (open-string-input-port (utf8->string text))))
                                  (ex (find (lambda (f) (and (pair? f) (eq? (car f) 'define)
                                                             (pair? (cadr f)) (eq? (car (cadr f)) 'exec)))
                                            (cddddr l))))
                             (filter (lambda (x) x)
                                     (map (lambda (f) (and (pair? f) (eq? (car f) 'define) (pair? (cadr f))
                                                           (prefixed-id (car (cadr f)) "%r")))
                                          (cddr ex))))
                           text)
                       '(1))))
      (harness-case "it agrees with the interpreter on every byte, and on runs"
        (lambda ()
          (let ((disagree 'none) (tried 0))
            (when gen
              (for-each
               (lambda (bytes)
                 (set! tried (+ tried 1))
                 (let ((a (run-bound ref (list bytes) #f)) (b (run-bound gen (list bytes) #f)))
                   (when (and (eq? disagree 'none) (not (equal? a b)))
                     (set! disagree (list bytes a b)))))
               (append (map list (span-bytes 0 255))
                       (map str->bytes '("abc;" "xyz" "" "a1" "hello world")))))
            (check-equal "no input where the lanes disagree" disagree 'none)
            (check-equal "inputs tried" tried 261)
            (check-equal "a run of letters, then a byte that stops"
                         (and gen (car (run-bound gen (list (str->bytes "abc;")) #f)))
                         '((stopped 4 4 #f stopped stp #f ())))))))))

(harness-finish)
