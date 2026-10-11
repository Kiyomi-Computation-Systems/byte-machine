#!r6rs
;;; The machine the documentation builds: lowercase words separated by
;;; spaces, ended by a newline. Each word is a span, so its bytes reach the
;;; `on-word` callback as they arrive, however the input is split.
(library (words)
  (export words)
  (import (rnrs) (byte-machine graph))

  (define (byte c) (char->integer c))
  (define is-letter (make-byte-range-matcher (byte #\a) (byte #\z)))
  (define is-space (make-exact-byte-matcher (byte #\space)))
  (define is-newline (make-exact-byte-matcher (byte #\newline)))

  (define words
    (make-machine 'words 'between
      '()                                       ; no fields
      (list (make-callback-declaration 'on-word 'span-data #t '() #f #f)
            (make-callback-declaration 'on-word-end 'span-complete #t '() #f #f))
      (list (make-span-declaration 'word 'on-word 'on-word-end #f))
      (list (make-error-declaration 'bad 'unexpected-byte
              "expected a letter, a space or a newline" #f)
            (make-error-declaration 'eof 'unexpected-eof
              "input ended before the newline" #f))
      (list
       ;; Between words: a letter starts a word, a space is skipped, and a
       ;; newline ends the line.
       (make-byte-dispatch-node 'between
         (list (make-byte-case is-letter (make-edge 'open 'reexecute) #f)
               (make-byte-case is-space (make-edge 'between 'advance) #f)
               (make-byte-case is-newline (make-edge 'done 'advance) #f))
         (make-edge 'reject 'reexecute) #f #f)
       (make-span-start-node 'open 'word 'in-word #f)
       ;; Inside a word: a letter extends it, anything else ends it.
       (make-byte-dispatch-node 'in-word
         (list (make-byte-case is-letter (make-edge 'in-word 'advance) #f))
         (make-edge 'close 'reexecute) #f #f)
       (make-span-end-node 'close 'word 'after-word #f)
       ;; After a word: a space or a newline, and nothing else.
       (make-byte-dispatch-node 'after-word
         (list (make-byte-case is-space (make-edge 'between 'advance) #f)
               (make-byte-case is-newline (make-edge 'done 'advance) #f))
         (make-edge 'reject 'reexecute) #f #f)
       (make-stop-node 'done #f)
       (make-error-node 'reject 'bad #f))
      'eof #f)))
