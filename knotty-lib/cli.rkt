#! /usr/bin/env racket
#lang racket

#|
    Knotty, a domain specific language for knitting patterns.
    Copyright (C) 2021-3 Tom Price

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
|#

(module+ main
  ;; Main submodule.
  ;; This code is executed when this file is run using DrRacket or the `racket` executable.
  ;; The code does not run when the file is required by another module.
  ;; Documentation: http://docs.racket-lang.org/guide/Module_Syntax.html#%28part._main-and-test

  (require racket/cmdline
           racket/system        ;; for XSLT system calls
           racket/path
           syntax/parse/define  ;; for `define-syntax-parse-rule`
           sxml/sxpath)
  (require "global.rkt"
           "util.rkt"
           "stitch.rkt"
           "tree.rkt"
           "yarn.rkt"
           "macros.rkt"
           "rows.rkt"
           "rowspec.rkt"
           "rowmap.rkt"
           "gauge.rkt"
           "options.rkt"
           "pattern.rkt"
           "xml.rkt"
           "png.rkt"
           "export-bundle.rkt"
           ;"dak.rkt"
           "knitspeak.rkt"
           "serv.rkt"
           "gui.rkt")

  ;; Obtains the arguments from `command-line`
  ;; and runs the executable.
  (define (cli-handler flags . positional)
    (define filestem-arg (if (null? positional) #f (car positional)))
    (let* (#|
           [input-suffix (path-get-extension input-filename)]
           [import-xml? (equal? #".xml" input-suffix)]
           [import-png? (equal? #".png" input-suffix)]
           [import-stp? (equal? #".stp" input-suffix)]
           [import-dak? (equal? #".dak" input-suffix)]
           [output-suffix (path-get-extension output-filename)]
           [export-xml? (equal? #".xml" output-suffix)]
           [export-stp? (equal? #".stp" output-suffix)]
           [export-dak? (equal? #".dak" output-suffix)]
           |#
           [invalid-input "invalid input file format"]
           [flags~ (cons '*TOP* flags)]
           ;[import-dak?      (equal? '((import-dak? #t))      ((sxpath "/import-dak?")      flags~))]
           [import-ks?       (equal? '((import-ks? #t))       ((sxpath "/import-ks?")       flags~))]
           [import-png?      (equal? '((import-png? #t))      ((sxpath "/import-png?")      flags~))]
           ;[import-stp?      (equal? '((import-stp? #t))      ((sxpath "/import-stp?")      flags~))]
           [import-xml?      (equal? '((import-xml? #t))      ((sxpath "/import-xml?")      flags~))]
           ;[export-dak?      (equal? '((export-dak? #t))      ((sxpath "/export-dak?")      flags~))]
           [export-html?     (equal? '((export-html? #t))     ((sxpath "/export-html?")     flags~))]
           [export-png?      (equal? '((export-png? #t))      ((sxpath "/export-png?")      flags~))]
           [export-bundle?   (equal? '((export-bundle? #t))   ((sxpath "/export-bundle?")   flags~))]
           [export-ks?       (equal? '((export-ks? #t))       ((sxpath "/export-ks?")       flags~))]
           ;[export-stp?      (equal? '((export-stp? #t))      ((sxpath "/export-stp?")      flags~))]
           [export-xml?      (equal? '((export-xml? #t))      ((sxpath "/export-xml?")      flags~))]
           [force?           (equal? '((force? #t))           ((sxpath "/force?")           flags~))]
           ;[generic-matches? (equal? '((generic-matches? #t)) ((sxpath "/generic-matches?") flags~))]
           [safe?       (not (equal? '((unsafe? #t))          ((sxpath "/unsafe?")          flags~)))]
           [quiet?           (equal? '((quiet? #t))           ((sxpath "/quiet?")           flags~))]
           [verbose?         (equal? '((verbose? #t))         ((sxpath "/verbose?")         flags~))]
           [debug?           (equal? '((debug? #t))           ((sxpath "/debug?")           flags~))]
           [webserver?       (equal? '((webserver? #t))       ((sxpath "/webserver?")       flags~))]
           [output                                            ((sxpath "/output")           flags~)]
           [input-option                                     ((sxpath "/input")            flags~)]
           [repeats                                           ((sxpath "/repeats")          flags~)]
           [explicit-input (and (not (null? input-option)) (cadar input-option))]
           [filestem-path
            (let* ([raw (cond
                         [(and filestem-arg (not (string=? filestem-arg "")))
                          (string->path filestem-arg)]
                         [explicit-input (string->path explicit-input)]
                         [else
                          (error 'knotty
                                 "missing input path; provide --input or a positional filename")])]
                   [ext (path-get-extension raw)])
              (if (and ext (> (bytes-length ext) 0))
                  (path-replace-extension raw #"")
                  raw))]
           [output-filestem (if (null? output)
                                filestem-path
                                (string->path (cadar output)))])

      ;; set logging level
      (define lvl (cond [quiet? 'none]
                        [debug? 'debug]
                        [verbose? 'info]
                        [else 'warning]))
      (define log-receiver-thread
        ((setup-log-receiver lvl)))
      (dlog (format "Set up log receiver thread ~a with level ~a"
                    log-receiver-thread
                    lvl))

      ;; set parameter value
      (SAFE safe?)

      (ilog (format "Knotty version ~a run with options:" knotty-version))
      #|
      (when import-dak?
        (ilog "  --import-dak"))
      |#
      (when import-ks?
        (ilog "  --import-ks"))
      (when import-png?
        (ilog "  --import-png"))
      #|
      (when import-stp?
        (ilog "  --import-stp"))
      |#
      (when import-xml?
        (ilog "  --import-xml"))
      #|
      (when export-dak?
        (ilog "  --export-dak"))
      |#
      (when export-html?
        (ilog "  --export-html"))
      (when export-bundle?
        (ilog "  --export-bundle"))
      (when export-png?
        (ilog "  --export-png"))
      (when export-ks?
        (ilog "  --export-ks"))
      #|
      (when export-png?
        (ilog "  --export-png"))
      (when export-stp?
        (ilog "  --export-stp"))
      |#
      (when export-xml?
        (ilog "  --export-xml"))
      (when quiet?
        (ilog "  --quiet"))
      (when verbose?
        (ilog "  --verbose"))
      (when debug?
        (ilog "  --debug"))
      (when force?
        (ilog "  --force"))
      (when (not (null? output))
        (ilog (format "  --output ~a"
                      output-filestem)))
      (when (not (null? repeats))
        (ilog (format "  --repeats ~a ~a"
                      (cadar repeats)
                      (caddar repeats))))
      #|
      (when generic-matches?
        (ilog "  --generic-matches"))
      |#
      (unless safe?
        (ilog "  --unsafe"))
      (when webserver?
        (ilog "  --web"))
      (dlog "in `cli-handler` with:")
      (dlog (format "command line flags=~a" flags))

      #|
        ;; (de)obfuscate DAK files
        (when (or (and import-dak? export-stp?)
                  (and import-stp? export-dak?))
          (let* ([in-suffix  (if import-stp? #".stp" #".dak")]
                 [out-suffix (if export-stp? #".stp" #".dak")]
                 [in-file-path  (path-replace-extension filestem-path in-suffix)]
                 [out-file-path (path-replace-extension output-filestem out-suffix)]
                 [in  (open-input-file  in-file-path)]
                 [out (open-output-file out-file-path)]
                 [data (port->bytes in)])
            (replace-file-if-forced force?
                                    out-file-path
                                    (thunk (write-bytes (de/obfuscate data import-stp?) out)
                                           (close-output-port out))
                                    (if export-stp? "stp" "dak"))))
        |#

      ;; convert format / launch webserver
      (when (or import-ks?
                import-png?
                (and import-xml?
                     (or ;export-dak?
                         export-html?
                         export-png?
                         export-bundle?
                         ;export-stp?
                         webserver?)))
        #|
                  (and (or import-dak?
                           import-stp?)
                       (or export-html?
                           export-text?
                           export-xml?
                           webserver?)))
          |#
        (let* ([input-filename-helper
                (lambda (ext)
                  (if explicit-input
                      (string->path explicit-input)
                      (path-replace-extension filestem-path ext)))]
               [input-filename
                (cond ;[import-dak? (input-filename-helper #".dak")]
                  [import-ks?  (input-filename-helper #".ks")]
                  [import-png? (input-filename-helper #".png")]
                  ;[import-stp? (input-filename-helper #".stp")]
                  [import-xml? (input-filename-helper #".xml")]
                  [else (error invalid-input)])]
               [p
                (cond ;[import-dak? (import-dak input-filename generic-matches? #f)]
                  [import-ks?  (import-ks  input-filename)]
                  [import-png? (import-png input-filename)]
                  ;[import-stp? (import-stp input-filename generic-matches?)]
                  [import-xml? (import-xml input-filename)]
                  [else (error invalid-input)])]
               [import-kind
                (cond
                  [import-ks? 'ks]
                  [import-png? 'png]
                  [import-xml? 'xml]
                  [else #f])]
                [import-kind
                 (cond
                   [import-ks? 'ks]
                   [import-png? 'png]
                   [import-xml? 'xml]
                   [else #f])]
                [repeats-h (if (null? repeats) 1 (cadar repeats))]
                [repeats-v (if (null? repeats) 1 (caddar repeats))])
          (ilog (format "  input ~a" (path->string input-filename)))
          (ilog (format "  output-base ~a" (path->string output-filestem)))
          #|
            (when export-dak?
              (let ([out-file-path (path-replace-extension output-filestem #".dak")])
                (replace-file-if-forced force?
                                        out-file-path
                                        (thunk (export-stp p out-file-path))
                                        "dak")))
            |#
          (when export-bundle?
            (let-values ([(base name dir?) (split-path output-filestem)])
              (when (symbol? name)
                (error 'knotty "invalid filename"))
              (let* ([dir (cond [(eq? 'relative base) "."]
                                [(false? base) "/"]
                                [else base])]
                     [basename (path->string name)])
                (define outputs
                  (export-pattern-bundle p dir
                                         #:basename basename
                                         #:overwrite? force?
                                         #:h-repeats repeats-h
                                         #:v-repeats repeats-v))
                (for ([(fmt path) (in-hash outputs)])
                  (ilog (format "    ~a -> ~a"
                                fmt
                                (path->string path))))
                (overwrite-files
                 (build-path resources-path "css")
                 (build-path dir "css")
                 '("knotty.css" "knotty-manual.css"))
                (overwrite-files
                 (build-path resources-path "js")
                 (build-path dir "js")
                 '("knotty.js"))
                (overwrite-files
                 (build-path resources-path "font")
                 (build-path dir "font")
                 '("StitchMasteryDash.ttf" "georgia.ttf"))
                (overwrite-files
                 (build-path resources-path "icon")
                 (build-path dir "icon")
                 '("favicon.ico"))
                (write-bundle-source dir basename force?
                                     import-kind input-filename
                                     repeats-h repeats-v))))
          (when (and export-html?
                     (not export-bundle?))
            (let-values ([(base name dir?) (split-path output-filestem)])
              (when (symbol? name)
                (error 'knotty "invalid filename"))
              (let* ([dir (cond [(eq? 'relative base) "."]
                                [(false? base) "/"]
                                [else base])]
                     [out-file-path (path-replace-extension output-filestem #".html")])
                (replace-file-if-forced force?
                                        out-file-path
                                        (thunk (export-html p out-file-path repeats-h repeats-v))
                                        "html")
                (overwrite-files
                 (build-path resources-path "css")
                 (build-path dir "css")
                 '("knotty.css" "knotty-manual.css"))
                (overwrite-files
                 (build-path resources-path "js")
                 (build-path dir "js")
                 '("knotty.js"))
                (overwrite-files
                 (build-path resources-path "font")
                 (build-path dir "font")
                 '("StitchMasteryDash.ttf" "georgia.ttf"))
                (overwrite-files
                 (build-path resources-path "icon")
                 (build-path dir "icon")
                 '("favicon.ico")))))
          (when (and export-png?
                     (not export-bundle?))
            (let ([out-file-path (path-replace-extension output-filestem #".png")])
              (replace-file-if-forced force?
                                      out-file-path
                                      (thunk (export-png p out-file-path
                                                         #:h-repeats repeats-h
                                                         #:v-repeats repeats-v))
                                      "png")))
          (when export-ks?
            (let ([out-file-path (path-replace-extension output-filestem #".ks")])
              (replace-file-if-forced force?
                                      out-file-path
                                      (thunk (export-ks p out-file-path))
                                      "ks")))
          #|
            (when export-stp?
              (let ([out-file-path (path-replace-extension output-filestem #".stp")])
                (replace-file-if-forced force?
                                        out-file-path
                                        (thunk (export-stp p out-file-path))
                                        "stp")))
            |#
          (when (and export-xml?
                     (not export-bundle?))
            (let ([out-file-path (path-replace-extension output-filestem #".xml")])
              (replace-file-if-forced force?
                                      out-file-path
                                      (thunk (export-xml p out-file-path))
                                      "xml")))
          (when webserver?
            (let ([h (if (null? repeats) 2 (cadar repeats))]
                  [v (if (null? repeats) 2 (caddar repeats))])
              (serve-pattern p h v)))))

      ;; send message to kill log receiver thread
      (thread-send log-receiver-thread 'time-to-stop)
      (dlog "Quitting Knotty")
      ;; wait for log receiver to finish before exiting
      (thread-wait log-receiver-thread)))

  ;; filesystem functions

  (define (move-file src-path dest-path)
    (copy-file src-path dest-path)
    (delete-file src-path))

  (define (overwrite-files src-dir-path dest-dir-path filenames)
    (unless (directory-exists? dest-dir-path)
      (make-directory dest-dir-path))
    (for ([f (in-list filenames)])
      (copy-file (build-path src-dir-path  f)
                 (build-path dest-dir-path f)
                 #:exists-ok? #t)))

  (define (bundle-script-content require-spec import-kind import-path basename repeats-h repeats-v)
    (define import-form
      (case import-kind
        [(xml) (format "(import-xml ~s)" import-path)]
        [(ks)  (format "(import-ks ~s)" import-path)]
        [(png) (format "(import-png ~s)" import-path)]
        [else "(error \"pattern source unavailable\")"]))
    (string-append
     "#lang racket\n\n"
     "(require racket/runtime-path\n"
     (format "         (file ~s))\n\n" require-spec)
     (format "(define-runtime-path source-path ~s)\n" import-path)
     (format "(define-runtime-path bundle-dir ~s)\n\n" ".")
     "(define pattern\n  (import-xml source-path))\n\n"
     "(keyword-apply export-pattern-bundle\n"
     "               '(#:basename #:h-repeats #:overwrite? #:v-repeats)\n"
     (format "               (list ~s ~a #t ~a)\n" basename repeats-h repeats-v)
     "               (list pattern bundle-dir))\n"))

  (define (write-bundle-source dir basename force? import-kind input-path repeats-h repeats-v)
    (when import-kind
      (define dir-abs (path->complete-path dir))
      (define input-abs (path->complete-path input-path))
      (define rel-input (find-relative-path dir-abs input-abs))
      (define import-path-str
        (if (path? rel-input)
            (path->string rel-input)
            (path->string input-abs)))
      (define main-path (simplify-path (build-path resources-path ".." "main.rkt")))
      (define rel-main (find-relative-path dir-abs main-path))
      (define require-spec
        (if (path? rel-main)
            (path->string rel-main)
            (path->string main-path)))
      (define script-content
        (bundle-script-content require-spec import-kind import-path-str basename repeats-h repeats-v))
      (define script-path (build-path dir (string-append basename ".rkt")))
      (replace-file-if-forced
       force?
       script-path
       (thunk
        (call-with-output-file script-path
          (lambda (out)
            (display script-content out)
            (newline out))
          #:exists 'replace))
       "rkt")))

  (define (replace-file-if-forced force? file-path thunk suffix)
    (let ([file-exists-msg "file ~a exists, use option --force to overwrite it"])
      (if (or (not force?)
              (not (file-exists? file-path)))
          ;; Unforced
          ;; Pretty error message if file exists
          (with-handlers
              ([exn:fail:filesystem:exists?
                (λ (e) (error 'knotty file-exists-msg file-path))])
            (thunk))
          ;; Forced
          ;; Moves file to be replaced to a temporary location
          ;; Restores file if an error occurs
          (let ([tmp-path (make-temporary-file (format "knotty~~a.~a" suffix))])
            (delete-file tmp-path)
            (move-file file-path tmp-path)
            (with-handlers
                ([exn:fail?
                  (λ (e)
                    (move-file tmp-path file-path)
                    (raise e))])
              (thunk))))))

  ;; Sets command line options for executable.
  (command-line
   #:program "knotty"
   #:usage-help
   "Knotty version KNOTTY-VERSION."
   "Knitting pattern viewer and converter."
   "More than one output format can be specified."

   ;; import format
   #:once-any
   #|
   [("-d" "--import-dak")
    "Import deobfuscated Designaknit .dak file"
    `(import-dak? #t)] ;; FIXME for testing purposes only. Comment out this option when ready for release.
   |#
   [("-k" "--import-ks")
    "Import Knitspeak .ks file"
    `(import-ks? #t)]
   [("-p" "--import-png")
    "Import graphical .png file"
    `(import-png? #t)]
   #|
   [("-s" "--import-stp")
    "Import Designaknit .stp file"
    `(import-stp? #t)]
   |#
   [("-x" "--import-xml")
    "Import Knotty XML file"
    `(import-xml? #t)]

   ;; export format
   #:once-each
   #|
   [("-D" "--export-dak")
    "Export deobfuscated Designaknit .dak file"
    `(export-dak? #t)] ;; FIXME for testing purposes only. Comment out this option when ready for release.
   |#
   [("-H" "--export-html")
    "Export chart and instructions as webpage"
    `(export-html? #t)]
   [("-B" "--export-bundle")
    "Export HTML, XML, text instructions, and PNG together"
    `(export-bundle? #t)]
   [("-K" "--export-ks")
    "Export Knitspeak .ks file"
    `(export-ks? #t)]
  [("-P" "--export-png")
   "Export color .png file"
    `(export-png? #t)]
   [("-R" "--export-racket")
    "Export Racket source file"
    `(export-rkt? #t)]
   #|
   [("-S" "--export-stp")
    "Export Designaknit .stp file"
    `(export-stp? #t)]
   |#
   [("-X" "--export-xml")
    "Export Knotty XML file"
    `(export-xml? #t)]

   ;; log settings
   #:once-any
   [("-q" "--quiet")
    "Turn off messages"
    `(quiet? #t)]
   [("-v" "--verbose")
    "Show detailed messages"
    `(verbose? #t)]
   [("-z" "--debug")
    "Show very verbose messages"
    `(debug? #t)]

   ;; other settings
   #:once-each
   [("-f" "--force")
    "Overwrite existing file(s) after conversion"
    `(force? #t)]
   #|
   [("-g" "--generic-matches")
    "Allow generic stitch matches when converting Designaknit .stp files"
    `(generic-matches? #t)]
   |#
  [("-o" "--output")
    output-filestem
    "Specify filename stem of exported files"
    `(output ,output-filestem)]
  [("-i" "--input")
    input-path
    "Specify input file (e.g., pattern.xml)"
    `(input ,input-path)]
  [("-r" "--repeats")
    hreps vreps ;; arguments for flag
    "Specify number of horizontal and vertical repeats in HTML output"
    `(repeats ,(string->positive-integer hreps)
              ,(string->positive-integer vreps))]
   [("-u" "--unsafe")
    "Override error messages"
    `(unsafe? #t)]
   [("-w" "--web")
    "View imported file as webpage"
    `(webserver? #t)]

   #:handlers
   cli-handler
   '("input-or-stem")))

;; end
