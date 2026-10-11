;;; The benchmark runner's smoke lane: the verdicts.
;;;
;;; test/common/bench-runner-smoke.cmake runs the command
;;; bench/runner/benchmark.sps records as its artefact's `exact-command`, at one
;;; round of one iteration, and leaves what happened in
;;; BYTE_MACHINE_BENCH_SMOKE_DIR: ran.txt (the command, one token per line),
;;; status.txt (its exit status, or why it was not run) and artefact.sls. This
;;; program checks that:
;;;
;;; - the runner records one command, and the driver ran exactly that command,
;;;   with only the executable and the object guard replaced;
;;; - the command, run as written from the tree root, exits 0;
;;; - the artefact is one datum, carries every field the committed baseline
;;;   carries, ran both executors, has as many workloads as the baseline, and
;;;   every row carries every metric the artefact itself names as required;
;;; - every documented copy of the command is the recorded one: the runner's
;;;   own header always, and every copy under docs/, .reference/ and README.org
;;;   when BYTE_MACHINE_REPO_ROOT is set. The ctest registration sets it and the
;;;   mutation suite does not, because its stage holds no documentation.
;;;
;;; The artefact is held to the committed baseline's shape rather than to a list
;;; of its own: release-ledger-tests.sps already pins the baseline's fields and
;;; workload count, so a second copy of either here would be one more place for
;;; them to drift. Values are not compared -- one iteration measures nothing.
(import (rnrs)
        (only (chezscheme) directory-list file-directory?)
        (byte-machine test harness))

(harness-begin "example.bench-runner")

