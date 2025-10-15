#lang sweet-exp typed/racket

require racket/file
require "knotty-lib/main.rkt"

;; Simple swatch pattern used for demo exports.
define sample-pattern
  pattern
    [name "Sample Swatch"]
    rows(1 3) k4
    rows(2 4) p
    row(5) bo

define output-dir
  (build-path (current-directory) "sample-output")

when (not (directory-exists? output-dir))
  (make-directory output-dir)

define html-path
  (build-path output-dir "sample-pattern.html")

define xml-path
  (build-path output-dir "sample-pattern.xml")

define instructions-path
  (build-path output-dir "sample-pattern.txt")

when (file-exists? html-path)
  (delete-file html-path)

when (file-exists? xml-path)
  (delete-file xml-path)

when (file-exists? instructions-path)
  (delete-file instructions-path)

export-html sample-pattern html-path
export-xml sample-pattern xml-path
export-instructions sample-pattern instructions-path

printf "HTML written to ~a\n" (path->string html-path)
printf "XML written to ~a\n" (path->string xml-path)
printf "Instructions written to ~a\n" (path->string instructions-path)
