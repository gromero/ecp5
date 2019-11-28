CC=g++
CC_FLAGS=-lwiringPi

all:	led fifo uart

led:	led.o
	$(CC) led.c -o led $(CC_FLAGS)

fifo:	fifo.c
	$(CC) fifo.c -o fifo $(CC_FLAGS)

uart:	uart.c
	$(CC) uart.c -o uart $(CC_FLAGS)

passthrough.json: passthrough.v
	yosys -p "synth_ecp5 -json $@" $<

passthrough_out.config: passthrough.json passthrough.lpf
	nextpnr-ecp5 --json passthrough.json --textcfg passthrough_out.config --um5g-85k --package CABGA381 --lpf passthrough.lpf

passthrough.bitstream: passthrough_out.config
	ecppack --svf passthrough.svf passthrough_out.config passthrough.bit

prog: passthrough.bitstream
	sudo --preserve-env=PATH env openocd -f ./ecp5.cfg -c "transport select jtag; init; svf passthrough.svf; exit"

clean:
	-rm -fr led.o
	-rm -fr led
	-rm -fr passthrough.bit passthrough.json passthrough.svf passthrough_out.config
	-rm -fr fifo.o fifo

.PHONY: passthrough.json
