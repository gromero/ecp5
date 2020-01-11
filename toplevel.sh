#!/bin/bash
yosys -p "synth_ecp5 -json toplevel.json" toplevel.v
nextpnr-ecp5 --json toplevel.json --textcfg toplevel_out.config --um5g-85k --package CABGA381 --lpf toplevel.lpf --freq 4 # XXX: freq = 4 just to make router pass wo/ error!
ecppack --svf toplevel.svf toplevel_out.config toplevel.bit
sudo --preserve-env=PATH env openocd -f ./ecp5.cfg -c "transport select jtag; init; svf toplevel.svf; exit"
