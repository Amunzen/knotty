# Knotty

Domain Specific Language for knitting patterns

[![Coverage Status](https://coveralls.io/repos/github/t0mpr1c3/knotty/badge.svg?branch=main)](https://coveralls.io/github/t0mpr1c3/knotty?branch=main)

[Documentation](https://t0mpr1c3.github.io/knotty/index.html)

## Description

Grid-based editors are handy for colorwork.
[Knitspeak](https://stitch-maps.com/about/knitspeak/) is great for lace.
Knotty aims for the best of both worlds. It's a way to design knitting patterns
that incorporate both textured stitches and multiple colors of yarn.

## Features

Knotty patterns are encoded in a format that is easy for humans to write and parse,
but is also highly structured.

Patterns can be viewed and saved in an HTML format that contains an interactive
knitting chart and written instructions. You can also import and export Knitspeak
files, and create Fair Isle patterns directly from color graphics.

Knotty has been coded as a module for
[Typed Racket](https://docs.racket-lang.org/ts-guide/). Reference information
is available in the [manual](https://t0mpr1c3.github.io/knotty/index.html).

A [Knotty executable](https://github.com/t0mpr1c3/knotty/releases) is also
available that can be used from the command line to convert knitting patterns from
one format to another. In addition to HTML and XML conversion, the CLI can now
export static PNG charts. For example:

```
racket knotty-lib/cli.rkt \
  --import-xml --export-png \
  --output lattice-chart \
  knotty-lib/resources/example/lattice
```

This writes `lattice-chart.png` alongside any copied CSS/JS assets.

### Programmatic conversion examples

You can also script conversions directly in Racket. The following examples assume
`lattice.xml` from `knotty-lib/resources/example/`.

```racket
#lang racket
(require knotty-lib)

(define pattern
  (import-xml "knotty-lib/resources/example/lattice.xml"))

;; save a copy of the source XML
(export-xml pattern "lattice-copy.xml")

;; write a standalone HTML chart and written instructions
(export-html pattern "lattice.html" 1 1)

;; render a PNG chart (repeat horizontally 2x, vertically 2x)
(export-png pattern "lattice.png" #:h-repeats 2 #:v-repeats 2)
```

## Getting Started

Clone [this repository](https://github.com/t0mpr1c3/knotty).

Download the latest version of [Racket](https://download.racket-lang.org/)
for your operating system. It comes with the graphical application DrRacket.
Open DrRacket and select the menu option "File > Install Package". Type
"knotty" into the text box and press "Install".

Open the test script `demo.rkt` from the `knotty-lib` directory of the repository
and press "Run" in the top right of the window. The demonstration script contains
a very short knitting pattern, together with many lines of comments describing how
to go about making your own.
