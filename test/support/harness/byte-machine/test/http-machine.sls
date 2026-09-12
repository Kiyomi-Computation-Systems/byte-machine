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
          http-tchar-bytes http-target-bytes http-field-value-bytes
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

  ;; field-value-byte = HTAB / SP / %x21-7E / %x80-FF (§21.2:1094). SP and HTAB
  ;; ARE value bytes, so a value span keeps its internal and trailing OWS
  ;; (§21.2:1097 — v0.1 has no trailing-marker primitive); only leading OWS,
  ;; skipped before the span opens, is excluded.
  (define http-field-value-bytes
    (append (list 9 32) (iota-range 33 126) (iota-range 128 255)))

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
           (make-callback-declaration 'version-complete 'event #f '() #f #f)
           ;; Slice ②: the header spans, headers-complete and message-complete.
           (make-callback-declaration 'header-name-data 'span-data #f '() #f #f)
           (make-callback-declaration 'header-name-complete 'span-complete #f '() #f #f)
           (make-callback-declaration 'header-value-data 'span-data #f '() #f #f)
           (make-callback-declaration 'header-value-complete 'span-complete #f '() #f #f)
           (make-callback-declaration 'headers-complete 'event #f '() #f #f)
           (make-callback-declaration 'message-complete 'event #f '() #f #f))
     (list (make-span-declaration 'method 'method-data 'method-complete #f)
           (make-span-declaration 'target 'target-data 'target-complete #f)
           (make-span-declaration 'header-name 'header-name-data 'header-name-complete #f)
           (make-span-declaration 'header-value 'header-value-data 'header-value-complete #f))
     ;; error declarations — one per §21.4 code this slice can raise; the EOF
     ;; declaration is the machine default (decision 0037).
     (list (make-error-declaration 'unexpected-eof 'unexpected-eof "unexpected end of input" #f)
           (make-error-declaration 'invalid-method 'invalid-method "method is not a token" #f)
           (make-error-declaration 'invalid-target 'invalid-target "target is not a target-byte" #f)
           (make-error-declaration 'invalid-version 'invalid-version "version is not HTTP/1.0 or HTTP/1.1" #f)
           (make-error-declaration 'invalid-line-ending 'invalid-line-ending "line ending is not CRLF" #f)
           (make-error-declaration 'invalid-header-name 'invalid-header-name "header name is not a token" #f)
           (make-error-declaration 'invalid-header-value 'invalid-header-value "header value has an invalid byte" #f))
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
                             (make-edge 'header-line-start 'advance) #f))
       (make-edge 'e-line-ending 'reexecute)  ; CR not followed by LF
       #f #f)
      ;; === Slice ②: the header section (§21.2:1069-1071) ===================
      ;; At each line start: a CR begins the empty-line terminator; a tchar
      ;; begins a header-field's name; anything else is invalid-header-name
      ;; (a field-name must begin with a tchar, and the terminating CR is the
      ;; only non-tchar permitted here). EOF here is a truncated message.
      (make-byte-dispatch-node
       'header-line-start
       (list (make-byte-case (make-exact-byte-matcher CR)
                             (make-edge 'hdrs-end-lf 'advance) #f)
             (make-byte-case (make-byte-set-matcher http-tchar-bytes)
                             (make-edge 'hn-open 'reexecute) #f))
       (make-edge 'e-hname 'reexecute)
       #f #f)
      ;; header-name span: 1*tchar, ends before the colon.
      (make-span-start-node 'hn-open 'header-name 'hn-loop #f)
      (make-byte-dispatch-node
       'hn-loop
       (list (make-byte-case (make-byte-set-matcher http-tchar-bytes)
                             (make-edge 'hn-loop 'advance) #f))
       (make-edge 'hn-close 'reexecute)
       'e-eof-hname #f)                     ; EOF with the header-name span open
      (make-span-end-node 'hn-close 'header-name 'after-hname #f)
      (make-byte-dispatch-node
       'after-hname
       (list (make-byte-case (make-exact-byte-matcher 58)   ; ":"
                             (make-edge 'ows-skip 'advance) #f))
       (make-edge 'e-hname 'reexecute)      ; a non-colon after the name
       #f #f)
      ;; Skip leading OWS after the colon BEFORE opening the value span
      ;; (§21.2:1097); a non-OWS byte reexecutes into the value span.
      (make-byte-dispatch-node
       'ows-skip
       (list (make-byte-case (make-exact-byte-matcher 32) (make-edge 'ows-skip 'advance) #f)   ; SP
             (make-byte-case (make-exact-byte-matcher 9)  (make-edge 'ows-skip 'advance) #f))  ; HTAB
       (make-edge 'hv-open 'reexecute)
       #f #f)
      ;; header-value span: *field-value-byte, ends before CR; keeps its
      ;; internal and trailing OWS. An all-OWS value opens and closes empty.
      (make-span-start-node 'hv-open 'header-value 'hv-loop #f)
      (make-byte-dispatch-node
       'hv-loop
       (list (make-byte-case (make-byte-set-matcher http-field-value-bytes)
                             (make-edge 'hv-loop 'advance) #f))
       (make-edge 'hv-close 'reexecute)
       'e-eof-hvalue #f)                    ; EOF with the header-value span open
      (make-span-end-node 'hv-close 'header-value 'hv-cr #f)
      (make-byte-dispatch-node
       'hv-cr
       (list (make-byte-case (make-exact-byte-matcher CR) (make-edge 'hv-lf 'advance) #f))
       (make-edge 'e-hvalue 'reexecute)     ; a non-fvb, non-CR after the value
       #f #f)
      (make-byte-dispatch-node
       'hv-lf
       (list (make-byte-case (make-exact-byte-matcher LF)
                             (make-edge 'header-line-start 'advance) #f))
       (make-edge 'e-line-ending 'reexecute)  ; CR not followed by LF
       #f #f)
      ;; the empty line's LF, then headers-complete (§21.3:1144, after the CRLF).
      (make-byte-dispatch-node
       'hdrs-end-lf
       (list (make-byte-case (make-exact-byte-matcher LF)
                             (make-edge 'hdrs-complete 'advance) #f))
       (make-edge 'e-line-ending 'reexecute)  ; the empty line's CR not followed by LF
       #f #f)
      (make-callback-node 'hdrs-complete 'headers-complete 'msg-complete '() 'msg-complete #f)
      ;; No body until Slice ③: message-complete fires for the empty body, then
      ;; the loop returns to idle (§21.3:1150). No fields yet, so no clear chain
      ;; (Slice ③ adds Content-Length and the clear that resets it).
      (make-callback-node 'msg-complete 'message-complete 'idle '() 'idle #f)
      (make-finish-node 'fin #f)
      ;; --- error nodes, per span state (decision 0036) --------------------
      (make-error-node 'e-eof-method 'unexpected-eof #f)   ; method span open
      (make-error-node 'e-eof-target 'unexpected-eof #f)   ; target span open
      (make-error-node 'e-eof-hname 'unexpected-eof #f)    ; header-name span open
      (make-error-node 'e-eof-hvalue 'unexpected-eof #f)   ; header-value span open
      (make-error-node 'e-method 'invalid-method #f)       ; no span open
      (make-error-node 'e-target 'invalid-target #f)       ; no span open
      (make-error-node 'e-version 'invalid-version #f)     ; no span open
      (make-error-node 'e-line-ending 'invalid-line-ending #f)
      (make-error-node 'e-hname 'invalid-header-name #f)   ; no span open
      (make-error-node 'e-hvalue 'invalid-header-value #f))  ; no span open
     'unexpected-eof #f)))                 ; machine default EOF (no span)
