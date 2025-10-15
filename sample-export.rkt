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

define outputs
  (export-pattern-bundle sample-pattern output-dir
                         #:basename "sample-pattern"
                         #:overwrite? #t)

define html-path (hash-ref outputs 'html)
define xml-path (hash-ref outputs 'xml)
define instructions-path (hash-ref outputs 'text)
define png-path (hash-ref outputs 'png)

printf "HTML written to ~a\n" (path->string html-path)
printf "XML written to ~a\n" (path->string xml-path)
printf "Instructions written to ~a\n" (path->string instructions-path)
printf "PNG written to ~a\n" (path->string png-path)
