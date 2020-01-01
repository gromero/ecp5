#!/bin/bash
iverilog -o outz t_port.v t_port_tl.v &&
vvp -n outz &&
gtkwave ./t_port_dumpfile.vcd
