#!/bin/bash
yosys -p "synth_ecp5 -json main.json" main.v
nextpnr-ecp5 --json main.json --textcfg main_out.config --um5g-85k --package CABGA381 --lpf main.lpf --freq 4 # XXX: freq = 4 just to make router pass wo/ error!
ecppack --svf main.svf main_out.config main.bit
