#!/bin/bash
iverilog -o x uart_tl.v &&
vvp -n x &&
gtkwave ./uart_dumpfile.vcd
