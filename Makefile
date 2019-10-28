CC=g++
CC_FLAGS=-lwiringPi

led:	led.o
	$(CC) led.c -o led $(CC_FLAGS)

clean:
	rm led.o
	rm led
