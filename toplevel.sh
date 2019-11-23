#!/bin/bash
yosys -p "synth_ecp5 -json toplevel.json" toplevel.v
