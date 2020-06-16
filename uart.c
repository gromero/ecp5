#include <wiringPi.h>
#include <stdio.h>
#include <stdlib.h>
#include <inttypes.h>
#include <string.h>

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
#define RX_ADDR 0x01
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

  for (i = 0; i < DATA_BUS_SIZE; i++) {
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

int main(int argc, char *argv[]) {
  int r;
  int data_in;
  char message[] = "Hello cruel world";
  int i;
  uint8_t in_byte;


  r = setupPins();
  if (r < 0) {
    printf("Error initializing pins\n");
    exit(1);
  }

//  set(RESET);
//  clock();
//  unset(RESET);


  if (argc == 1) goto first;
  else if (argc == 2) {
     if (strcmp(argv[1], "-w")  == 0) {
       goto first;  
     }
     else if (strcmp(argv[1], "-r") == 0) {
       goto second;
     }
     else {
       printf("Unknown flag: %s\n", argv[1]);
       exit(1);
     }
  } else {
    printf("Wrong number of parameters\n");
    exit(1);
  }

goto second;

first:
printf("** WRITE TO WB BUS **\n"); 

loop:
  for (i = 'a'; i < 'a'+26 ; i++) {
    setAddr(TX_ADDR);
    dataOut('A');
    printf("%c\n", 'A');
    unset(WE); // !WE => write
    set(CS);
    clock();
//    delay(DELAY);
  }
goto loop;

  unset(CS); // get ACK set
  clock();

//delay(DELAY);
second: 
   printf("** READ FROM WB BUS **\n");
   setAddr(RX_ADDR);
   set(WE); // read, since WE_  
   set(CS); // select UART chip
   clock();
   in_byte = dataIn();  
   unset(CS); // get ACK set
   clock();

   printf("%0x %c\n", in_byte, in_byte);
}
