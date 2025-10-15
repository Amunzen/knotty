#lang racket

(module+ test
  (require rackunit
           racket/file
           racket/path
           racket/system
           racket/runtime-path)

  (define-runtime-path resources-xml
    "../knotty-lib/resources/example/lattice.xml")

  (define (with-temporary-directory proc)
    (define temp-dir (make-temporary-directory))
    (dynamic-wind
      void
      (lambda () (proc temp-dir))
      (lambda ()
        (when (directory-exists? temp-dir)
          (delete-directory/files temp-dir)))))

  (define (bundle-output-dir filestem)
    (or (path-only (path-replace-extension filestem #".html"))
        (current-directory)))

  (test-case "CLI --export-bundle writes all assets"
    (with-temporary-directory
     (lambda (temp-root)
       (define input-dir (build-path temp-root "input"))
       (make-directory* input-dir)
       (define filestem (build-path input-dir "lattice"))
       (copy-file resources-xml
                  (path-replace-extension filestem #".xml")
                  #:exists-ok? #t)
       (define output-filestem (build-path temp-root "output" "bundle"))

       (define exit-code
         (system*/exit-code
          "racket"
          "knotty-lib/cli.rkt"
          "--quiet"
          "--import-xml"
          "--export-bundle"
          "--output" (path->string output-filestem)
          (path->string filestem)))
       (check-eqv? exit-code 0)

       (define output-dir (bundle-output-dir output-filestem))

       (check-true (file-exists? (path-replace-extension output-filestem #".html")))
       (check-true (file-exists? (path-replace-extension output-filestem #".xml")))
       (check-true (file-exists? (path-replace-extension output-filestem #".txt")))
       (check-true (file-exists? (path-replace-extension output-filestem #".png")))

       (check-true (file-exists? (build-path output-dir "css" "knotty.css")))
       (check-true (file-exists? (build-path output-dir "css" "knotty-manual.css")))
       (check-true (file-exists? (build-path output-dir "js" "knotty.js")))
       (check-true (file-exists? (build-path output-dir "font" "StitchMasteryDash.ttf")))
       (check-true (file-exists? (build-path output-dir "font" "georgia.ttf")))
       (check-true (file-exists? (build-path output-dir "icon" "favicon.ico"))))))

;; end
