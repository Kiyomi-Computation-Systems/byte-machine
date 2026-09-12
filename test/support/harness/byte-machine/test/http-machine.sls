;;; The private HTTP request fixture (§21), grown one slice at a time and built
;;; ONLY through (byte-machine graph) — §21.5:1181 forbids private constructors,
;;; and §21.5:1189 forbids a callback that parses. Every accept/reject choice is
;;; a declared graph node; the callbacks below only record.
;;;
;;; MILESTONE 8 SLICE ①: the request line — `method SP request-target SP version
;;; CRLF` (§21.2:1063-1065). Later slices extend this same machine: Slice ②
;;; replaces the `reqline-done` stop with the header section and the message
;;; loop; ③ adds framing recognition and the fixed body; ④ the chunked body; ⑤
;;; conflicts, pipelining and the close. Nothing in `src/` changes (§4.7).
;;;
;;; THE SHAPE, and why each turn is what it is:
;;;
;;;  * `idle` is a byte dispatch, not a callback node (decision 0037). Its one
;;;    case matches a `tchar` and REEXECUTES into `message-begin`, so the first
;;;    method byte is available but unconsumed when the event fires (§21.3:1139);
;;;    its eof-target is the finish, so clean EOF between messages is `finished`;
;;;    its fallback rejects `invalid-method`. This one node also enforces
;;;    `method = 1*tchar`'s "1*": the method span opens only after a tchar is
;;;    seen, so an empty method is `invalid-method` here, before any span.
;;;
;;;  * A span ends BEFORE its delimiter SP is consumed (§21.3:1140). `method-loop`
;;;    consumes tchars; the first non-tchar REEXECUTES into `method-close`
;;;    (span-end, no consume), then `after-method` reads that same byte — SP
;;;    advances into the target, anything else is `invalid-method` at that byte,
;;;    now with no span open. The target is the same shape behind a `target-gate`
;;;    that enforces `1*target-byte`.
;;;
;;;  * The version is a two-alternative sequence (http-version-machine.sls's
;;;    production, lifted in): both alternatives reach `version-complete`, whose
;;;    event fires before the CRLF. The CRLF is strict — a bare CR or bare LF is
;;;    `invalid-line-ending` (§21.2's `CRLF = %x0D %x0A`).
;;;
;;;  * ERROR NODES ARE PER SPAN STATE, NOT PER CODE (decision 0036). EOF while a
;;;    span is open needs its own node (`e-eof-method`, `e-eof-target`), distinct
;;;    from the no-span EOF the machine default raises, because pass 7's flat
;;;    lattice (decision 0029) refuses one node reached with two span states.
;;;    `invalid-method` and `invalid-line-ending` are each reached only with no
;;;    span open, so each is one node; all three EOF paths name one
;;;    `unexpected-eof` declaration.
(library (byte-machine test http-machine)
  (export make-http-machine
          http-tchar-bytes http-target-bytes
          http-request-line-bytes)
  (import (rnrs) (byte-machine graph))

  (define (iota-range lo hi)
    (let loop ((i hi) (acc '()))
      (if (< i lo) acc (loop (- i 1) (cons i acc)))))

  (define (string-bytes s) (map char->integer (string->list s)))

  ;; tchar = ALPHA / DIGIT / "!" "#" "$" "%" "&" "'" "*" "+" "-" "." "^" "_"
  ;;         "`" "|" "~"  (§21.2:1088-1090).
  (define http-tchar-bytes
    (append '(33 35 36 37 38 39 42 43 45 46 94 95 96 124 126)   ; the symbols
            (iota-range 48 57)     ; DIGIT
            (iota-range 65 90)     ; A-Z
            (iota-range 97 122)))  ; a-z

  ;; target-byte = %x21-7E (§21.2:1092): every printable ASCII, SP excluded.
  (define http-target-bytes (iota-range 33 126))

  ;; A canonical, well-formed request line, for the lanes to split and drive.
  (define (http-request-line-bytes)
    (string-bytes "GET /index HTTP/1.1\r\n"))

  (define SP 32)
  (define CR 13)
  (define LF 10)

  (define (make-http-machine)
    (make-machine
     'httpreq 'idle
     '()                                 ; fields — none until Slice ③
     ;; callbacks: the events and the two request-line span pairs (§21.3).
     (list (make-callback-declaration 'message-begin 'event #f '() #f #f)
           (make-callback-declaration 'method-data 'span-data #f '() #f #f)
           (make-callback-declaration 'method-complete 'span-complete #f '() #f #f)
           (make-callback-declaration 'target-data 'span-data #f '() #f #f)
           (make-callback-declaration 'target-complete 'span-complete #f '() #f #f)
           (make-callback-declaration 'version-complete 'event #f '() #f #f))
     (list (make-span-declaration 'method 'method-data 'method-complete #f)
           (make-span-declaration 'target 'target-data 'target-complete #f))
     ;; error declarations — one per §21.4 code this slice can raise; the EOF
     ;; declaration is the machine default (decision 0037).
     (list (make-error-declaration 'unexpected-eof 'unexpected-eof "unexpected end of input" #f)
           (make-error-declaration 'invalid-method 'invalid-method "method is not a token" #f)
           (make-error-declaration 'invalid-target 'invalid-target "target is not a target-byte" #f)
           (make-error-declaration 'invalid-version 'invalid-version "version is not HTTP/1.0 or HTTP/1.1" #f)
           (make-error-declaration 'invalid-line-ending 'invalid-line-ending "line ending is not CRLF" #f))
     (list
      ;; --- idle: the message-begin gate (decision 0037) -------------------
      (make-byte-dispatch-node
       'idle
       (list (make-byte-case (make-byte-set-matcher http-tchar-bytes)
                             (make-edge 'msg-begin 'reexecute) #f))
       (make-edge 'e-method 'reexecute)   ; not a tchar → empty/invalid method
       'fin #f)                           ; clean EOF while idle → finished
      (make-callback-node 'msg-begin 'message-begin 'method-open '() 'method-open #f)
      ;; --- method span ----------------------------------------------------
      (make-span-start-node 'method-open 'method 'method-loop #f)
      (make-byte-dispatch-node
       'method-loop
       (list (make-byte-case (make-byte-set-matcher http-tchar-bytes)
                             (make-edge 'method-loop 'advance) #f))
       (make-edge 'method-close 'reexecute)   ; non-tchar ends the token
       'e-eof-method #f)                       ; EOF with the method span open
      (make-span-end-node 'method-close 'method 'after-method #f)
      (make-byte-dispatch-node
       'after-method
       (list (make-byte-case (make-exact-byte-matcher SP)
                             (make-edge 'target-gate 'advance) #f))
       (make-edge 'e-method 'reexecute)   ; a non-SP after the method
       #f #f)                             ; EOF here → machine default unexpected-eof
      ;; --- target span (behind a 1*target-byte gate) ----------------------
      (make-byte-dispatch-node
       'target-gate
       (list (make-byte-case (make-byte-range-matcher 33 126)
                             (make-edge 'target-open 'reexecute) #f))
       (make-edge 'e-target 'reexecute)   ; empty target
       #f #f)
      (make-span-start-node 'target-open 'target 'target-loop #f)
      (make-byte-dispatch-node
       'target-loop
       (list (make-byte-case (make-byte-range-matcher 33 126)
                             (make-edge 'target-loop 'advance) #f))
       (make-edge 'target-close 'reexecute)
       'e-eof-target #f)                   ; EOF with the target span open
      (make-span-end-node 'target-close 'target 'after-target #f)
      (make-byte-dispatch-node
       'after-target
       (list (make-byte-case (make-exact-byte-matcher SP)
                             (make-edge 'ver 'advance) #f))
       (make-edge 'e-target 'reexecute)   ; a non-SP after the target
       #f #f)
      ;; --- version, then version-complete (before the CRLF) ---------------
      (make-sequence-dispatch-node
       'ver
       (list (make-sequence-case (string-bytes "HTTP/1.0") 'ver-ok #f)
             (make-sequence-case (string-bytes "HTTP/1.1") 'ver-ok #f))
       (make-edge 'e-version 'reexecute)  ; first mismatch byte, unconsumed
       #f #f)
      (make-callback-node 'ver-ok 'version-complete 'crlf-cr '() 'crlf-cr #f)
      ;; --- strict request-line CRLF ---------------------------------------
      (make-byte-dispatch-node
       'crlf-cr
       (list (make-byte-case (make-exact-byte-matcher CR)
                             (make-edge 'crlf-lf 'advance) #f))
       (make-edge 'e-line-ending 'reexecute)  ; bare LF or other → not CRLF
       #f #f)
      (make-byte-dispatch-node
       'crlf-lf
       (list (make-byte-case (make-exact-byte-matcher LF)
                             (make-edge 'reqline-done 'advance) #f))
       (make-edge 'e-line-ending 'reexecute)  ; CR not followed by LF
       #f #f)
      ;; Slice ② replaces this stop with the header section entry.
      (make-stop-node 'reqline-done #f)
      (make-finish-node 'fin #f)
      ;; --- error nodes, per span state (decision 0036) --------------------
      (make-error-node 'e-eof-method 'unexpected-eof #f)   ; method span open
      (make-error-node 'e-eof-target 'unexpected-eof #f)   ; target span open
      (make-error-node 'e-method 'invalid-method #f)       ; no span open
      (make-error-node 'e-target 'invalid-target #f)       ; no span open
      (make-error-node 'e-version 'invalid-version #f)     ; no span open
      (make-error-node 'e-line-ending 'invalid-line-ending #f))
     'unexpected-eof #f)))                 ; machine default EOF (no span)
