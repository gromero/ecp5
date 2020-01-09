#!/bin/bash
iverilog -o x uart_sim_tl.v &&
vvp -n x &&
gtkwave ./uart_dumpfile.vcd
