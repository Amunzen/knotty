#lang typed/racket

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

(provide (all-defined-out))
(require/typed sxml
               [sxml:modify ((Listof (U String Symbol (Sexp Any Sexp -> (U Sexp (Listof Sexp))) Sexp)) -> (Sexp -> Sexp))]
               [srl:sxml->xml (Sexp -> String)])
(require/typed html-parsing
               [html->xexp  (String -> Sexp)])
(require/typed html-writing
               [xexp->html  (Sexp -> String)])
(require racket/string
         "util.rkt"
         "pattern.rkt")
(require/typed "html.rkt"
               [pattern-template (->* (Output-Port Pattern (HashTable Symbol Integer)) (Boolean) Void)]
               [instructions-sxml (->* (Pattern) (Boolean) Sexp)])

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Displays pattern as written knitting instructions.
(: text : Pattern -> Void)
(define (text p)
  (display (pattern->text p)))

;; Formats pattern for text output.
(: pattern->text : Pattern -> String)
(define (pattern->text p)
  (transform-pattern-text
   (let ([s (open-output-string)]
         [i (make-hasheq
             '((hreps . 1)
               (vreps . 1)
               (zoom  . 1)
               (float . 0)
               (notes . 0)
               (yarn  . 0)
               (instr . 0)
               (size  . 0)))])
     (pattern-template s p i #t)
     (get-output-string s))))

;; first convert HTML template back to SXML
;; then use XSLT to convert SXML
;; and transform back to text
(: transform-pattern-text : String -> String)
(define (transform-pattern-text s)
  (regexp-replace
   #px"^\n"
   (remove-tags
   (xexp->html
    ((sxml:modify '("//tr" insert-following "\n"))
     ((sxml:modify '("//td//text()[normalize-space()]" insert-following " "))
      ((sxml:modify '("//tr/td[2]" insert-following "- "))
       ((sxml:modify '("//div[not(normalize-space())]" delete))
        ((sxml:modify '("//li" insert-following "\n"))
         ((sxml:modify '("//p" insert-following "\n"))
          ((sxml:modify '("//h3/text()[1]" insert-preceding "\n"))
           ((sxml:modify '("//h3/text()" insert-following ":\n"))
            ((sxml:modify '("//h1/text()" insert-following "\n"))
             ((sxml:modify '("//a" delete-undeep))
              ((sxml:modify '("//div[contains(@class, 'footer')]" delete))
               ((sxml:modify '("//div[contains(@class, 'form')]" delete))
                ((sxml:modify '("//div[contains(@class, 'figure')]" delete))
                 ((sxml:modify '("/script" delete))
                  ((sxml:modify '("/body" delete-undeep))
                   ((sxml:modify '("/head" delete))
                    ((sxml:modify '("/html" delete-undeep))
                     (html->xexp s))))))))))))))))))))
   ""))

;; Extracts only the instructions section from text export.
(: pattern->instructions-text : Pattern -> String)
(define (pattern->instructions-text p)
  (let* ([html (srl:sxml->xml (instructions-sxml p #t))]
         [with-breaks (regexp-replace* #px"</(h3|p|li)>" html "</\\1>\n")]
         [with-breaks (regexp-replace* #px"<div[^>]*>" with-breaks "\n")]
         [text (remove-tags with-breaks)]
         [collapsed (regexp-replace* #px"[ \t]+\n" text "\n")]
         [normalized (regexp-replace* #px"\n+" collapsed "\n")]
         [trimmed (string-trim normalized)]
         [splits (string-split trimmed "\n")]
         [parts (for/list : (Listof String) ([s (in-list splits)]
                                             #:when (> (string-length s) 0))
                  s)])
    (if (null? parts)
        ""
        (let* ([lines (cdr parts)]
               [trimmed-lines (map (λ ([line : String]) (string-trim line)) lines)]
               [clean-lines (for/list : (Listof String) ([line (in-list trimmed-lines)]
                                                         #:when (> (string-length line) 0))
                              line)])
          (if (null? clean-lines)
              ""
              (let ([body (string-join clean-lines "\n")])
                (if (zero? (string-length body))
                    ""
                    (string-append "Instructions:\n" body "\n"))))))))

;; Writes instructions to a plain-text file.
(: export-instructions (->* (Pattern Path-String)
                            (#:exports-with (Path-String -> Output-Port))
                            Void))
(define (export-instructions p filename
                             #:exports-with [open-output-file open-output-file])
  (let* ([instructions (pattern->instructions-text p)]
         [out (open-output-file filename)])
    (when (positive? (string-length instructions))
      (display instructions out)
      (unless (char=? (string-ref instructions (sub1 (string-length instructions))) #\newline)
        (newline out)))
    (close-output-port out)))

;; end
