;;; The HTTP fixture stays private and no HTTP API leaks into a public library.
;;; Read from the tree as data (the diagnostic-census technique), not asserted
;;; in prose: it fails if a change imports the fixture into `src/`, re-exports
;;; an HTTP name from a public library, or names a fixture library outside
;;; `(byte-machine test …)`.
(import (rnrs)
        (byte-machine test harness))

(harness-begin "unit.http-leak")

(define source-root
  (let ((r (adapter-environment-variable "BYTE_MACHINE_SOURCE_ROOT")))
    (if (and r (not (string=? r ""))) r
        (assertion-violation 'http-leak "BYTE_MACHINE_SOURCE_ROOT is unset" r))))
(define harness-root
  (let ((r (adapter-environment-variable "BYTE_MACHINE_HARNESS_ROOT")))
    (if (and r (not (string=? r ""))) r
        (assertion-violation 'http-leak "BYTE_MACHINE_HARNESS_ROOT is unset" r))))

;; A .sls file is exactly one library datum; the guard asserts nothing follows it.
(define (read-library path)
  (call-with-input-file path
    (lambda (p) (let* ((d (read p)) (clean (eof-object? (read p)))) (cons d clean)))))
(define (lib-name d) (cadr d))            ; (library <name> (export …) (import …) …)
(define (lib-exports d) (cdr (caddr d)))  ; the exported identifiers
(define (lib-imports d) (cdr (cadddr d))) ; the import specs

;; Flatten an import spec to the library-reference symbols it names, so
;; `(only (byte-machine runtime) x)` and a bare `(rnrs)` both reduce to symbols.
(define (spec-symbols x)
  (cond ((symbol? x) (list x))
        ((pair? x) (append (spec-symbols (car x)) (spec-symbols (cdr x))))
        (else '())))

;; HTTP vocabulary that must never appear in a PUBLIC export or a public library
;; name. Substring match on the identifier's spelling.
(define http-words
  '("http" "chunk" "trailer" "content-length" "transfer-encoding" "header"
    "message-begin" "message-complete" "request" "framing"))
(define (has-http-word? sym)
  (let ((s (symbol->string sym)))
    (exists (lambda (w) (harness-string-contains? s w)) http-words)))

(define public-src-libs
  (map (lambda (n) (string-append source-root "/byte-machine/" n ".sls"))
       '("graph" "verify" "compile" "interpret" "runtime")))
(define private-src-libs
  (map (lambda (n) (string-append source-root "/byte-machine/private/" n ".sls"))
       '("ir" "normal-ir" "names")))
(define fixture-libs
  (map (lambda (n) (string-append harness-root "/byte-machine/test/" n ".sls"))
       '("http-machine" "http-event-order" "http-error-table")))

(define (imports-the-fixture? d)
  ;; any import spec that references `(byte-machine test …)`.
  (exists (lambda (spec)
            (let ((syms (spec-symbols spec)))
              (and (memq 'byte-machine syms) (memq 'test syms) #t)))
          (lib-imports d)))

(harness-group "no src/ library imports the fixture or any test library"
  (lambda ()
    (for-each
     (lambda (path)
       (let ((rl (read-library path)))
         (harness-case path
           (lambda ()
             (check "the .sls is a single library datum" (cdr rl))
             (check "does not import (byte-machine test …)"
                    (not (imports-the-fixture? (car rl))))))))
     (append public-src-libs private-src-libs))))

(harness-group "no PUBLIC library re-exports an HTTP name"
  (lambda ()
    (for-each
     (lambda (path)
       (let* ((d (car (read-library path)))
              (leaked (filter has-http-word? (lib-exports d))))
         (harness-case path
           (lambda ()
             (check-equal "no HTTP-vocabulary export" leaked '())))))
     public-src-libs)))

(harness-group "the fixture libraries live under (byte-machine test …), never (byte-machine http-…)"
  (lambda ()
    (for-each
     (lambda (path)
       (let* ((d (car (read-library path))) (name (lib-name d)))
         (harness-case path
           (lambda ()
             (check-equal "named (byte-machine test <x>)"
                          (list (car name) (cadr name)) '(byte-machine test))
             ;; the HTTP vocabulary is confined to the third segment onward,
             ;; never the (byte-machine …) prefix a public importer would use.
             (check "carries no HTTP word into the (byte-machine test …) prefix"
                    (not (or (has-http-word? (car name)) (has-http-word? (cadr name)))))))))
     fixture-libs)))

(harness-finish)
