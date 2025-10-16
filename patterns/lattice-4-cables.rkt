#lang sweet-exp typed/racket

require "../knotty-lib/main.rkt"

provide lattice-4-cables

define lattice-4-cables
  pattern
    [name "Lattice with 4 Cables"]
    [form circular]
    rows(1 9)       repeat(p2 k2 p4 lc-2/2 p4 k2) p2
    rows(2 8 10 16) repeat(p2 k2 p4 k4 p4 k2) p2
    rows(3 11)      repeat(p2 lpc-2/2 rpc-2/2 lpc-2/2 rpc-2/2) p2
    rows(4 6 12 14) repeat(p4 k4 p4 k4 p2) p2
    rows(5 13)      repeat(p4 lc-2/2 p4 lc-2/2 p2) p2
    rows(7 15)      repeat(p2 rpc-2/2 lpc-2/2 rpc-2/2 lpc-2/2) p2
