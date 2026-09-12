;;; The fixture-state -> expected-error table for the private HTTP fixture.
;;;
;;; *** THIS TABLE IS THE HTTP FIXTURE'S, AND IT NEVER BECOMES A GENERIC
;;; BYTE-MACHINE ERROR CATALOG. *** §21.4:1177's second sentence is a scope
;;; constraint in those words. §27:1696's diagnostic catalog is a different,
;;; UNSCHEDULED document (Milestone 7 design §10 says so); this table is not its
;;; first instalment. It lives beside the fixture, no `src/` library imports it
;;; (§4.7's gate and Slice ⑤'s leak check assert that), and it carries no HTTP
;;; vocabulary into any `(byte-machine ...)` name.
;;;
;;; It discharges §21.4:1177's precondition, addressed to tests: "Before
;;; Milestone 8 implementation begins, tests must expand this catalog into a
;;; table mapping every fixture state family to its expected byte, boundary, or
;;; EOF error." Slice ⓪ ships it FIRST, before any grammar node exists (decision
;;; 0034): written after the fixture it would be a transcription of what the
;;; fixture does; written first it is the thing the fixture is measured against,
;;; and every slice from ① onward states which of these rows it makes true.
;;;
;;; A row is (region trigger code position-kind offset-rule production):
;;;   region       -- a §21.2 grammar region, NOT a node name, so a row survives
;;;                   the node renames every later slice performs (decision 0034).
;;;   trigger      -- `byte`, `boundary` or `eof`, matching §21.4:1175's three
;;;                   sentences: what causes the error.
;;;   code         -- one of §21.4:1156-1173's eighteen stable codes.
;;;   position-kind-- `byte` or `boundary`, the parser-error-position-kind the
;;;                   fixture will report (§12.7:770-773, and what the runtime's
;;;                   `(kind ...)` carries).
;;;   offset-rule  -- §21.4:1175 restated for this row, as data.
;;;   production   -- the §21.2 production the region guards.
;;;
;;; A (region trigger) pair that CANNOT produce an error is an entry in
;;; http-error-inapplicable, carrying its reason as DATA (never as a comment or
;;; an omission), so the totality check can see it. Every (region x trigger) is
;;; covered by exactly one side: a row, or an inapplicable entry.
;;;
;;; TWO ROWS THIS TABLE DECIDES WITH THE GRAMMAR IN FRONT OF IT (design
;;; Appendix, "the two rows this table cannot fill from reading"):
;;;  1. `forbidden-trailer`'s position. §21.4:1175 says "at the colon following
;;;     the completed forbidden name". The name is completed (its bytes
;;;     consumed); the colon is then the first offending UNCONSUMED byte, and
;;;     §21.4:1175's first sentence ("lexical errors win at the first offending
;;;     unconsumed byte") makes it a `byte` trigger with `byte` position-kind --
;;;     NOT the `boundary` the Appendix skeleton guessed. framing-conflict, by
;;;     contrast, is a genuine `boundary`: a zero-width decision after the later
;;;     header line's LF, no byte of its own.
;;;  2. Whether `fixed-body` and `chunk-data` can produce a non-EOF error. They
;;;     consume EXACTLY the counted number of octets and reject nothing once the
;;;     count is fixed, so the byte and boundary cells are inapplicable -- stated
;;;     as a claim, with the reason as data, not left as an empty cell.
;;;
;;; The "read from the machine" half of decision 0034's code set-equal has no
;;; machine to read at Slice ⓪; the test asserts the code union against the
;;; eighteen §21.4 names alone, and Slice ⑤ closes the set-equal once the
;;; fixture's own error declarations exist.
(library (byte-machine test http-error-table)
  (export http-error-rows
          http-error-inapplicable
          http-error-regions
          http-error-triggers
          http-error-region-nodes)
  (import (rnrs))

  ;; The regions of §21.2's grammar, in stream order. A region is a NAME, not a
  ;; node: node names change as slices land, a region does not (decision 0034).
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

  ;; The three triggers §21.4:1175's three position sentences name.
  (define http-error-triggers '(byte boundary eof))

  ;; Every producible (region trigger code position-kind offset-rule production).
  ;; A cell with two codes (content-length-value, chunk-size, header-crlf's
  ;; boundary, trailer-name's byte) is two rows. `unexpected-eof` is one row per
  ;; non-idle region: decision 0036 makes each an error node of its own, all
  ;; naming one declaration; the row is keyed on the region, not the node.
  (define http-error-rows
    '(;; --- request line -----------------------------------------------------
      (idle byte invalid-method byte
            "the first offending unconsumed byte -- a byte that is not a tchar where a method must begin"
            "method = 1*tchar")
      (method byte invalid-method byte
              "the first offending unconsumed byte -- not a tchar inside the method"
              "method = 1*tchar")
      (method eof unexpected-eof boundary
              "the final stream boundary -- EOF in a non-idle state"
              "method = 1*tchar")
      (target byte invalid-target byte
              "the first offending unconsumed byte -- not a target-byte"
              "request-target = 1*target-byte")
      (target eof unexpected-eof boundary
              "the final stream boundary -- EOF in a non-idle state"
              "request-target = 1*target-byte")
      (version byte invalid-version byte
               "the first offending unconsumed byte -- diverges from HTTP/1.0 or HTTP/1.1"
               "version = \"HTTP/1.0\" / \"HTTP/1.1\"")
      (version eof unexpected-eof boundary
               "the final stream boundary -- EOF in a non-idle state"
               "version = \"HTTP/1.0\" / \"HTTP/1.1\"")
      (request-line-crlf byte invalid-line-ending byte
                         "the first offending unconsumed byte -- a bare CR or bare LF where CRLF is required"
                         "CRLF = %x0D %x0A")
      (request-line-crlf eof unexpected-eof boundary
                         "the final stream boundary -- EOF in a non-idle state"
                         "CRLF = %x0D %x0A")
      ;; --- header section ---------------------------------------------------
      (header-name byte invalid-header-name byte
                   "the first offending unconsumed byte -- not a tchar inside a field-name"
                   "field-name = 1*tchar")
      (header-name eof unexpected-eof boundary
                   "the final stream boundary -- EOF in a non-idle state"
                   "field-name = 1*tchar")
      (header-value byte invalid-header-value byte
                    "the first offending unconsumed byte -- not a field-value-byte"
                    "field-value = *field-value-byte")
      (header-value eof unexpected-eof boundary
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
      (header-crlf eof unexpected-eof boundary
                   "the final stream boundary -- EOF in a non-idle state"
                   "header-section = *header-field CRLF")
      ;; --- framing header values -------------------------------------------
      (content-length-value byte invalid-content-length byte
                            "the first offending unconsumed byte -- not a DIGIT and not trailing OWS"
                            "content-length = 1*DIGIT *OWS")
      (content-length-value byte content-length-overflow byte
                            "the digit that would overflow u64, left unconsumed"
                            "content-length = 1*DIGIT *OWS")
      (content-length-value eof unexpected-eof boundary
                            "the final stream boundary -- EOF in a non-idle state"
                            "content-length = 1*DIGIT *OWS")
      (transfer-encoding-value byte unsupported-transfer-encoding byte
                               "the first offending unconsumed byte -- a value other than case-insensitive chunked plus trailing OWS"
                               "transfer-value = case-insensitive(\"chunked\") *OWS")
      (transfer-encoding-value eof unexpected-eof boundary
                               "the final stream boundary -- EOF in a non-idle state"
                               "transfer-value = case-insensitive(\"chunked\") *OWS")
      ;; --- fixed body -------------------------------------------------------
      (fixed-body eof unexpected-eof boundary
                  "the final stream boundary -- EOF before content-length octets have been consumed"
                  "fixed-body = exactly content-length octets")
      ;; --- chunked body -----------------------------------------------------
      (chunk-size byte invalid-chunk-size byte
                  "the first offending unconsumed byte -- not a HEXDIG where a chunk size must begin"
                  "nonzero-chunk = 1*HEXDIG chunk-ext CRLF chunk-data CRLF")
      (chunk-size byte chunk-size-overflow byte
                  "the digit that would overflow u64, left unconsumed"
                  "nonzero-chunk = 1*HEXDIG chunk-ext CRLF chunk-data CRLF")
      (chunk-size eof unexpected-eof boundary
                  "the final stream boundary -- EOF in a non-idle state"
                  "nonzero-chunk = 1*HEXDIG chunk-ext CRLF chunk-data CRLF")
      (chunk-ext-name byte invalid-chunk-extension byte
                      "the first offending unconsumed byte -- not a token character where an extension name is expected"
                      "chunk-ext = *(\";\" token [\"=\" token])")
      (chunk-ext-name eof unexpected-eof boundary
                      "the final stream boundary -- EOF in a non-idle state"
                      "chunk-ext = *(\";\" token [\"=\" token])")
      (chunk-ext-value byte invalid-chunk-extension byte
                       "the first offending unconsumed byte -- not a token character where an extension value is expected (quoted values are excluded)"
                       "chunk-ext = *(\";\" token [\"=\" token])")
      (chunk-ext-value eof unexpected-eof boundary
                       "the final stream boundary -- EOF in a non-idle state"
                       "chunk-ext = *(\";\" token [\"=\" token])")
      (chunk-data eof unexpected-eof boundary
                  "the final stream boundary -- EOF before decoded chunk-size octets have been consumed"
                  "chunk-data = exactly decoded chunk-size octets")
      (chunk-ending byte invalid-chunk-ending byte
                    "the first offending unconsumed byte -- the CRLF terminating chunk data is malformed"
                    "nonzero-chunk = 1*HEXDIG chunk-ext CRLF chunk-data CRLF")
      (chunk-ending eof unexpected-eof boundary
                    "the final stream boundary -- EOF in a non-idle state"
                    "nonzero-chunk = 1*HEXDIG chunk-ext CRLF chunk-data CRLF")
      ;; --- trailers ---------------------------------------------------------
      (trailer-name byte invalid-header-name byte
                    "the first offending unconsumed byte -- not a tchar inside a trailer name"
                    "trailer-field = header-field")
      (trailer-name byte forbidden-trailer byte
                    "the colon following the completed forbidden name -- the first unconsumed byte after a Content-Length or Transfer-Encoding trailer name"
                    "trailer-field = header-field")
      (trailer-name eof unexpected-eof boundary
                    "the final stream boundary -- EOF in a non-idle state"
                    "trailer-field = header-field")
      (trailer-value byte invalid-header-value byte
                     "the first offending unconsumed byte -- not a field-value-byte inside a trailer value"
                     "trailer-field = header-field")
      (trailer-value eof unexpected-eof boundary
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

  ;; §4.9 item 2 (owner-approved): the exported fixture-region -> node-name map.
  ;; It lets a failure name the node without coupling the rows to node names. At
  ;; Slice ⓪ NO grammar node exists, so every region maps to the empty list; the
  ;; map grows a row's node list per slice as ① onward build the fixture, and its
  ;; totality row ("every declared node is in exactly one region") is vacuously
  ;; true here and bites once nodes exist.
  (define http-error-region-nodes
    (map (lambda (region) (cons region '())) http-error-regions)))
