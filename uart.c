#include <wiringPi.h>
#include <stdio.h>
#include <stdlib.h>

// IO "semantics" in this code:
// DATA_OUT: from RPi3 ---- to ----> FPGA
// DATA_IN : from FPGA ---- to ----> RPi3

#define RESET 25

#define ADDR0 15
#define ADDR1 23

#define WE   26
#define CLK  6
#define CS   27
#define ACK  16

#define DATA_BUS_SIZE 8

#define TX_ADDR 0x00
#define FREQ_DIV 0x02
#define ADDR_BUS_SIZE 2

#define DATA_OUT0 7
#define DATA_OUT1 21
#define DATA_OUT2 22
#define DATA_OUT3 10
#define DATA_OUT4 11
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

int addr[] = { ADDR0, ADDR1 };

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

void setAddr(int a) {
  int i;
  int bit;

  for (i = 0; i < ADDR_BUS_SIZE; i++) {
   bit = (a >> i) & 0x1;
   digitalWrite(addr[i], bit);
  }
}

void dataOut(int d) {
  int i;
  int bit;

  for (i = 0; i < DATA_BUS_SIZE; i++) {
    bit = (d >> i) & 0x1;
    digitalWrite(data_out[i], bit);
  }
}

int dataIn(void) {
  int i;
  int d = 0;
  int bit;

  for (i = DATA_BUS_SIZE-1; i >= 0; i--) {
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

  pinMode(RESET, OUTPUT);

  pinMode(ADDR0, OUTPUT);
  pinMode(ADDR1, OUTPUT);

  pinMode(WE, OUTPUT);
  pinMode(CLK, OUTPUT);
  pinMode(CS, OUTPUT);
  pinMode(ACK, INPUT);

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

void prinDatain(int data) {
 printf("DATA_IN = %#x\n", data & 0xFF);
}

int main(void) {
  int r;
  int data_in;
  char message[] = "Hello cruel world";
  int i;


  r = setupPins();
  if (r < 0) {
    printf("Error initializing pins\n");
    exit(1);
  }

  set(RESET);
  clock();
  unset(RESET);

//printf("ACK: %d\n", get(ACK));
loop:
  for (i = 'a'; i < 'a'+26 ; i++) {
    setAddr(TX_ADDR);
    dataOut(i);
    printf("%c\n", i);
    unset(WE); // !WE => write
    set(CS);
    clock();
    delay(DELAY);
  }
goto loop;

  unset(CS); // get ACK set
  clock();

//delay(DELAY);
}
