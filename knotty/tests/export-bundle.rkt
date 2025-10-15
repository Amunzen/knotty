#lang racket

(module+ test
  (require rackunit
           racket/file
           racket/path
           racket/string)
  (require "../../knotty-lib/export-bundle.rkt"
           "mocks.rkt")

  (define (with-temporary-directory proc)
    (define temp-dir (make-temporary-directory))
    (dynamic-wind
      void
      (lambda () (proc temp-dir))
      (lambda () (delete-directory/files temp-dir))))

  (test-case "export-pattern-bundle writes all formats"
    (with-temporary-directory
     (lambda (temp-dir)
       (define outputs
         (export-pattern-bundle dummy-pattern temp-dir
                                #:basename "bundle-sample"
                                #:overwrite? #t))
       (define html-path (hash-ref outputs 'html))
       (define xml-path (hash-ref outputs 'xml))
       (define text-path (hash-ref outputs 'text))
       (define png-path (hash-ref outputs 'png))

       (check-true (file-exists? html-path))
       (check-true (file-exists? xml-path))
       (check-true (file-exists? text-path))
       (check-true (file-exists? png-path))

       (define html-content (file->string html-path))
       (define xml-content (file->string xml-path))
       (define instructions (file->string text-path))

       (check-true (> (string-length html-content) 0))
       (check-true (> (string-length xml-content) 0))
       (check-true (or (zero? (string-length instructions))
                       (string-suffix? instructions "\n")))

       (define png-bytes (file->bytes png-path))
       (check-true (> (bytes-length png-bytes) 0)))))

  (test-case "export-pattern-bundle enforces overwrite flag"
    (with-temporary-directory
     (lambda (temp-dir)
       (export-pattern-bundle dummy-pattern temp-dir
                              #:basename "bundle-sample"
                              #:overwrite? #t)
       (check-exn exn:fail?
                  (lambda ()
                    (export-pattern-bundle dummy-pattern temp-dir
                                           #:basename "bundle-sample")))
       (check-not-exn
        (lambda ()
          (export-pattern-bundle dummy-pattern temp-dir
                                 #:basename "bundle-sample"
                                 #:overwrite? #t)))))))

;; end
