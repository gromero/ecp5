#!/usr/bin/python

import serial

# configure the serial connections
ser = serial.Serial(
    port='/dev/ttyUSB1',
    baudrate=9600,
    parity=serial.PARITY_NONE,
    stopbits=serial.STOPBITS_ONE,
    bytesize=serial.EIGHTBITS
)


while 1:
    while ser.inWaiting() > 0:
        byte = ser.read(1);
        print("%s" %(byte))
