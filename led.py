#!/bin/python
import RPi.GPIO as GPIO
import time

interval = 0.1

# See passthrough.lpf for data_in[7:0] locates onto pins
#   LED 0, 1, 2, ...
leds = [4, 5, 6, 8, 7, 9, 10, 18]

print "------"
for ld in leds:
    print "Setting GPIO %d as output..." % ld
    GPIO.setmode(GPIO.BCM)
    GPIO.setwarnings(False)
    GPIO.setup(ld, GPIO.OUT)

print "------"

while (1):
    for ld in leds:
        print("GPIO %d on" % ld)
        GPIO.output(ld, GPIO.LOW)
        time.sleep(interval)

        print "GPIO %d off" % ld
        GPIO.output(ld, GPIO.HIGH)
        time.sleep(interval)
