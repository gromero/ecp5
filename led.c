#include <wiringPi.h>
#include <stdio.h>
#include <stdlib.h>

int main(void) {
  int ret;
  int leds[] = { 7, 21, 22, 10, 11, 13, 12, 1 };
  int leds_num = 8;
  int led;
  int i;

  ret = wiringPiSetup();
  if (ret < 0) {
    printf("wiringPiSetup(): error initializing wiringPi\n");
    exit(-1);
  }

  printf("------\n");
  for (i = 0; i < leds_num; i++) {
    // LED index to BMC pin
    led = leds[i];

    printf("Settting GPIO %d as OUTPUT\n", led);
    pinMode(led, OUTPUT);
  }
  printf("------\n");

  while(1) {
    for (i = 0; i < leds_num; i++) {
      led = leds[i];

      digitalWrite(led, LOW);
      printf("GPIO %d is ON\n", led);
      delay(100);
      digitalWrite(led, HIGH);
      printf("GPIO %d is OFF\n", led);
      delay(100);
    }
  }
}
