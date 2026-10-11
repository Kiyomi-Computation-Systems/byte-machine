#!r6rs
(library (site pages)
  (export pages home-page page-html-name)
  (import (rnrs))

  ;; The nav's single source of order and labels. test/site/site-check.sps
  ;; asserts the file set here equals docs/*.md.
  (define pages
    '(("README.md"     . "Home")
      ("installing.md" . "Installing")
      ("usage.md"      . "Usage")
      ("machines.md"   . "Building machines")
      ("fields.md"     . "Fields and counts")
      ("callbacks.md"  . "Callbacks and spans")
      ("running.md"    . "Running a parser")
      ("errors.md"     . "Errors")
      ("verifier.md"   . "The verifier")
      ("generating.md" . "Generated code")
      ("testing.md"    . "Testing a grammar")
      ("llparse.md"    . "Why llparse-style")
      ("reference.md"  . "API reference")
      ("building.md"   . "Building")))

  ;; The page a site visitor lands on. Its source is docs/README.md, so that
  ;; browsing docs/ on GitHub shows the same index the site opens with.
  (define home-page "README.md")

  ;; page-html-name : String -> String
  ;; The file a page is written to: "usage.md" -> "usage.html", and the home
  ;; page -> "index.html". Every name the site emits for a page goes through
  ;; here -- the files written, the nav and footer links, and rewritten
  ;; links -- so the three cannot disagree about where the home page went.
  (define (page-html-name name)
    (if (string=? name home-page)
        "index.html"
        (string-append (substring name 0 (- (string-length name) 3)) ".html"))))
