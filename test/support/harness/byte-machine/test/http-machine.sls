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

  ;; --- Slice ③: the case-insensitive recognizer (decision 0035) --------------
  (define (letter? b) (or (and (>= b 65) (<= b 90)) (and (>= b 97) (<= b 122))))
  ;; The byte-set of a character's two cases — one byte where it has no case
  ;; (e.g. the hyphen), so §16.2:893's overlap rule is satisfied by construction.
  (define (both-cases b)
    (if (letter? b)
        (if (>= b 97) (list b (- b 32)) (list b (+ b 32)))
        (list b)))
  (define (nsym prefix i) (string->symbol (string-append prefix (number->string i))))

  ;; One dispatch node per grammar character (decision 0035): node i matches
  ;; char i (both cases) and ADVANCES to node i+1 (the last to `end`); its
  ;; fallback REEXECUTES into `opaque`, so the byte it did not match is re-read
  ;; there — no case-set arithmetic, and the opaque path keeps every byte. `chars`
  ;; is the canonical byte list AFTER the shared first byte.
  (define (recognizer-chain prefix chars end opaque eof-target)
    (let ((n (length chars)))
      (let loop ((i 0) (cs chars) (out '()))
        (if (null? cs)
            (reverse out)
            (let ((nextname (if (= i (- n 1)) end (nsym prefix (+ i 1)))))
              (loop (+ i 1) (cdr cs)
                    (cons (make-byte-dispatch-node
                           (nsym prefix i)
                           (list (make-byte-case (make-byte-set-matcher (both-cases (car cs)))
                                                 (make-edge nextname 'advance) #f))
                           (make-edge opaque 'reexecute)
                           eof-target #f)
                          out)))))))

  (define (make-http-machine)
    (make-machine
     'httpreq 'idle
     ;; Slice ③ fields: the checked Content-Length value and the two framing
     ;; flags. u8 flags carry 0/1; content-length is a checked u64 (§9.1 admits
     ;; width 64). Reset by the completion clear chain (§21.3:1150).
     (list (make-uint-field 'content-length 64 0 #f)
           (make-uint-field 'has-cl 8 0 #f)
           (make-uint-field 'has-te 8 0 #f))
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
           (make-callback-declaration 'message-complete 'event #f '() #f #f)
           ;; Slice ③: the fixed body's data callback — NO completion callback
           ;; (§21.3:1145).
           (make-callback-declaration 'body-data 'span-data #f '() #f #f))
     (list (make-span-declaration 'method 'method-data 'method-complete #f)
           (make-span-declaration 'target 'target-data 'target-complete #f)
           (make-span-declaration 'header-name 'header-name-data 'header-name-complete #f)
           (make-span-declaration 'header-value 'header-value-data 'header-value-complete #f)
           (make-span-declaration 'body 'body-data #f #f))
     ;; error declarations — one per §21.4 code this slice can raise; the EOF
     ;; declaration is the machine default (decision 0037).
     (list (make-error-declaration 'unexpected-eof 'unexpected-eof "unexpected end of input" #f)
           (make-error-declaration 'invalid-method 'invalid-method "method is not a token" #f)
           (make-error-declaration 'invalid-target 'invalid-target "target is not a target-byte" #f)
           (make-error-declaration 'invalid-version 'invalid-version "version is not HTTP/1.0 or HTTP/1.1" #f)
           (make-error-declaration 'invalid-line-ending 'invalid-line-ending "line ending is not CRLF" #f)
           (make-error-declaration 'invalid-header-name 'invalid-header-name "header name is not a token" #f)
           (make-error-declaration 'invalid-header-value 'invalid-header-value "header value has an invalid byte" #f)
           ;; Slice ③: the framing codes (§21.4:1162-1167).
           (make-error-declaration 'invalid-content-length 'invalid-content-length "Content-Length is not 1*DIGIT *OWS" #f)
           (make-error-declaration 'content-length-overflow 'content-length-overflow "Content-Length overflows u64" #f)
           (make-error-declaration 'duplicate-content-length 'duplicate-content-length "a second Content-Length" #f)
           (make-error-declaration 'duplicate-transfer-encoding 'duplicate-transfer-encoding "a second Transfer-Encoding" #f)
           (make-error-declaration 'framing-conflict 'framing-conflict "both Content-Length and Transfer-Encoding" #f)
           (make-error-declaration 'unsupported-transfer-encoding 'unsupported-transfer-encoding "Transfer-Encoding is not chunked" #f))
     (append
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
      ;; header-name span: 1*tchar, ends before the colon. Slice ③ opens the
      ;; span, then dispatches the first byte into the framing recognizers
      ;; (decision 0035); an unrecognized first byte reexecutes into the opaque
      ;; loop, keeping the span accumulating on both paths.
      (make-span-start-node 'hn-open 'header-name 'hn-recognize #f)
      (make-byte-dispatch-node
       'hn-recognize
       (list (make-byte-case (make-byte-set-matcher (both-cases (char->integer #\C)))
                             (make-edge 'cl-0 'advance) #f)     ; Content-Length
             (make-byte-case (make-byte-set-matcher (both-cases (char->integer #\T)))
                             (make-edge 'te-0 'advance) #f))    ; Transfer-Encoding
       (make-edge 'hn-loop 'reexecute)      ; any other first byte → opaque
       'e-eof-hname #f)
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
      (make-callback-node 'hdrs-complete 'headers-complete 'body-decide '() 'body-decide #f)
      ;; === Slice ③: the body decision (§21.2:1076-1078) ====================
      ;; Content-Length present routes to the fixed body (zero length goes
      ;; straight to completion); Transfer-Encoding present to the chunked body
      ;; (Slice ④); neither present is an empty body.
      (make-field-branch-node 'body-decide 'nonzero '(has-cl) 'bd-cl 'bd-te #f)
      (make-field-branch-node 'bd-cl 'nonzero '(content-length) 'body-open 'msg-complete #f)
      (make-field-branch-node 'bd-te 'nonzero '(has-te) 'chunked-todo 'msg-complete #f)
      (make-span-start-node 'body-open 'body 'body-consume #f)
      (make-counted-consume-node 'body-consume 'content-length 'body-close 'e-eof-body #f)
      (make-span-end-node 'body-close 'body 'msg-complete #f)
      ;; Slice ④ replaces this with the chunked body, which begins by reading the
      ;; first chunk-size byte. For ③ it is input-reading (not a stop) so it is
      ;; not an EOF-reachable stop (§16.2:909): EOF here is a truncated chunked
      ;; message (unexpected-eof, the machine default); a body byte reaches a stop
      ;; ④ will replace.
      (make-byte-dispatch-node
       'chunked-todo
       (list (make-byte-case (make-byte-range-matcher 0 255)
                             (make-edge 'chunked-stop 'advance) #f))
       (make-edge 'chunked-stop 'reexecute)   ; unreachable: the range covers all bytes
       #f #f)
      (make-stop-node 'chunked-stop #f)
      ;; message-complete, then the completion clear chain resets the message
      ;; fields (§21.3:1150) and loops to idle; the absolute offset is untouched.
      ;; `clear` is infallible, so the chain takes no error edge (decision 0037).
      (make-callback-node 'msg-complete 'message-complete 'clear-cl '() 'clear-cl #f)
      (make-field-action-node 'clear-cl 'clear '(content-length) 'clear-hascl #f #f)
      (make-field-action-node 'clear-hascl 'clear '(has-cl) 'clear-haste #f #f)
      (make-field-action-node 'clear-haste 'clear '(has-te) 'idle #f #f)
      (make-finish-node 'fin #f)
      ;; === Slice ③: the Content-Length value path ==========================
      ;; cl-end sees the byte after the recognized name: a colon confirms
      ;; Content-Length; a tchar means only the prefix matched (Content-Lengthy),
      ;; so reexecute into the opaque loop keeping the span's bytes; anything else
      ;; ends the name without a colon (invalid-header-name via hn-close).
      (make-byte-dispatch-node
       'cl-end
       (list (make-byte-case (make-exact-byte-matcher 58) (make-edge 'cl-name-close 'reexecute) #f)
             (make-byte-case (make-byte-set-matcher http-tchar-bytes) (make-edge 'hn-loop 'reexecute) #f))
       (make-edge 'hn-close 'reexecute)
       'e-eof-hname #f)
      (make-span-end-node 'cl-name-close 'header-name 'cl-colon #f)
      (make-byte-dispatch-node
       'cl-colon
       (list (make-byte-case (make-exact-byte-matcher 58) (make-edge 'cl-ows 'advance) #f))
       (make-edge 'e-hname 'reexecute) #f #f)
      (make-byte-dispatch-node        ; skip leading OWS before the value span
       'cl-ows
       (list (make-byte-case (make-exact-byte-matcher SP) (make-edge 'cl-ows 'advance) #f)
             (make-byte-case (make-exact-byte-matcher 9)  (make-edge 'cl-ows 'advance) #f))
       (make-edge 'cl-hv-open 'reexecute) #f #f)
      ;; the value is a header-value span too (§21.3): the digits are delivered
      ;; as header-value-data AND accumulated into content-length.
      (make-span-start-node 'cl-hv-open 'header-value 'cl-gate #f)
      (make-byte-dispatch-node        ; 1*DIGIT: at least one digit
       'cl-gate
       (list (make-byte-case (make-byte-range-matcher 48 57) (make-edge 'cl-value 'reexecute) #f))
       (make-edge 'e-cl-invalid 'reexecute)
       'e-eof-hvalue #f)
      (make-integer-accumulate-node 'cl-value 'content-length 10 'cl-value
        (make-edge 'cl-after 'reexecute) 'e-cl-overflow 'e-eof-hvalue #f)
      (make-byte-dispatch-node        ; *OWS (in the span), then before CR
       'cl-after
       (list (make-byte-case (make-exact-byte-matcher SP) (make-edge 'cl-after 'advance) #f)
             (make-byte-case (make-exact-byte-matcher 9)  (make-edge 'cl-after 'advance) #f)
             (make-byte-case (make-exact-byte-matcher CR) (make-edge 'cl-hv-close 'reexecute) #f))
       (make-edge 'e-cl-invalid 'reexecute)
       'e-eof-hvalue #f)
      (make-span-end-node 'cl-hv-close 'header-value 'cl-crlf-cr #f)
      (make-byte-dispatch-node
       'cl-crlf-cr
       (list (make-byte-case (make-exact-byte-matcher CR) (make-edge 'cl-crlf-lf 'advance) #f))
       (make-edge 'e-line-ending 'reexecute) #f #f)
      (make-byte-dispatch-node
       'cl-crlf-lf
       (list (make-byte-case (make-exact-byte-matcher LF) (make-edge 'cl-line-done 'advance) #f))
       (make-edge 'e-line-ending 'reexecute) #f #f)
      ;; The framing refusals are decided at the boundary AFTER the LF (P2): a
      ;; zero-width field-branch, so the position is a boundary (§21.4:1175). A
      ;; second Content-Length is a duplicate; one after a Transfer-Encoding is a
      ;; conflict; otherwise set the flag and go on.
      (make-field-branch-node 'cl-line-done 'nonzero '(has-cl) 'e-dup-cl 'cl-conflict #f)
      (make-field-branch-node 'cl-conflict 'nonzero '(has-te) 'e-framing-conflict 'cl-set #f)
      (make-field-action-node 'cl-set 'store '(has-cl 1) 'header-line-start #f #f)
      ;; === Slice ③: the Transfer-Encoding value path (case-insensitive chunked) =
      (make-byte-dispatch-node
       'te-end
       (list (make-byte-case (make-exact-byte-matcher 58) (make-edge 'te-name-close 'reexecute) #f)
             (make-byte-case (make-byte-set-matcher http-tchar-bytes) (make-edge 'hn-loop 'reexecute) #f))
       (make-edge 'hn-close 'reexecute)
       'e-eof-hname #f)
      (make-span-end-node 'te-name-close 'header-name 'te-colon #f)
      (make-byte-dispatch-node
       'te-colon
       (list (make-byte-case (make-exact-byte-matcher 58) (make-edge 'te-ows 'advance) #f))
       (make-edge 'e-hname 'reexecute) #f #f)
      (make-byte-dispatch-node
       'te-ows
       (list (make-byte-case (make-exact-byte-matcher SP) (make-edge 'te-ows 'advance) #f)
             (make-byte-case (make-exact-byte-matcher 9)  (make-edge 'te-ows 'advance) #f))
       (make-edge 'te-hv-open 'reexecute) #f #f)
      (make-span-start-node 'te-hv-open 'header-value 'tv-0 #f)   ; tv-0 recognizes "chunked"
      ;; after "chunked": optional trailing OWS (in the span), then before CR;
      ;; anything else is unsupported-transfer-encoding.
      (make-byte-dispatch-node
       'tv-end
       (list (make-byte-case (make-exact-byte-matcher SP) (make-edge 'tv-end 'advance) #f)
             (make-byte-case (make-exact-byte-matcher 9)  (make-edge 'tv-end 'advance) #f)
             (make-byte-case (make-exact-byte-matcher CR) (make-edge 'te-hv-close 'reexecute) #f))
       (make-edge 'e-te-unsup 'reexecute)
       'e-eof-hvalue #f)
      (make-span-end-node 'te-hv-close 'header-value 'te-crlf-cr #f)
      (make-byte-dispatch-node
       'te-crlf-cr
       (list (make-byte-case (make-exact-byte-matcher CR) (make-edge 'te-crlf-lf 'advance) #f))
       (make-edge 'e-line-ending 'reexecute) #f #f)
      (make-byte-dispatch-node
       'te-crlf-lf
       (list (make-byte-case (make-exact-byte-matcher LF) (make-edge 'te-line-done 'advance) #f))
       (make-edge 'e-line-ending 'reexecute) #f #f)
      (make-field-branch-node 'te-line-done 'nonzero '(has-te) 'e-dup-te 'te-conflict #f)
      (make-field-branch-node 'te-conflict 'nonzero '(has-cl) 'e-framing-conflict 'te-set #f)
      (make-field-action-node 'te-set 'store '(has-te 1) 'header-line-start #f #f)
      ;; --- error nodes, per span state (decision 0036) --------------------
      (make-error-node 'e-eof-method 'unexpected-eof #f)   ; method span open
      (make-error-node 'e-eof-target 'unexpected-eof #f)   ; target span open
      (make-error-node 'e-eof-hname 'unexpected-eof #f)    ; header-name span open
      (make-error-node 'e-eof-hvalue 'unexpected-eof #f)   ; header-value span open
      (make-error-node 'e-eof-body 'unexpected-eof #f)     ; body span open
      (make-error-node 'e-method 'invalid-method #f)       ; no span open
      (make-error-node 'e-target 'invalid-target #f)       ; no span open
      (make-error-node 'e-version 'invalid-version #f)     ; no span open
      (make-error-node 'e-line-ending 'invalid-line-ending #f)
      (make-error-node 'e-hname 'invalid-header-name #f)   ; no span open
      (make-error-node 'e-hvalue 'invalid-header-value #f) ; no span open
      (make-error-node 'e-cl-invalid 'invalid-content-length #f)      ; header-value span open
      (make-error-node 'e-cl-overflow 'content-length-overflow #f)    ; header-value span open
      (make-error-node 'e-dup-cl 'duplicate-content-length #f)        ; no span open (post-LF)
      (make-error-node 'e-dup-te 'duplicate-transfer-encoding #f)     ; no span open (post-LF)
      (make-error-node 'e-framing-conflict 'framing-conflict #f)      ; no span open (post-LF)
      (make-error-node 'e-te-unsup 'unsupported-transfer-encoding #f)) ; header-value span open
     ;; the case-insensitive recognizer chains (decision 0035), generated
     (recognizer-chain "cl-" (string-bytes "ontent-Length") 'cl-end 'hn-loop 'e-eof-hname)
     (recognizer-chain "te-" (string-bytes "ransfer-Encoding") 'te-end 'hn-loop 'e-eof-hname)
     (recognizer-chain "tv-" (string-bytes "chunked") 'tv-end 'e-te-unsup 'e-eof-hvalue))
     'unexpected-eof #f)))                 ; machine default EOF (no span)
