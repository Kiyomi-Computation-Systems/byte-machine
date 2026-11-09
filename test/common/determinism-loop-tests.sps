;;; Deterministic emission over the loop machine: proved against a committed
;;; golden, and the emitted library's loops run directly. A golden of its own,
;;; on the accumulate lane's reasoning: a state that advances back to itself
;;; renders a run loop beside it and a class table at library level, and the
;;; loop machine has every shape of both -- a class of one byte, of one run,
;;; of several runs, a table two states share, a fallback that loops, and a
;;; class of every byte -- where the HTTP golden has neither of the last two.
;;; A determinism claim that excluded them would be a claim about the other
;;; machines only. The golden is also what pins the parts of a loop's text no
;;; outcome can see, such as the position kind it passes on at the end of a
;;; feed, which a dispatch state never reads.
;;;
;;; Comparison is over raw bytes through the project-owned writer, never via
;;; implementation `write`.
(import (rnrs) (rnrs eval)
        (only (chezscheme) load)
        (byte-machine test harness)
        (byte-machine test loop-machine)
        (byte-machine compile)
        (byte-machine runtime))

(harness-begin "determinism.loop")

(define ok (compile-machine (make-loop-machine) '()))

(define golden-file
  (let ((f (adapter-environment-variable "BYTE_MACHINE_LOOP_GOLDEN_FILE")))
    (if (and f (not (string=? f ""))) f
        (assertion-violation 'determinism "BYTE_MACHINE_LOOP_GOLDEN_FILE is unset" f))))

(harness-group "byte-identical emission"
  (lambda ()
    (harness-case "rendering twice in one process yields identical bytes"
      (lambda ()
        (check-equal "twice" (render-machine ok 'loopm-parser) (render-machine ok 'loopm-parser))))
    (harness-case "the emitted bytes equal the committed golden"
      (lambda ()
        (check-equal "golden" (render-machine ok 'loopm-parser)
                     (adapter-file-bytes golden-file))))))

;; THE LOOPS' SHAPES, READ BACK. Some of a loop's text no outcome can see: the
;; position kind it passes on at the end of a feed, which a dispatch state
;; never reads; whether its state enters it at the byte after the first or at
;; the first, which only costs one more turn; whether its exit keeps the
;; clauses that loop back, which no byte in the class reaches, or a fallback
;; that loops, which none reaches either. The golden pins all of it as bytes;
;; this pins each as a value of its own, so a change to one is named.
;;
;; Per loop, by state id: how its state's arm calls it (every distinct
;; argument list), the position kind it leaves with, then for a loop that tests
;; a byte the number of its exit clauses and whether they end in `else`, or
;; for one with no test whether its body steps or leaves.
(define lib (read (open-string-input-port (utf8->string (render-machine ok 'loopm-parser)))))
(define (numbered sym c)
  (let ((s (symbol->string sym)))
    (and (> (string-length s) 2) (char=? (string-ref s 0) #\%) (char=? (string-ref s 1) c)
         (string->number (substring s 2 (string-length s))))))
(define exec-forms
  (cddr (find (lambda (f) (and (pair? f) (eq? (car f) 'define) (pair? (cadr f))
                               (eq? (car (cadr f)) 'exec)))
              (cddddr lib))))
(define (defined-as c id)
  (find (lambda (f) (and (pair? f) (eq? (car f) 'define) (pair? (cadr f))
                         (eqv? (numbered (car (cadr f)) c) id)))
        exec-forms))
(define (calls-to sym x acc)
  (cond ((and (pair? x) (eq? (car x) sym)) (if (member (cdr x) acc) acc (cons (cdr x) acc)))
        ((pair? x) (calls-to sym (cdr x) (calls-to sym (car x) acc)))
        (else acc)))
(define (loop-shape id)
  (let* ((f (defined-as #\r id))
         (body (caddr (caddr f)))
         (leave (cadddr (caddr f))))
    (list id
          (reverse (calls-to (car (cadr f)) (defined-as #\s id) '()))
          (cadr (list-ref leave 4))
          (if (and (pair? body) (eq? (car body) 'let))
              (let ((clauses (cdr (caddr (cadddr (caddr body))))))
                (list (length (filter (lambda (c) (not (eq? (car c) 'else))) clauses))
                      (and (exists (lambda (c) (eq? (car c) 'else)) clauses) #t)))
              (if (eqv? (numbered (car body) #\r) id) 'step 'leave)))))
(define loop-ids
  (list-sort < (filter (lambda (x) x)
                       (map (lambda (f) (and (pair? f) (eq? (car f) 'define) (pair? (cadr f))
                                             (numbered (car (cadr f)) #\r)))
                            exec-forms))))

(harness-group "the loops' shapes, read back"
  (lambda ()
    (harness-case "each loop is entered after its first byte, leaves on a boundary, and exits by the state's other clauses"
      (lambda ()
        ;; start 0, ws 1, num 2, key 5, val 9, text 12, comment 16. Every arm
        ;; enters at the byte after the first, with the run beginning at it;
        ;; every loop leaves at the end of a feed on a boundary. The exits:
        ;; start's seven other clauses and its fallback; ws's fallback alone;
        ;; num's newline and dot and its fallback; key's `=`, val's newline,
        ;; each with its fallback; text's three clauses and no `else`, its
        ;; fallback being the loop; comment steps with no test.
        (check-equal "loop shapes (id entries leave exits)"
                     (map loop-shape loop-ids)
                     '((0 (((fx+ pos 1) pos off)) boundary (7 #t))
                       (1 (((fx+ pos 1) pos off)) boundary (0 #t))
                       (2 (((fx+ pos 1) pos off)) boundary (2 #t))
                       (5 (((fx+ pos 1) pos off)) boundary (1 #t))
                       (9 (((fx+ pos 1) pos off)) boundary (1 #t))
                       (12 (((fx+ pos 1) pos off)) boundary (3 #f))
                       (16 (((fx+ pos 1) pos off)) boundary step)))))))

(define tmpdir (or (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")
                   (assertion-violation 'determinism-loop "no tmpdir" #f)))
(define genfile (string-append tmpdir "/determinism-loop.sls"))
(call-with-port (open-file-output-port genfile (file-options no-fail))
  (lambda (p) (emit-machine ok 'loopm-parser p)))
(load genfile)
(define cm (eval 'loopm-parser (environment '(generated loopm))))

(define (str->bv s) (u8-list->bytevector (map char->integer (string->list s))))
(define (feed p s) (parser-feed! p (str->bv s) 0 (string-length s)))
(define (run-of n b) (make-string n (integer->char b)))

(harness-group "the golden output compiles and runs its loops"
  (lambda ()
    ;; Each walk drives a loop the golden's text is for, through a run long
    ;; enough that a per-byte slip would show in the offset.
    (harness-case "a key and a value, each a long run, then the newline loop"
      (lambda ()
        (let* ((p (make-parser cm '() #f))
               (r (feed p (string-append (run-of 300 97) "=" (run-of 200 66) "\n\n\n"))))
          (check-equal "need-input at the end" (parser-result-status r) 'need-input)
          (check-equal "every byte consumed" (parser-result-consumed r) 504)
          (check-equal "parked in the newline loop's state" (parser-state-name p) 'start))))
    (harness-case "a text loop that takes its fallback, its named byte and an escape"
      (lambda ()
        (let* ((p (make-parser cm '() #f))
               (r (feed p (string-append "\"" (run-of 100 120) "\\\"" (run-of 100 255) "\"#"))))
          (check-equal "need-input at the end" (parser-result-status r) 'need-input)
          (check-equal "every byte consumed" (parser-result-consumed r) 205)
          (check-equal "parked in the comment" (parser-state-name p) 'comment))))
    (harness-case "a number left by a byte its fallback refuses"
      (lambda ()
        (let* ((p (make-parser cm '() #f)) (r (feed p (string-append "  \t " (run-of 50 55) "x"))))
          (check-equal "error" (parser-result-status r) 'error)
          (check-equal "at the refused byte" (parser-error-offset (parser-result-error r)) 54)
          (check-equal "its position kind" (parser-error-position-kind (parser-result-error r)) 'byte))))
    (harness-case "a comment runs to the end of the input and finishes"
      (lambda ()
        (let* ((p (make-parser cm '() #f)))
          (feed p (string-append "#" (run-of 256 0)))
          (let ((r (parser-finish! p)))
            (check-equal "finished" (parser-result-status r) 'finished)
            (check-equal "at the end" (parser-result-stream-offset r) 257)))))))

(harness-finish)
