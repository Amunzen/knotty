#lang racket

(require racket/cmdline
         racket/path
         racket/runtime-path)

(define-runtime-path script-dir ".")
(define repo-root (simplify-path (build-path script-dir "..")))
(define main-module
  `(file ,(path->string (build-path repo-root "knotty-lib" "main.rkt"))))

(define export-pattern-bundle
  (dynamic-require main-module 'export-pattern-bundle))
(define import-xml
  (dynamic-require main-module 'import-xml))
(define import-ks
  (dynamic-require main-module 'import-ks))
(define import-png
  (dynamic-require main-module 'import-png))

(define pattern-spec #f)
(define pattern-id 'lattice-4-cables)
(define output-dir ".")
(define basename "pattern")
(define repeats-h 1)
(define repeats-v 1)
(define overwrite? #f)

(command-line
 #:once-each
 [("-p" "--pattern") path "Path to the pattern module (e.g., patterns/lattice-4-cables.rkt)"
  (set! pattern-spec path)]
 [("-n" "--name") id "Identifier exported by the pattern module"
  (set! pattern-id (string->symbol id))]
 [("-o" "--output") dir "Output directory for bundle artifacts"
  (set! output-dir dir)]
 [("-b" "--basename") base "Basename used for generated files"
  (set! basename base)]
 [("--h-repeats") h "Horizontal repeats (positive integer)"
  (set! repeats-h (string->number h))]
 [("--v-repeats") v "Vertical repeats (positive integer)"
  (set! repeats-v (string->number v))]
 #:once-any
 [("--overwrite") "Overwrite existing bundle files"
  (set! overwrite? #t)]
 #:args ()
 (void))

(when (not pattern-spec)
  (error 'export-pattern-bundle "missing required --pattern argument"))

(define module-path
  (let ([raw (string->path pattern-spec)])
    (path->string (simplify-path raw (current-directory)))))

(define pattern
  (dynamic-require `(file ,module-path) pattern-id))

(define output-path
  (path->complete-path (string->path output-dir)))

(keyword-apply export-pattern-bundle
               '(#:basename #:h-repeats #:overwrite? #:v-repeats)
               (list basename repeats-h overwrite? repeats-v)
               (list pattern output-path))

(displayln (format "Bundle written to ~a (basename ~a)"
                   (path->string output-path)
                   basename))
