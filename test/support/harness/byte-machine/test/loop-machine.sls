;;; The run-loop proving machine: a dispatch state whose transitions advance
;;; back to the state itself renders a tight loop beside it, and this machine
;;; has one of every shape that lowering makes. Built only through
;;; (byte-machine graph).
;;;
;;; A line of the input is `key=val`, a `"text"`, a number, blanks or a `#`
;;; comment, separated by newlines:
;;;
;;;   state    loops on                                   class test
;;;   start    10 (`\n`)                                  one byte, (fx=? b 10)
;;;   ws       9, 32                                      a table: two runs
;;;   num      48-57                                      one run, two comparisons
;;;   key      48-57, 65-90, 95, 97-122                   a table: four runs
;;;   val      the same class as `key`                    `key`'s table, shared
;;;   text     its fallback, and 120 (`x`) by name        a table: every byte but
;;;                                                       0-31, 34 and 92
;;;   comment  its fallback, with no transition            no test: every byte
;;;
;;; A byte that ends a run leaves through each kind of clause: an advance to
;;; another state (`num` on `\n`, `text` on `\`), a reexecute (`key` on `=`,
;;; `val` on `\n`, `text` on `"`), an error state (`num` on `.`, by advance;
;;; `text` on a control byte, by reexecute), and the fallback (`ws` back to
;;; `start`, `num` and `key` to an error). `key`, `val` and `text` each run
;;; inside a span, so a run is open across a feed boundary whenever a feed ends
;;; in one. Every span's data callback is optional, so a parser built with no
;;; bindings runs the same states.
;;;
;;; EOF: `start`, `ws`, `num` and `comment` finish; inside a span the EOF is a
;;; truncation with that span's own error node, because a sink shared with a
;;; state outside the span joins two span states (the verifier's pass 7).
(library (byte-machine test loop-machine)
  (export make-loop-machine loop-classes make-unreachable-fallback-machine)
  (import (rnrs) (byte-machine graph))

  (define (adv t) (make-edge t 'advance))
  (define (rex t) (make-edge t 'reexecute))
  (define (on m e) (make-byte-case m e #f))
  (define (one b) (make-exact-byte-matcher b))
  (define (range lo hi) (make-byte-range-matcher lo hi))
  ;; The identifier class `key` and `val` share: digits, capitals, `_`, small
  ;; letters -- four runs, so it is a table.
  (define (ident-cases target)
    (list (on (range 48 57) (adv target))
          (on (range 65 90) (adv target))
          (on (one 95) (adv target))
          (on (range 97 122) (adv target))))

  (define (make-loop-machine)
    (make-machine 'loopm 'start
      '()
      (list (make-callback-declaration 'on-key 'span-data #f '() #f #f)
            (make-callback-declaration 'on-val 'span-data #f '() #f #f)
            (make-callback-declaration 'on-text 'span-data #f '() #f #f))
      (list (make-span-declaration 'key 'on-key #f #f)
            (make-span-declaration 'val 'on-val #f #f)
            (make-span-declaration 'text 'on-text #f #f))
      (list (make-error-declaration 'default-eof 'eof "unexpected end of input" #f)
            (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f)
            (make-error-declaration 'control 'unexpected-byte "control byte in text" #f)
            (make-error-declaration 'bad-number 'unexpected-byte "malformed number" #f)
            (make-error-declaration 'truncated 'eof "truncated" #f))
      (list
       (make-byte-dispatch-node 'start
         (list (on (one 10) (adv 'start))
               (on (one 32) (adv 'ws))
               (on (range 48 57) (rex 'num))
               (on (range 65 90) (rex 'kopen))
               (on (one 95) (rex 'kopen))
               (on (range 97 122) (rex 'kopen))
               (on (one 34) (adv 'topen))
               (on (one 35) (adv 'comment)))
         (rex 'bad) 'fin #f)
       (make-byte-dispatch-node 'ws
         (list (on (make-byte-set-matcher '(9 32)) (adv 'ws)))
         (rex 'start) 'fin #f)
       (make-byte-dispatch-node 'num
         (list (on (range 48 57) (adv 'num))
               (on (one 10) (adv 'start))
               (on (one 46) (adv 'numerr)))
         (rex 'bad) 'fin #f)
       (make-error-node 'numerr 'bad-number #f)
       (make-span-start-node 'kopen 'key 'key #f)
       (make-byte-dispatch-node 'key
         (append (ident-cases 'key) (list (on (one 61) (rex 'kclose))))
         (rex 'kbad) 'ktrunc #f)
       (make-span-end-node 'kclose 'key 'eq #f)
       (make-byte-dispatch-node 'eq
         (list (on (one 61) (adv 'vopen)))
         (rex 'bad) 'trunc #f)
       (make-span-start-node 'vopen 'val 'val #f)
       (make-byte-dispatch-node 'val
         (append (ident-cases 'val) (list (on (one 10) (rex 'vclose))))
         (rex 'vbad) 'vtrunc #f)
       (make-span-end-node 'vclose 'val 'start #f)
       (make-span-start-node 'topen 'text 'text #f)
       (make-byte-dispatch-node 'text
         (list (on (range 0 31) (rex 'tctl))
               (on (one 34) (rex 'tclose))
               (on (one 92) (adv 'tesc))
               (on (one 120) (adv 'text)))
         (adv 'text) 'ttrunc #f)
       (make-byte-dispatch-node 'tesc
         (list (on (make-byte-set-matcher '(34 92)) (adv 'text)))
         (rex 'tctl) 'ttrunc #f)
       (make-span-end-node 'tclose 'text 'tquote #f)
       (make-byte-dispatch-node 'tquote
         (list (on (one 34) (adv 'start)))
         (rex 'bad) 'trunc #f)
       (make-byte-dispatch-node 'comment '() (adv 'comment) 'fin #f)
       (make-finish-node 'fin #f)
       (make-error-node 'bad 'rejected #f)
       (make-error-node 'kbad 'rejected #f)
       (make-error-node 'vbad 'rejected #f)
       (make-error-node 'tctl 'control #f)
       (make-error-node 'ktrunc 'truncated #f)
       (make-error-node 'vtrunc 'truncated #f)
       (make-error-node 'ttrunc 'truncated #f)
       (make-error-node 'trunc 'truncated #f))
      'default-eof #f))

  ;; A fallback that advances back to its state but that no byte reaches: `s`
  ;; names all 256 bytes, so its fallback is never taken and its class is
  ;; empty. It must render no loop, beside `w`, which does loop. A letter takes
  ;; `s` to `w`, which loops on letters and reexecutes anything else back
  ;; into `s`; every other byte stops.
  (define (make-unreachable-fallback-machine)
    (make-machine 'deadfb 's '() '() '()
      (list (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
      (list
       (make-byte-dispatch-node 's
         (list (on (range 0 96) (adv 'stp))
               (on (range 97 122) (adv 'w))
               (on (range 123 255) (adv 'stp)))
         (adv 's) 'fin #f)
       (make-byte-dispatch-node 'w
         (list (on (range 97 122) (adv 'w)))
         (rex 's) 'fin #f)
       (make-stop-node 'stp #f)
       (make-finish-node 'fin #f))
      'default-eof #f))

  ;; The classes the table above declares, as (state . runs), runs ascending
  ;; (lo . hi). Written out here rather than derived from the machine, so a
  ;; lowering that derived the wrong class meets a list it did not write.
  (define (loop-classes)
    '((start (10 . 10))
      (ws (9 . 9) (32 . 32))
      (num (48 . 57))
      (key (48 . 57) (65 . 90) (95 . 95) (97 . 122))
      (val (48 . 57) (65 . 90) (95 . 95) (97 . 122))
      (text (32 . 33) (35 . 91) (93 . 255))
      (comment (0 . 255)))))
