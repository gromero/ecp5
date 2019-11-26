#!/bin/bash
yosys -p "synth_ecp5 -json raw_serial.json" raw_serial.v
nextpnr-ecp5 --json raw_serial.json --textcfg raw_serial_out.config --um5g-85k --package CABGA381 --lpf raw_serial.lpf --freq 4
ecppack --svf raw_serial.svf raw_serial_out.config raw_serial.bit
sudo --preserve-env=PATH env openocd -f ./ecp5.cfg -c "transport select jtag; init; svf raw_serial.svf; exit"