(define (env name)
  (let ((v (adapter-environment-variable name)))
    (if (and v (not (string=? v ""))) v
        (assertion-violation 'bench-runner-smoke (string-append name " is unset") v))))
(define tree (env "BYTE_MACHINE_BENCH_TREE"))
(define work (env "BYTE_MACHINE_BENCH_SMOKE_DIR"))
(define chez (env "BYTE_MACHINE_CHEZ_EXECUTABLE"))
(define repo (let ((v (adapter-environment-variable "BYTE_MACHINE_REPO_ROOT")))
               (and v (not (string=? v "")) v)))
(define guard-dir (string-append work "/guard"))

;; --- text helpers -----------------------------------------------------------
(define (file-string path)
  (let ((bv (adapter-file-bytes path)))
    (let loop ((i (- (bytevector-length bv) 1)) (acc '()))
      (if (< i 0) (list->string acc)
          (loop (- i 1) (cons (integer->char (bytevector-u8-ref bv i)) acc))))))
(define (starts-with? s p)
  (and (>= (string-length s) (string-length p))
       (string=? (substring s 0 (string-length p)) p)))
(define (ends-with? s p)
  (let ((n (string-length s)) (k (string-length p)))
    (and (>= n k) (string=? (substring s (- n k) n) p))))
(define (blank? c) (memv c '(#\space #\tab #\return)))
(define (trim s)
  (let* ((n (string-length s))
         (a (let loop ((i 0)) (if (and (< i n) (blank? (string-ref s i))) (loop (+ i 1)) i)))
         (b (let loop ((j n)) (if (and (> j a) (blank? (string-ref s (- j 1)))) (loop (- j 1)) j))))
    (substring s a b)))
(define (tokens s)
  (filter (lambda (t) (not (string=? t "")))
          (harness-split (list->string (map (lambda (c) (if (blank? c) #\space c))
                                            (string->list s)))
                         #\space)))
(define (read-all path)
  (call-with-input-file path
    (lambda (p)
      (let loop ((acc '()))
        (let ((d (read p)))
          (if (eof-object? d) (reverse acc) (loop (cons d acc))))))))
(define (field alist key) (let ((e (assq key alist))) (and e (cadr e))))
(define (sorted-symbols xs)
  (list-sort (lambda (a b) (string<? (symbol->string a) (symbol->string b))) xs))

;; --- the recorded command ---------------------------------------------------
;; Every `(list 'exact-command <x>)` in the runner, read as data.
(define (recorded-commands forms)
  (let walk ((x forms) (acc '()))
    (cond ((and (pair? x) (eq? (car x) 'list) (list? x) (= (length x) 3)
                (equal? (cadr x) ''exact-command))
           (cons (caddr x) acc))
          ((pair? x) (walk (cdr x) (walk (car x) acc)))
          (else acc))))
(define runner-path (string-append tree "/bench/runner/benchmark.sps"))
(define recorded (recorded-commands (read-all runner-path)))
(define literal
  (if (and (= (length recorded) 1) (string? (car recorded))) (car recorded) ""))

;; A command as a reader sees it, with the two tokens the driver replaces by
;; design shown as placeholders: the executable, when it is `executable`, and
;; the object guard's value, when `guard-value?` accepts it.
(define (masked toks executable guard-value?)
  (let loop ((ts toks) (i 0) (previous #f) (acc '()))
    (if (null? ts)
        (harness-join (reverse acc) " ")
        (let ((t (car ts)))
          (loop (cdr ts) (+ i 1) t
                (cons (cond ((and (= i 0) (string=? t executable)) "<chez>")
                            ((and previous (string=? previous "--object-guard")
                                  (guard-value? t))
                             "<guard>")
                            (else t))
                      acc))))))

(define ran (filter (lambda (t) (not (string=? t "")))
                    (harness-split (file-string (string-append work "/ran.txt")) #\newline)))
(define status
  (let ((s (file-string (string-append work "/status.txt"))))
    (or (string->number s) s)))

;; --- documented copies ------------------------------------------------------
;; Every command block in `text` that starts at a line reading `chez --script`
;; (after a leading `;;;`, for the runner's own header) and continues while a
;; line ends in a backslash, kept when it names the runner. Returned as
;; space-joined token strings.
(define (documented-commands text)
  (define (line-text l) (trim (if (starts-with? l ";;;") (substring l 3 (string-length l)) l)))
  (let loop ((ls (harness-split text #\newline)) (acc '()))
    (cond ((null? ls) (reverse acc))
          ((starts-with? (line-text (car ls)) "chez --script")
           (let collect ((ls ls) (toks '()))
             (let* ((l (line-text (car ls)))
                    (more? (ends-with? l "\\"))
                    (toks (append toks (tokens (if more?
                                                   (substring l 0 (- (string-length l) 1))
                                                   l)))))
               (if (and more? (pair? (cdr ls)))
                   (collect (cdr ls) toks)
                   (loop (cdr ls)
                         (if (exists (lambda (t) (ends-with? t "bench/runner/benchmark.sps")) toks)
                             (cons (harness-join toks " ") acc)
                             acc))))))
          (else (loop (cdr ls) acc)))))

(define (doc-files dir)
  (if (file-directory? dir)
      (apply append
             (map (lambda (name)
                    (let ((path (string-append dir "/" name)))
                      (cond ((file-directory? path) (doc-files path))
                            ((or (ends-with? name ".md") (ends-with? name ".org")) (list path))
                            (else '()))))
                  (list-sort string<? (directory-list dir))))
      '()))

;; --- the run's artefact -----------------------------------------------------
(define artefact-path (string-append work "/artefact.sls"))
(define artefact-forms
  (and (file-exists? artefact-path)
       (guard (e (#t #f)) (read-all artefact-path))))
(define artefact
  (and (eqv? status 0) artefact-forms (= (length artefact-forms) 1) (car artefact-forms)))
(define baseline
  (car (read-all (string-append tree "/bench/fixtures/baseline-tarm64osx.sls"))))

(harness-group "the recorded command"
  (lambda ()
    (harness-case "the runner records one command"
      (lambda ()
        (check-equal "exact-command strings in the runner" (length recorded) 1)))
    (harness-case "the driver ran the recorded command"
      (lambda ()
        (check-equal "the command run, executable and object guard masked"
                     (masked ran chez (lambda (t) (string=? t guard-dir)))
                     (masked (tokens literal) "chez" (lambda (t) #t)))))
    (harness-case "the recorded command run as written exits 0"
      (lambda ()
        (check-equal "exit status" status 0)))
    (harness-case "the runner's header documents the recorded command"
      (lambda ()
        (let ((copies (documented-commands (file-string runner-path))))
          (check-equal "header copies" (length copies) 1)
          (for-each (lambda (c) (check-equal "header copy" c literal)) copies))))))

(harness-group "the artefact a run writes"
  (lambda ()
    (harness-case "a run that exits 0 writes one artefact datum"
      (lambda ()
        (if (eqv? status 0)
            (begin
              (check "the artefact exists" (file-exists? artefact-path))
              (when (file-exists? artefact-path)
                (check-equal "artefact datums" (if artefact-forms (length artefact-forms) 'unreadable) 1)))
            (check-fail "no artefact to check" "the recorded command did not exit 0"))))
    (when artefact
      (harness-case "the artefact carries every field the committed baseline carries"
        (lambda ()
          (let ((fresh (map car artefact)) (recorded-fields (map car baseline)))
            (check "the committed baseline has fields" (pair? recorded-fields))
            (check-equal "fields missing from the run"
                         (filter (lambda (k) (not (memq k fresh))) recorded-fields)
                         '()))))
      (harness-case "the artefact ran both executors"
        (lambda ()
          (check-equal "executors" (field artefact 'executors) 'both)))
      (harness-case "the artefact has as many workloads as the committed baseline"
        (lambda ()
          (let ((recorded-workloads (field baseline 'workloads)))
            (check "the committed baseline has workloads" (pair? recorded-workloads))
            (check-equal "workloads"
                         (length (field artefact 'workloads))
                         (length recorded-workloads)))))
      (harness-case "every workload row carries every required metric"
        (lambda ()
          (let* ((required (field artefact 'required-metrics))
                 (one-time (map car (field artefact 'one-time-metrics)))
                 (missing
                  (fold-left
                   (lambda (acc w)
                     (fold-left
                      (lambda (acc executor)
                        (let* ((row (field w executor))
                               (have (append one-time (if (list? row) (map car row) '()))))
                          (fold-left (lambda (acc m)
                                       (if (or (memq m have) (memq m acc)) acc (cons m acc)))
                                     acc required)))
                      acc '(generated interpreted)))
                   '() (field artefact 'workloads))))
            (check "the artefact names required metrics" (pair? required))
            (check-equal "required metrics missing from a row" (sorted-symbols missing) '())))))))

(when repo
  (harness-group "the documented copies"
    (lambda ()
      (let* ((files (append (doc-files (string-append repo "/docs"))
                            (doc-files (string-append repo "/.reference"))
                            (let ((r (string-append repo "/README.org")))
                              (if (file-exists? r) (list r) '()))))
             (relative (lambda (path) (substring path (+ (string-length repo) 1)
                                                 (string-length path))))
             (copies (map (lambda (f) (cons (relative f) (documented-commands (file-string f))))
                          files))
             (with-copy (map car (filter (lambda (c) (pair? (cdr c))) copies))))
        (harness-case "every documented copy is the recorded command"
          (lambda ()
            (check-equal "pages whose copy differs"
                         (map car (filter (lambda (c)
                                            (exists (lambda (d) (not (string=? d literal))) (cdr c)))
                                          copies))
                         '())))
        (harness-case "the pages known to document the command still carry it"
          (lambda ()
            (check-equal "known pages without a copy"
                         (filter (lambda (p) (not (member p with-copy)))
                                 '("docs/building.md"
                                   ".reference/benchmark-methodology-and-baseline.md"))
                         '())))))))

(harness-finish)
