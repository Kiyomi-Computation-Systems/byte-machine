;;; The fixture-state -> expected-error table for the private HTTP fixture.
;;;
;;; *** THIS TABLE IS THE HTTP FIXTURE'S, AND IT NEVER BECOMES A GENERIC
;;; BYTE-MACHINE ERROR CATALOG. *** The verifier's diagnostic catalog is a
;;; different document. This table lives beside the fixture, no `src/` library
;;; imports it, and it carries no HTTP vocabulary into any `(byte-machine ...)`
;;; name.
;;;
;;; It maps every fixture state family to its expected byte, boundary, or EOF
;;; error, and is written independently of the fixture: it is the thing the
;;; fixture is measured against, not a transcription of what the fixture does.
;;;
;;; A row is (region trigger code position-kind offset-rule production):
;;;   region       -- an HTTP grammar region, NOT a node name, so a row survives
;;;                   node renames.
;;;   trigger      -- `byte`, `boundary` or `eof`: what causes the error.
;;;   code         -- one of the eighteen stable HTTP error codes.
;;;   position-kind-- `byte`, `boundary` or `eof`, the parser-error-position-kind
;;;                   the fixture reports (`byte | boundary | eof`). Every eof
;;;                   row is `eof`: the fixture reports position-kind `eof` for an
;;;                   `unexpected-eof` raised by `parser-finish!` ("`eof` at the
;;;                   final stream offset").
;;;   offset-rule  -- the error-position rule restated for this row, as data.
;;;   production   -- the grammar production the region guards.
;;;
;;; A (region trigger) pair that CANNOT produce an error is an entry in
;;; http-error-inapplicable, carrying its reason as DATA (never as a comment or
;;; an omission), so the totality check can see it. Every (region x trigger) is
;;; covered by exactly one side: a row, or an inapplicable entry.
;;;
;;; TWO ROWS THAT NEED THE GRAMMAR IN FRONT OF THEM:
;;;  1. `forbidden-trailer`'s position: "at the colon following the completed
;;;     forbidden name". The name is completed (its bytes consumed); the colon
;;;     is then the first offending UNCONSUMED byte, and lexical errors win at
;;;     the first offending unconsumed byte, which makes it a `byte` trigger with
;;;     `byte` position-kind -- NOT a `boundary`. framing-conflict, by contrast,
;;;     is a genuine `boundary`: a zero-width decision after the later header
;;;     line's LF, no byte of its own.
;;;  2. Whether `fixed-body` and `chunk-data` can produce a non-EOF error. They
;;;     consume EXACTLY the counted number of octets and reject nothing once the
;;;     count is fixed, so the byte and boundary cells are inapplicable -- stated
;;;     as a claim, with the reason as data, not left as an empty cell.
(library (byte-machine test http-error-table)
  (export http-error-rows
          http-error-inapplicable
          http-error-regions
          http-error-triggers
          http-error-region-nodes)
  (import (rnrs))

  ;; The regions of the HTTP grammar, in stream order. A region is a NAME, not a
  ;; node: node names can change, a region does not.
  (define http-error-regions
    '(idle
      method
      target
      version
      request-line-crlf
      header-name
      header-value
      header-crlf
      content-length-value
      transfer-encoding-value
      fixed-body
      chunk-size
      chunk-ext-name
      chunk-ext-value
      chunk-data
      chunk-ending
      trailer-name
      trailer-value))

  ;; The three triggers the error-position rule names.
  (define http-error-triggers '(byte boundary eof))

  ;; Every producible (region trigger code position-kind offset-rule production).
  ;; A cell with two codes (content-length-value, chunk-size, header-crlf's
  ;; boundary, trailer-name's byte) is two rows. `unexpected-eof` is one row per
  ;; non-idle region: each is an error node of its own, all naming one
  ;; declaration; the row is keyed on the region, not the node.
  (define http-error-rows
    '(;; --- request line -----------------------------------------------------
      (idle byte invalid-method byte
            "the first offending unconsumed byte -- a byte that is not a tchar where a method must begin"
            "method = 1*tchar")
      (method byte invalid-method byte
              "the first offending unconsumed byte -- not a tchar inside the method"
              "method = 1*tchar")
      (method eof unexpected-eof eof
              "the final stream boundary -- EOF in a non-idle state"
              "method = 1*tchar")
      (target byte invalid-target byte
              "the first offending unconsumed byte -- not a target-byte"
              "request-target = 1*target-byte")
      (target eof unexpected-eof eof
              "the final stream boundary -- EOF in a non-idle state"
              "request-target = 1*target-byte")
      (version byte invalid-version byte
               "the first offending unconsumed byte -- diverges from HTTP/1.0 or HTTP/1.1"
               "version = \"HTTP/1.0\" / \"HTTP/1.1\"")
      (version eof unexpected-eof eof
               "the final stream boundary -- EOF in a non-idle state"
               "version = \"HTTP/1.0\" / \"HTTP/1.1\"")
      (request-line-crlf byte invalid-line-ending byte
                         "the first offending unconsumed byte -- a bare CR or bare LF where CRLF is required"
                         "CRLF = %x0D %x0A")
      (request-line-crlf eof unexpected-eof eof
                         "the final stream boundary -- EOF in a non-idle state"
                         "CRLF = %x0D %x0A")
      ;; --- header section ---------------------------------------------------
      (header-name byte invalid-header-name byte
                   "the first offending unconsumed byte -- not a tchar inside a field-name"
                   "field-name = 1*tchar")
      (header-name eof unexpected-eof eof
                   "the final stream boundary -- EOF in a non-idle state"
                   "field-name = 1*tchar")
      (header-value byte invalid-header-value byte
                    "the first offending unconsumed byte -- not a field-value-byte"
                    "field-value = *field-value-byte")
      (header-value eof unexpected-eof eof
                    "the final stream boundary -- EOF in a non-idle state"
                    "field-value = *field-value-byte")
      (header-crlf byte invalid-line-ending byte
                   "the first offending unconsumed byte -- a bare CR or bare LF where a header CRLF is required"
                   "header-field = field-name \":\" OWS field-value CRLF")
      (header-crlf boundary duplicate-content-length boundary
                   "the between-byte boundary after the later header line's LF -- a second Content-Length"
                   "content-length = 1*DIGIT *OWS")
      (header-crlf boundary duplicate-transfer-encoding boundary
                   "the between-byte boundary after the later header line's LF -- a second Transfer-Encoding"
                   "transfer-value = case-insensitive(\"chunked\") *OWS")
      (header-crlf boundary framing-conflict boundary
                   "the between-byte boundary after the later header line's LF -- both framing headers present"
                   "body = fixed-body / chunked-body / empty")
      (header-crlf eof unexpected-eof eof
                   "the final stream boundary -- EOF in a non-idle state"
                   "header-section = *header-field CRLF")
      ;; --- framing header values -------------------------------------------
      (content-length-value byte invalid-content-length byte
                            "the first offending unconsumed byte -- not a DIGIT and not trailing OWS"
                            "content-length = 1*DIGIT *OWS")
      (content-length-value byte content-length-overflow byte
                            "the digit that would overflow u64, left unconsumed"
                            "content-length = 1*DIGIT *OWS")
      (content-length-value eof unexpected-eof eof
                            "the final stream boundary -- EOF in a non-idle state"
                            "content-length = 1*DIGIT *OWS")
      (transfer-encoding-value byte unsupported-transfer-encoding byte
                               "the first offending unconsumed byte -- a value other than case-insensitive chunked plus trailing OWS"
                               "transfer-value = case-insensitive(\"chunked\") *OWS")
      (transfer-encoding-value eof unexpected-eof eof
                               "the final stream boundary -- EOF in a non-idle state"
                               "transfer-value = case-insensitive(\"chunked\") *OWS")
      ;; --- fixed body -------------------------------------------------------
      (fixed-body eof unexpected-eof eof
                  "the final stream boundary -- EOF before content-length octets have been consumed"
                  "fixed-body = exactly content-length octets")
      ;; --- chunked body -----------------------------------------------------
      (chunk-size byte invalid-chunk-size byte
                  "the first offending unconsumed byte -- not a HEXDIG where a chunk size must begin"
                  "nonzero-chunk = 1*HEXDIG chunk-ext CRLF chunk-data CRLF")
      (chunk-size byte chunk-size-overflow byte
                  "the digit that would overflow u64, left unconsumed"
                  "nonzero-chunk = 1*HEXDIG chunk-ext CRLF chunk-data CRLF")
      (chunk-size eof unexpected-eof eof
                  "the final stream boundary -- EOF in a non-idle state"
                  "nonzero-chunk = 1*HEXDIG chunk-ext CRLF chunk-data CRLF")
      (chunk-ext-name byte invalid-chunk-extension byte
                      "the first offending unconsumed byte -- not a token character where an extension name is expected"
                      "chunk-ext = *(\";\" token [\"=\" token])")
      (chunk-ext-name eof unexpected-eof eof
                      "the final stream boundary -- EOF in a non-idle state"
                      "chunk-ext = *(\";\" token [\"=\" token])")
      (chunk-ext-value byte invalid-chunk-extension byte
                       "the first offending unconsumed byte -- not a token character where an extension value is expected (quoted values are excluded)"
                       "chunk-ext = *(\";\" token [\"=\" token])")
      (chunk-ext-value eof unexpected-eof eof
                       "the final stream boundary -- EOF in a non-idle state"
                       "chunk-ext = *(\";\" token [\"=\" token])")
      (chunk-data eof unexpected-eof eof
                  "the final stream boundary -- EOF before decoded chunk-size octets have been consumed"
                  "chunk-data = exactly decoded chunk-size octets")
      (chunk-ending byte invalid-chunk-ending byte
                    "the first offending unconsumed byte -- the CRLF terminating chunk data is malformed"
                    "nonzero-chunk = 1*HEXDIG chunk-ext CRLF chunk-data CRLF")
      (chunk-ending eof unexpected-eof eof
                    "the final stream boundary -- EOF in a non-idle state"
                    "nonzero-chunk = 1*HEXDIG chunk-ext CRLF chunk-data CRLF")
      ;; --- trailers ---------------------------------------------------------
      (trailer-name byte invalid-header-name byte
                    "the first offending unconsumed byte -- not a tchar inside a trailer name"
                    "trailer-field = header-field")
      (trailer-name byte forbidden-trailer byte
                    "the colon following the completed forbidden name -- the first unconsumed byte after a Content-Length or Transfer-Encoding trailer name"
                    "trailer-field = header-field")
      (trailer-name eof unexpected-eof eof
                    "the final stream boundary -- EOF in a non-idle state"
                    "trailer-field = header-field")
      (trailer-value byte invalid-header-value byte
                     "the first offending unconsumed byte -- not a field-value-byte inside a trailer value"
                     "trailer-field = header-field")
      (trailer-value eof unexpected-eof eof
                     "the final stream boundary -- EOF in a non-idle state"
                     "trailer-field = header-field")))

  ;; The (region trigger reason) cells that CANNOT produce an error. Each reason
  ;; is data the totality check reads; a region x trigger is covered by exactly
  ;; one of a row or one of these.
  (define http-error-inapplicable
    '((idle boundary
            "idle reads one byte to decide whether a message begins; it has no zero-width boundary decision")
      (idle eof
            "clean finish, not an error: idle's eof-target is the finish terminal, so EOF between messages is `finished` (decision 0037)")
      (method boundary
            "the method is a byte span; it takes no zero-width boundary decision")
      (target boundary
            "the target is a byte span; it takes no zero-width boundary decision")
      (version boundary
            "the version is a byte sequence; it takes no zero-width boundary decision")
      (request-line-crlf boundary
            "the request-line CRLF is matched byte by byte; it takes no zero-width boundary decision")
      (header-name boundary
            "a header name is a byte span; it takes no zero-width boundary decision")
      (header-value boundary
            "a header value is a byte span; it takes no zero-width boundary decision")
      (content-length-value boundary
            "the Content-Length value is a byte span of digits and OWS; the framing conflict it can raise is charged to header-crlf's boundary after the line completes")
      (transfer-encoding-value boundary
            "the Transfer-Encoding value is a byte span; the framing conflict it can raise is charged to header-crlf's boundary after the line completes")
      (fixed-body byte
            "the fixed body consumes exactly content-length octets and rejects no byte once the count is fixed")
      (fixed-body boundary
            "the fixed body has no zero-width decision inside it; its only failure is EOF before the count is met")
      (chunk-size boundary
            "the chunk size is a byte span of hex digits; it takes no zero-width boundary decision")
      (chunk-ext-name boundary
            "a chunk-extension name is a byte span; it takes no zero-width boundary decision")
      (chunk-ext-value boundary
            "a chunk-extension value is a byte span; it takes no zero-width boundary decision")
      (chunk-data byte
            "chunk data consumes exactly decoded chunk-size octets and rejects no byte once the count is fixed")
      (chunk-data boundary
            "chunk data has no zero-width decision inside it; its only failure is EOF before the count is met")
      (chunk-ending boundary
            "the chunk-ending CRLF is matched byte by byte; it takes no zero-width boundary decision")
      (trailer-name boundary
            "a forbidden trailer is a `byte` at the colon, not a boundary; the trailer name otherwise takes no zero-width decision")
      (trailer-value boundary
            "a trailer value is a byte span; it takes no zero-width boundary decision")))

  ;; The exported fixture-region -> node-name map. It lets a failure name the
  ;; node without coupling the rows to node names. Every region maps to the
  ;; empty list, so its totality row ("every declared node is in exactly one
  ;; region") is vacuously true and bites only once a region lists nodes.
  (define http-error-region-nodes
    (map (lambda (region) (cons region '())) http-error-regions)))
