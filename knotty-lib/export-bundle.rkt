#lang sweet-exp typed/racket

(provide export-pattern-bundle)

(require racket/file)
(require racket/path)
(require racket/string)
(require racket/hash)

(require/typed sxml
  [srl:sxml->xml-noindent (Sexp -> String)])

(require/typed "html.rkt"
  [pattern-template (->* (Output-Port
                          Pattern
                          (HashTable Symbol Integer))
                         (Boolean)
                         Void)])
(require/typed "xml.rkt"
  [pattern->sxml (Pattern -> Sexp)])

(require "pattern.rkt")
(require "text.rkt")
(require "png.rkt")
(require "knitspeak.rkt")

(define-type Paths-Hash
  (Immutable-HashTable Symbol Path))

(: export-pattern-bundle
   (->* (Pattern Path-String)
        (#:basename (Option String)
         #:overwrite? Boolean
         #:h-repeats Positive-Integer
         #:v-repeats Positive-Integer
         #:cell-size Positive-Integer
         #:margin Nonnegative-Integer)
        Paths-Hash))
(define (export-pattern-bundle p output-dir
                               #:basename [maybe-basename #f]
                               #:overwrite? [overwrite? #f]
                               #:h-repeats [h 1]
                               #:v-repeats [v 1]
                               #:cell-size [cell-size 36]
                               #:margin [margin 2])
  (define dir (normalise-output-directory output-dir))
  (define base (determine-basename p maybe-basename))
  (define html-path (build-path dir (string-append base ".html")))
  (define png-path (build-path dir (string-append base ".png")))
  (define xml-path (build-path dir (string-append base ".xml")))
  (define text-path (build-path dir (string-append base ".txt")))
  (define ks-path (build-path dir (string-append base ".ks")))
  (ensure-writable html-path overwrite?)
  (ensure-writable png-path overwrite?)
  (ensure-writable xml-path overwrite?)
  (ensure-writable text-path overwrite?)
  (ensure-writable ks-path overwrite?)

  (define instructions (pattern->instructions-text p))
  (define html-content (render-html p h v))
  (define xml-bytes (render-xml-bytes p))

  (write-string-file html-path html-content overwrite?)
  (write-bytes-file xml-path xml-bytes overwrite?)
  (write-instructions-file text-path instructions overwrite?)
  (export-png p png-path
              #:h-repeats h
              #:v-repeats v
              #:cell-size cell-size
              #:margin margin)
  (when (file-exists? ks-path)
    (delete-file ks-path))
  (export-ks p ks-path)

  (make-immutable-hasheq
   (list (cons 'html html-path)
         (cons 'png png-path)
         (cons 'xml xml-path)
         (cons 'text text-path)
         (cons 'ks ks-path))))

(: normalise-output-directory (Path-String -> Path))
(define (normalise-output-directory dir)
  (define complete (path->complete-path dir))
  (cond
    [(directory-exists? complete) complete]
    [(file-exists? complete)
     (error 'export-pattern-bundle
            "Output directory ~a exists and is not a directory"
            (path->string complete))]
    [else
     (make-directory* complete)
     complete]))

(: ensure-writable (Path Boolean -> Void))
(define (ensure-writable path overwrite?)
  (when (and (not overwrite?)
             (file-exists? path))
    (error 'export-pattern-bundle
           "File ~a exists; use #:overwrite? #t to replace it"
           (path->string path))))

(: determine-basename (Pattern (Option String) -> String))
(define (determine-basename p maybe-basename)
  (define raw-source
    (if maybe-basename
        maybe-basename
        (Pattern-name p)))
  (define raw (string-trim raw-source))
  (define fallback
    (if (zero? (string-length raw)) "pattern" raw))
  (define lowered (string-downcase fallback))
  (define replaced
    (regexp-replace* #px"[^0-9a-z]+" lowered "-"))
  (define collapsed
    (regexp-replace* #px"-+" replaced "-"))
  (define trimmed
    (regexp-replace* #px"(^-+|-+$)" collapsed ""))
  (if (string=? trimmed "")
      "pattern"
      trimmed))

(: render-html (Pattern Positive-Integer Positive-Integer -> String))
(define (render-html p h v)
  (define inputs : (Mutable-HashTable Symbol Integer)
    (make-hasheq))
  (hash-set! inputs 'stat 1)
  (hash-set! inputs 'hreps h)
  (hash-set! inputs 'vreps v)
  (hash-set! inputs 'zoom 80)
  (hash-set! inputs 'float 0)
  (hash-set! inputs 'notes 0)
  (hash-set! inputs 'yarn 0)
  (hash-set! inputs 'instr 0)
  (hash-set! inputs 'size 400)
  (define out (open-output-string))
  (pattern-template out p inputs)
  (get-output-string out))

(: render-xml-bytes (Pattern -> Bytes))
(define (render-xml-bytes p)
  (string->bytes/utf-8
   (srl:sxml->xml-noindent (pattern->sxml p))))

(: write-string-file (Path String Boolean -> Void))
(define (write-string-file path content overwrite?)
  (define out
    (open-output-file path
                      #:exists (if overwrite? 'truncate 'error)
                      #:mode 'text))
  (display content out)
  (close-output-port out))

(: write-bytes-file (Path Bytes Boolean -> Void))
(define (write-bytes-file path content overwrite?)
  (define out
    (open-output-file path
                      #:exists (if overwrite? 'truncate 'error)
                      #:mode 'binary))
  (write-bytes content out)
  (close-output-port out))

(: write-instructions-file (Path String Boolean -> Void))
(define (write-instructions-file path instructions overwrite?)
  (define out
    (open-output-file path
                      #:exists (if overwrite? 'truncate 'error)
                      #:mode 'text))
  (define len (string-length instructions))
  (when (> len 0)
    (display instructions out)
    (unless (char=? (string-ref instructions (sub1 len)) #\newline)
      (newline out)))
  (close-output-port out))

;; end
