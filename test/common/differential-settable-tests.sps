;;; interpreter ≡ generated over the settable-mode proving machine (Milestone 13,
;;; decision 0047). Two parsers built from ONE compiled machine start in two modes
;;; through the make-parser initial-values argument; both executors must agree on
;;; the fork, the mode must survive parser-reset!, and an illegal override must be
;;; refused identically. A disagreement here is a real defect in the settable
;;; seam: the ABI payload's fourth member (the settable table), the runtime's
;;; override validation, or the reset-survival slot.
(import (rnrs) (rnrs eval) (only (chezscheme) load)
        (byte-machine test harness)
        (byte-machine test settable-machine)
        (byte-machine graph)
        (byte-machine verify) (byte-machine interpret)
        (byte-machine runtime) (byte-machine compile))

(harness-begin "differential.settable")

(define tmpdir (or (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")
                   (assertion-violation 'differential-settable "no tmpdir" #f)))
(define genfile (string-append tmpdir "/generated-settable.sls"))
(define m (make-settable-machine))
(define cm-ref (make-interpreted-machine (verify-machine m)))
(call-with-port (open-file-output-port genfile (file-options no-fail))
  (lambda (p) (emit-machine (compile-machine m '()) 'settable-parser p)))
(load genfile)
(define cm-gen (eval 'settable-parser (environment '(generated settable))))

;; The observable tuple: status, offsets, and the mode field read back -- so a
;; lost or mis-applied override shows as a disagreement in the field value even
;; when the status happens to match.
(define (rfields r p)
  (list (parser-result-status r) (parser-result-next r) (parser-result-consumed r)
        (parser-result-stream-offset r) (parser-field-ref p 'mode)))

(define (feed-both inits byte)
  ;; Build one parser per lane with the same overrides, feed one byte, return
  ;; both observable tuples for comparison.
  (let ((pr (make-parser cm-ref '() #f inits))
        (pg (make-parser cm-gen '() #f inits)))
    (values (rfields (parser-feed! pr (u8-list->bytevector (list byte)) 0 1) pr)
            (rfields (parser-feed! pg (u8-list->bytevector (list byte)) 0 1) pg))))

(harness-group "two parsers from one machine start in two modes, and the lanes agree"
  (lambda ()
    (define (case* label inits byte)
      (harness-case label
        (lambda ()
          (let-values (((ref gen) (feed-both inits byte)))
            (check-equal (string-append label " interp==gen") ref gen)))))
    ;; mode override 1 -> the request arm: 'R' stops, 'S' errors.
    (case* "override mode=1 fed R (request arm accepts)" (list (cons 'mode 1)) #x52)
    (case* "override mode=1 fed S (request arm rejects)"  (list (cons 'mode 1)) #x53)
    ;; no override -> declared mode 0 -> the response arm: 'S' stops, 'R' errors.
    (case* "default mode fed S (response arm accepts)" '() #x53)
    (case* "default mode fed R (response arm rejects)" '() #x52)))

(harness-group "the embedder's mode survives parser-reset! in both lanes"
  (lambda ()
    (define (survives label cm)
      (harness-case label
        (lambda ()
          (let ((p (make-parser cm '() #f (list (cons 'mode 1)))))
            (check-equal "mode set at construction" (parser-field-ref p 'mode) 1)
            (parser-feed! p (u8-list->bytevector (list #x52)) 0 1)
            (parser-reset! p)
            ;; reset restores the EMBEDDER's initial (1), NOT the declared 0.
            (check-equal "mode after reset is the embedder's, not the declared"
                         (parser-field-ref p 'mode) 1)
            (check-equal "and the request arm still accepts after reset"
                         (parser-result-status (parser-feed! p (u8-list->bytevector (list #x52)) 0 1))
                         'stopped)))))
    (survives "interpreter" cm-ref)
    (survives "generated" cm-gen)))

(harness-group "an illegal override is refused identically in both lanes"
  (lambda ()
    (define (raises? thunk) (guard (e (#t #t)) (thunk) #f))
    (define (refused label inits)
      (harness-case label
        (lambda ()
          (check "interpreter refuses" (raises? (lambda () (make-parser cm-ref '() #f inits))))
          (check "generated refuses"   (raises? (lambda () (make-parser cm-gen '() #f inits)))))))
    (refused "an unknown field name" (list (cons 'nonesuch 1)))
    (refused "a value outside the field width" (list (cons 'mode 999)))
    (refused "a duplicate override of one field" (list (cons 'mode 1) (cons 'mode 0)))
    ;; A well-formed override still applies: the refusals above are the only ones.
    (harness-case "a legal override is accepted"
      (lambda ()
        (check "interpreter accepts" (parser? (make-parser cm-ref '() #f (list (cons 'mode 1)))))
        (check "generated accepts"   (parser? (make-parser cm-gen '() #f (list (cons 'mode 1)))))))))

(harness-finish)
