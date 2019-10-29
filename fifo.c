#include <wiringPi.h>
#include <stdio.h>
#include <stdlib.h>

// DATA_OUT: from RPi3 ---- to ----> FPGA
// DATA_IN : from FPGA ---- to ----> RPi3
//
// I/O semantics for other signals is similar to DATA_OUT/IN.

#define CLK   6
#define RESET 26

#define EMPTY 23
#define FULL  15

#define PUSH  16
#define POP   27

#define BUS_SIZE 8

#define DATA_OUT0 7
#define DATA_OUT1 21
#define DATA_OUT2 22
#define DATA_OUT3 11
#define DATA_OUT4 10
#define DATA_OUT5 13
#define DATA_OUT6 12
#define DATA_OUT7 14

#define DATA_IN0 0
#define DATA_IN1 1
#define DATA_IN2 24
#define DATA_IN3 28
#define DATA_IN4 29
#define DATA_IN5 3
#define DATA_IN6 4
#define DATA_IN7 5

#define DELAY 100

int data_out[] = { DATA_OUT0, DATA_OUT1, DATA_OUT2, DATA_OUT3,
                   DATA_OUT4, DATA_OUT5, DATA_OUT6, DATA_OUT7 };

int data_in[] = { DATA_IN0, DATA_IN1, DATA_IN2, DATA_IN3,
                  DATA_IN4, DATA_IN5, DATA_IN6, DATA_IN7 };

void clock(void) {
  digitalWrite(CLK, LOW);
  delay(1);
  digitalWrite(CLK, HIGH);
  delay(2);
  digitalWrite(CLK, LOW);
  delay(1);
}

void set(int pin) {
  digitalWrite(pin, HIGH);
  delay(1);
}

void unset(int pin) {
  digitalWrite(pin, LOW);
  delay(1);
}

int get(int pin) {
  return digitalRead(pin);
}

void dataOut(int d) {
  int i;
  int bit;

  for (i = 0; i < BUS_SIZE; i++) {
    bit = (d >> i) & 0x1;
    digitalWrite(data_out[i], bit);
  }
}

int dataIn(void) {
  int i;
  int d = 0;
  int bit;

  for (i = BUS_SIZE-1; i >= 0; i--) {
    bit = digitalRead(data_in[i]);
    d |= bit << i;
  }
  return d;
}

int setupPins(void) {
  int r;

  r = wiringPiSetup();
  if (r < 0)
    return r;

  pinMode(CLK, OUTPUT);
  pinMode(RESET, OUTPUT);

  pinMode(EMPTY, INPUT);
  pinMode(FULL, INPUT);

  pinMode(PUSH, OUTPUT);
  pinMode(POP, OUTPUT);

  pinMode(DATA_OUT0, OUTPUT);
  pinMode(DATA_OUT1, OUTPUT);
  pinMode(DATA_OUT2, OUTPUT);
  pinMode(DATA_OUT3, OUTPUT);
  pinMode(DATA_OUT4, OUTPUT);
  pinMode(DATA_OUT5, OUTPUT);
  pinMode(DATA_OUT6, OUTPUT);
  pinMode(DATA_OUT7, OUTPUT);

  pinMode(DATA_IN0, INPUT);
  pinMode(DATA_IN1, INPUT);
  pinMode(DATA_IN2, INPUT);
  pinMode(DATA_IN3, INPUT);
  pinMode(DATA_IN4, INPUT);
  pinMode(DATA_IN5, INPUT);
  pinMode(DATA_IN6, INPUT);
  pinMode(DATA_IN7, INPUT);

  return 0;
}

void pd(int data) {
 printf("DATA_IN = %#x\n", data & 0xFF);
}

int main(void) {
  int r;
  int data_in;

  r = setupPins();
  if (r < 0) {
    printf("Error initializing pins\n");
    exit(1);
  } else {
    printf("Pins are initialized\n");
  }

  set(RESET);
  clock();
  unset(RESET);

  printf("EMPTY: %d\n", get(EMPTY));
  printf("FULL:  %d\n", get(FULL));

loop:
  // -- push 4 bytes to FIFO
  set(PUSH);
  dataOut(0x00);
  clock();

  dataOut(0xFF);
  clock();

  dataOut(0xA5);
  clock();

  dataOut(~0xA5);
  clock();

  unset(PUSH);

  printf("EMPTY: %d\n", get(EMPTY));
  printf("FULL:  %d\n", get(FULL));

  // -- pop 4 bytes to FIFO
  // EMPTY should become = 1 again and FULL should always be = 0 as FIFO depth
  // is 10 (see fifo.v).
  set(POP);
  clock();
  data_in = dataIn();
  pd(data_in);
  delay(DELAY);

  clock();
  data_in = dataIn();
  pd(data_in);
  delay(DELAY);

  clock();
  data_in = dataIn();
  pd(data_in);
  delay(DELAY);

  clock();
  data_in = dataIn();
  pd(data_in);
  delay(DELAY);

  unset(POP);

  printf("EMPTY: %d\n", get(EMPTY));
  printf("FULL:  %d\n", get(FULL));

  goto loop;
}
