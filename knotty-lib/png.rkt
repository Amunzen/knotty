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

(require typed/racket/draw
         racket/fixnum)
(require "global.rkt"
         "util.rkt"
         "colors.rkt"
         "stitch.rkt"
         "yarn.rkt"
         "tree.rkt"
         "macros.rkt"
         "rows.rkt"
         "rowspec.rkt"
         "rowmap.rkt"
         "rowcount.rkt"
         "gauge.rkt"
         "options.rkt"
         "repeats.rkt"
         "pattern.rkt"
         "chart.rkt"
         "chart-row.rkt")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Imports PNG file as Pattern struct.
(: import-png (->* (Path-String)
                   (#:name String
                    #:url String
                    #:attribution (Listof Author)
                    #:keywords (Listof String)
                    #:technique Technique
                    #:form Form
                    #:face Face
                    #:side Side
                    #:gauge (Option Gauge)
                    #:row-repeats (U False Positive-Integer (List Positive-Integer Positive-Integer))
                    #:imports-with (Path-String Symbol -> (Instance Bitmap%)))
                   Pattern))
(define (import-png
         filename
         #:name [name (let-values ([(a b c) (split-path filename)])
                        (if (path? b) (path->string b) (symbol->string b)))]
         #:url [url ""]
         #:attribution [attribution null]
         #:keywords [keywords null]
         #:technique [technique default-pattern-technique]
         #:form [form default-pattern-form]
         #:face [face default-pattern-face]
         #:side [side default-pattern-side]
         #:gauge [gauge #f]
         #:row-repeats [row-repeats #f]
         #:imports-with [read-bitmap read-bitmap])
  (let ([bitmap (read-bitmap filename 'png)])
    (bitmap->pattern
     bitmap
     #:name name
     #:url url
     #:attribution attribution
     #:keywords keywords
     #:technique technique
     #:form form
     #:face face
     #:side side
     #:gauge gauge
     #:row-repeats row-repeats)))

;; Converts PNG file to Knotty pattern.
;; * Fair Isle hand knit flat
;; * max 256 yarns
(: bitmap->pattern (->* ((Instance Bitmap%))
                        (#:name String
                         #:url String
                         #:attribution (Listof Author)
                         #:keywords (Listof String)
                         #:technique Technique
                         #:form Form
                         #:face Face
                         #:side Side
                         #:gauge (Option Gauge)
                         #:row-repeats (U False Positive-Integer (List Positive-Integer Positive-Integer)))
                        Pattern))
(define (bitmap->pattern
         bitmap
         #:name [name ""]
         #:url [url ""]
         #:attribution [attribution null]
         #:keywords [keywords null]
         #:technique [technique default-pattern-technique]
         #:form [form default-pattern-form]
         #:face [face default-pattern-face]
         #:side [side default-pattern-side]
         #:gauge [gauge #f]
         #:row-repeats [row-repeats #f])
  (let* ([hand?  : Boolean (eq? technique 'hand)]
         [flat?  : Boolean (eq? form 'flat)]
         [rs?    : Boolean (eq? face 'rs)]
         [right? : Boolean (eq? side 'right)]
         [w : Positive-Integer (send bitmap get-width)]
         [h : Positive-Integer (send bitmap get-height)]
         [n : Positive-Integer (* w h)] ;; total number of pixels/stitches
         [argb (make-bytes (* n 4))]
         [sts (make-bytes n)]
         [st-rows : (HashTable Bytes (Listof Positive-Integer)) (make-hasheq)]
         [yarn-palette : (HashTable Nonnegative-Fixnum Byte) (make-hasheq)]
         [palette-counts : (HashTable Nonnegative-Fixnum Positive-Integer) (make-hasheq)]
         [yarn-numbers : (HashTable Byte Byte) (make-hasheq)])
    (send bitmap get-argb-pixels 0 0 w h argb)
    ;; extract stitch data from image
    (let process-image ([row   : Integer 1]
                        [st    : Integer 1]
                        [i     : Integer (* 4 (- n (if right? 1 w)))]
                        [j     : Integer 0]
                        [r2l?  : Boolean right?])
      (cond
        [(> row h) #t] ;; finished
        [(> st w) ;; next row
         (if (and hand? flat?)
             (process-image (add1 row)
                            1
                            (- i (* 4 w) (if r2l? -4 4))
                            j
                            (not r2l?))
             (process-image (add1 row)
                            1
                            (- i (* 8 (if right? 0 w)))
                            j
                            right?))]
        [else ;; next stitch
         (let ([c (rgb->color (bytes-ref argb (+ i 1))    ;; r
                              (bytes-ref argb (+ i 2))    ;; g
                              (bytes-ref argb (+ i 3)))]) ;; b
           (if (hash-has-key? yarn-palette c)
               (hash-set! palette-counts c (add1 (hash-ref palette-counts c)))
               (let ([n (hash-count yarn-palette)])
                 (when (> n #xFF)
                   (err SAFE "too many colors in png"))
                 (begin
                   (hash-set! yarn-palette c (bitwise-and n #xFF))
                   (hash-set! palette-counts c 1))))
           (bytes-set! sts j (hash-ref yarn-palette c))
           (process-image row
                          (add1 st)
                          (- i (if r2l? 4 -4))
                          (add1 j)
                          r2l?))]))
    ;; collate yarn data
    ;; set main color yarn = most frequent
    (let* ([colors (hash-keys palette-counts)]
           [color-names (map rgb->name colors)]
           [main-color (list-ref colors
                                 (argmax (λ ([i : Natural]) (hash-ref palette-counts (list-ref colors i)))
                                         (range (length colors))))]
           [main-yarn : Byte (hash-ref yarn-palette main-color)]
           [main-color-name (rgb->name main-color)]
           [yrns ((inst make-vector Yarn) (length colors) default-yarn)]
           [color-names : (HashTable String Natural) (make-hash)])
      (hash-set! color-names main-color-name 1)
      (vector-set! yrns 0 (yarn main-color main-color-name))
      (for ([c : Nonnegative-Fixnum (in-list colors)])
        (let* ([n : Byte (hash-ref yarn-palette c)]
               [y : Byte (cond [(< main-yarn n) n]
                               [(> main-yarn n) (byte-sum n 1)]
                               [else 0])])
          ;; renumber yarn
          (hash-set! yarn-numbers y n)
          ;; assign yarn name
          (unless (zero? y)
            ;; assign yarn name
            (let ([color-name (rgb->name c)])
              (if (not (hash-has-key? color-names color-name))
                  (begin
                    (hash-set! color-names color-name 1)
                    (vector-set! yrns y (yarn c color-name)))
                  (let* ([name-count (add1 (hash-ref color-names color-name))]
                         [color-name~ (format "~a (~a)" color-name name-count)])
                    (hash-set! color-names color-name name-count)
                    (vector-set! yrns y (yarn c color-name~))))))))
      ;; split data into rows
      (for ([r0 : Natural (in-range h)]) ;; 0-indexed
        (let* ([r1 : Positive-Integer (add1 r0)] ;; 1-indexed
               [st-data (bytes-append
                         (make-bytes 1 (if (row-rs? hand? flat? rs? r1)
                                           #x6B   ;; k
                                           #x70)) ;; p
                         (subbytes sts
                                   (* r0 w)
                                   (* r1 w)))])
          (if (hash-has-key? st-rows st-data)
              (hash-set! st-rows st-data (cons r1 (hash-ref st-rows st-data)))
              (hash-set! st-rows st-data (list r1)))))
      ;; format rows
      (let* ([pattern-rows (let get-pattern-rows : (Listof Rows) ([srs (hash-keys st-rows)]
                                                                  [krs : (Listof Rows) null])
                             (if (null? srs)
                                 krs
                                 (let* ([sr (car srs)]
                                        [st (bytes-ref sr 0)]
                                        [scs (let stitch-clusters : (Listof Tree) ([rle (run-length-encode (subbytes sr 1))]
                                                                                   [t : (Listof Tree) null])
                                               (if (null? rle)
                                                   (reverse t)
                                                   (let* ([run (car rle)]
                                                          [n (car run)]
                                                          [y (hash-ref yarn-numbers (cdr run))]
                                                          [sc (if (= st #x6B)
                                                                  ((with-yarn y) (k n))
                                                                  ((with-yarn y) (p n)))])
                                                     (stitch-clusters ((inst cdr (Pairof Positive-Integer Byte)) rle)
                                                                      ((inst cons Tree (Listof Tree)) sc t)))))]
                                        [kr (Rows (hash-ref st-rows sr)
                                                  (make-rowspec (treelike->tree scs)))])
                                   (get-pattern-rows (cdr srs)
                                                     ((inst cons Rows (Listof Rows)) kr krs)))))]
             [rowspecs~ (list->vector
                        (map (λ ([x : Rows])
                               (Rows-rowspec x))
                             pattern-rows))]
             [rowmap~ (make-rowmap
                       (vector->immutable-vector
                        ((inst list->vector (Vectorof Positive-Integer))
                         (map (λ ([x : Rows])
                                (vector->immutable-vector
                                 ((inst list->vector Positive-Integer)
                                  (Rows-rownums x))))
                              pattern-rows))))]
             [rowcounts~ (make-rowcounts rowspecs~ rowmap~)]
             [options~ (Options
                        technique
                        form
                        face
                        side
                        gauge)]
             [p (Pattern name
                 url
                 attribution
                 keywords
                 rowspecs~
                 rowmap~
                 rowcounts~
                 h
                 options~
                 dummy-repeats
                 (rowspecs-max-yarns-used rowspecs~)
                 yrns)])
          (struct-copy Pattern p
                       [repeats (pattern-make-repeats p row-repeats)])))))

;; Run length encoding for PNG.
(: run-length-encode : Bytes -> (Listof (Pairof Positive-Integer Byte)))
(define (run-length-encode b)
  (let ([n (bytes-length b)])
    (let loop ([i (- n 2)]
               [c : Byte (bytes-ref b (sub1 n))]
               [k : Positive-Integer 1]
               [v : (Listof (Pairof Positive-Integer Byte)) null])
      (if (negative? i) ((inst cons (Pairof Positive-Integer Byte) (Listof (Pairof Positive-Integer Byte)))
                         ((inst cons Positive-Integer Byte) k c) v)
          (let ([x : Byte (bytes-ref b i)])
            (if (= c x) (loop (sub1 i) c (add1 k) v)
                (loop (sub1 i) x 1 ((inst cons (Pairof Positive-Integer Byte) (Listof (Pairof Positive-Integer Byte)))
                                    ((inst cons Positive-Integer Byte) k c) v))))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Helpers for PNG export.

(: fixnum->byte : Fixnum -> Byte)
(define (fixnum->byte n)
  (if (or (< n 0) (> n 255))
      (error 'export-png "invalid channel value ~a" n)
      (cast n Byte)))

(: color-components : Nonnegative-Fixnum -> (Values Byte Byte Byte))
(define (color-components c)
  (values (fixnum->byte (fxand (fxrshift c 16) #xFF))
          (fixnum->byte (fxand (fxrshift c 8) #xFF))
          (fixnum->byte (fxand c #xFF))))

(: draw-strikethrough : (Instance DC<%>) Real Real Real Real (Instance Pen%) -> Void)
(define (draw-strikethrough dc x y w h strike-pen)
  (send dc set-pen strike-pen)
  (send dc draw-line x (+ y (/ h 2.0)) (+ x w) (+ y (/ h 2.0))))

(: make-font-for-cell : Positive-Integer -> (Instance Font%))
(define (make-font-for-cell cell-size)
  (define font-size
    (max 10
         (inexact->exact
          (round (* (real->double-flonum cell-size) 0.6)))))
  (make-object font% font-size 'modern))

(: hex->brush : Nonnegative-Fixnum -> (Instance Brush%))
(define (hex->brush color)
  (let-values ([(r g b) (color-components color)])
    (make-object brush% (make-object color% r g b) 'solid)))

(: pattern->bitmap (->* (Pattern)
                        (Positive-Integer Positive-Integer Positive-Integer Nonnegative-Integer)
                        (Instance Bitmap%)))
(define (pattern->bitmap p
                         [h-repeats 1]
                         [v-repeats 1]
                         [cell-size 36]
                         [margin 2])
  (define chart (pattern->chart p h-repeats v-repeats))
  (define rows (Chart-rows chart))
  (define width (* (Chart-width chart) cell-size))
  (define height (* (Chart-height chart) cell-size))
  (define total-width (+ width (* 2 margin)))
  (define total-height (+ height (* 2 margin)))
  (define bmp (make-object bitmap% total-width total-height))
  (define dc (new bitmap-dc% [bitmap bmp]))
  (send dc clear)
  (send dc set-brush "white" 'solid)
  (send dc set-pen "white" 1 'transparent)
  (send dc draw-rectangle 0 0 total-width total-height)
  (define yarns (Chart-yarns chart))
  (define symbol-font (make-font-for-cell cell-size))
  (define border-pen (make-object pen% "black" 1 'solid))
  (define strike-pen (make-object pen% "red" 2 'solid))
  (define cache-brushes : (HashTable Nonnegative-Fixnum (Instance Brush%)) (make-hasheq))
  (: brush-for : Nonnegative-Fixnum -> (Instance Brush%))
  (define (brush-for color)
    (hash-ref! cache-brushes
               color
               (λ () (hex->brush color))))
  (: resolve-yarn-color : Stitch Chart-row -> Nonnegative-Fixnum)
  (define (resolve-yarn-color st row)
    (let* ([y (Stitch-yarn st)]
           [dy : Byte (Chart-row-default-yarn row)]
           [idx : Byte (if (false? y) dy y)]
           [i : Nonnegative-Fixnum (cast idx Nonnegative-Fixnum)])
      (if (>= i (vector-length yarns))
          default-yarn-color
          (Yarn-color (vector-ref yarns i)))))
  (for ([row-index (in-range (Chart-height chart))])
    (define row : Chart-row (vector-ref rows (- (Chart-height chart) row-index 1)))
    (define base-y (+ margin (* row-index cell-size)))
    (define align-left (Chart-row-align-left row))
    (define align-right (Chart-row-align-right row))
    (define stitches : (Vectorof Stitch) (Chart-row-stitches row))
    (define rs? (Chart-row-rs? row))
    (define row-symbols (vector-length stitches))
    (: draw-cell : Integer Nonnegative-Fixnum String String Boolean Boolean -> Void)
    (define (draw-cell column color-val text text-color blank? nostitch?)
      (define base-x (+ margin (* column cell-size)))
      (send dc set-brush (brush-for color-val))
      (send dc set-pen border-pen)
      (send dc draw-rectangle base-x base-y cell-size cell-size)
      (cond
        [blank?
         (draw-strikethrough dc base-x base-y cell-size cell-size strike-pen)
         (send dc set-pen border-pen)]
        [nostitch?
         (void)]
        [else
         (when (> (string-length text) 0)
           (send dc set-text-foreground text-color)
           (send dc set-font symbol-font)
           (let-values ([(tw th _descent _leading)
                         (send dc get-text-extent text symbol-font)])
             (define tx (+ base-x (/ (- cell-size tw) 2.0)))
             (define ty (+ base-y (/ (- cell-size th) 2.0)))
             (send dc draw-text text tx ty)))]))
    ;; leading blanks (no stitch)
    (for ([c (in-range align-left)])
      (draw-cell c #xEEEEEE "" "#888888" #f #t))
    ;; actual stitches
    (for ([i (in-range row-symbols)])
      (define st : Stitch (vector-ref stitches i))
      (define sym (Stitch-symbol st))
      (define blank? (eq? sym 'na))
      (define nostitch? (eq? sym 'ns))
      (define color
        (cond
          [nostitch? #xEEEEEE]
          [blank? #xFFFFFF]
          [else (resolve-yarn-color st row)]))
      (define text-bytes
        (let ([st-type (get-stitchtype sym)])
          (cond
            [blank? #""]
            [rs? (Stitchtype-rs-string st-type)]
            [else (Stitchtype-ws-string st-type)])))
      (define text
        (let ([s (bytes->string/utf-8 text-bytes)])
          (if (string=? s "") (symbol->string sym) s)))
      (define text-color
        (if (or nostitch? blank?) "#000000"
            (contrast-color-hex (hex-color color))))
      (draw-cell (+ align-left i) color text text-color blank? nostitch?))
    ;; trailing blanks (no stitch)
    (for ([c (in-range align-right)])
      (draw-cell (+ align-left row-symbols c) #xEEEEEE "" "#888888" #f #t)))
  (send dc set-bitmap #f)
  bmp)

;; Exports pattern as PNG image.
(: export-png (->* (Pattern Path-String)
                   (#:h-repeats Positive-Integer
                    #:v-repeats Positive-Integer
                    #:cell-size Positive-Integer
                    #:margin Nonnegative-Integer)
                   Void))
(define (export-png p filename
                    #:h-repeats [h 1]
                    #:v-repeats [v 1]
                    #:cell-size [cell-size 36]
                    #:margin [margin 2])
  (define bmp (pattern->bitmap p h v cell-size margin))
  (unless (send bmp save-file filename 'png)
    (error 'export-png "failed to save png to ~a" filename)))

;; end
