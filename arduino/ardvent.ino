

#include <SPI.h>
#include <Metro.h>
#include <OneWire.h>
#include "nRF24L01.h"
#include "RF24.h"
//#include "printf.h"
#include <dht.h>

dht DHT;
float lastHum;
float lastTempDHT;
#define DHT22_PIN 16

OneWire ds(8);

// TEMP 28 78 8F 50 5 0 0 6E


// 5 - relay 1
// 6 - relay 2
// 7 - beeper
#define RED_LED_PIN 2 // 2
#define GREEN_LED_PIN 3
#define BLUE_LED_PIN 4
#define BEEP_PIN 7

#define RELAY1_PIN 5
#define RELAY2_PIN 6

#define RPL_ACK 1337
#define RPL_ERR -666
//
// Hardware conf
//

// Set up nRF24L01 radio on SPI bus plus pins 9 & 10 

RF24 radio(9,10);

//
// Topology
//

// Radio pipe addresses for the 2 nodes to communicate.
const uint64_t pipes[2] = { 
  0xF0F0F0F0E1LL, 0xF0F0F0F0D2LL };

//Metro ledMetro = Metro(2000); 
Metro dhtMetro = Metro(2500);
Metro tempMetro = Metro(2000);

float lastTemp;

int ledState = HIGH;
byte dsAddr[8] = {
  0x28, 0x78, 0x8F, 0x50, 0x05, 0x00, 0x00, 0x6E}; // {40,34,234,46,3,0,0,32};

void setup(void)
{
  //
  // Print preamble
  //

  //Serial.begin(9600);

  lastHum = 0;
  lastTemp = 0;
  pinMode(RED_LED_PIN, OUTPUT);
  digitalWrite(RED_LED_PIN, LOW);
  delay(100);
  digitalWrite(RED_LED_PIN, HIGH);
  pinMode(GREEN_LED_PIN, OUTPUT);
  digitalWrite(GREEN_LED_PIN, LOW);
  delay(100);
  digitalWrite(GREEN_LED_PIN, HIGH);
  pinMode(BLUE_LED_PIN, OUTPUT);
  digitalWrite(BLUE_LED_PIN, LOW);
  delay(100);  
  digitalWrite(BLUE_LED_PIN, HIGH);

  pinMode(BEEP_PIN, OUTPUT);
  pinMode(RELAY1_PIN, OUTPUT);
  pinMode(RELAY2_PIN, OUTPUT);

  //printf_begin();
  //printf("\nLight Switch Arduino\n\r");

  //
  // Setup and configure rf radio
  //

  radio.begin();
  radio.setRetries(15,15);

  radio.openWritingPipe(pipes[0]);
  radio.openReadingPipe(1,pipes[1]);
  radio.startListening();
  radio.printDetails();
}

void loop(void)
{
  if (tempMetro.check() == 1) {
    lastTemp = temp_read(dsAddr);
    temp_prepare(dsAddr);
  }
  /*temp_prepare(dsAddr);
   delay(1000);
   Serial.print("TEMP:");
   Serial.println(temp_read(dsAddr));
   delay(500); */
  /* 
  if (ledMetro.check() == 1) {
    if (ledState==HIGH) ledState=LOW;
    else ledState=HIGH;
    digitalWrite(RED_LED_PIN, ledState);
  }*/

  if (dhtMetro.check() == 1) {
    int chk = DHT.read22(DHT22_PIN);
    if (chk == DHTLIB_OK) {
      float hum = DHT.humidity;
      float temp = DHT.temperature;
      //Serial.print("DHT: ");
      lastHum = hum;
      lastTempDHT = temp;
      //Serial.println(hum);    
      //Serial.print("last temp ");
      //Serial.println(lastTemp);
    } 
    else {
      lastHum = -111;
      lastTempDHT = -111;
      //Serial.println("DHT FAIL");
    }
  }
  // if there is data ready
  if ( radio.available() )
  {
    // Dump the payloads until we've gotten everything
    unsigned long message;
    long reply;
    reply = RPL_ERR;
    bool done = false;
    while (!done)
    {
      // Fetch the payload, and see if this was the last one.
      done = radio.read( &message, sizeof(unsigned long) );

      // Spew it
      //printf("Got message %lu...",message);
      switch(message) {
      case 1: // ping
        reply = RPL_ACK;
        break; 
        
      case 2: // red led on
        digitalWrite(RED_LED_PIN, LOW);
        reply = RPL_ACK;
        break;
      case 3: // red led off
        digitalWrite(RED_LED_PIN, HIGH);
        reply = RPL_ACK;
        break;
      case 4: // green led on
        digitalWrite(GREEN_LED_PIN, LOW);
        reply = RPL_ACK;
        break;
      case 5: // green led off
        digitalWrite(GREEN_LED_PIN, HIGH);
        reply = RPL_ACK;
        break;
      case 6: // blue led on
        digitalWrite(BLUE_LED_PIN, LOW);
        reply = RPL_ACK;
        break;
      case 7: // blue led off
        digitalWrite(BLUE_LED_PIN, HIGH);
        reply = RPL_ACK;
        break;
      case 8: // switch relay 1 on
        digitalWrite(BEEP_PIN, HIGH);
        reply = RPL_ACK;
        break;
      case 9: // switch relay 1 on
        digitalWrite(BEEP_PIN, LOW);
        reply = RPL_ACK;
        break; 

        
      case 10: // get temp
        reply = lastTemp * 100;
        break;
      case 11: // get humiditiy
        reply = lastHum * 100;
        break;
      case 12:
        reply = lastTempDHT * 100;
        break;
        
      case 20: // switch relay 1 on
        digitalWrite(RELAY1_PIN, HIGH);
        reply = RPL_ACK;
        break;
      case 21: // switch relay 1 on
        digitalWrite(RELAY1_PIN, LOW);
        reply = RPL_ACK;
        break; 
      case 22: // switch relay 2 on
        digitalWrite(RELAY2_PIN, HIGH);
        reply = RPL_ACK;
        break;
      case 23: // switch relay 2 on
        digitalWrite(RELAY2_PIN, LOW);
        reply = RPL_ACK;
        break;       
        
      case 30:
        digitalWrite(BEEP_PIN, HIGH);
        delay(5);
        digitalWrite(BEEP_PIN, LOW);
        break;
      }

      // Delay just a little bit to let the other unit
      // make the transition to receiver
      delay(20);
    }

    // First, stop listening so we can talk
    radio.stopListening();

    // Send the final one back.
    //reply = message*3;
    //reply = -337;
    radio.write( &reply, sizeof(long) );
    //printf("Sent response.\n\r");

    // Now, resume listening so we catch the next packets.
    radio.startListening();
  }

}

void temp_prepare(byte *addr) {
  ds.reset();
  ds.select(addr);
  ds.write(0x44,1);         // start conversion, with parasite power on at the end
}

float temp_read(byte *addr) {
  byte present = 0;
  byte i;
  byte data[12];
  present = ds.reset();
  ds.select(addr);
  ds.write(0xBE);         // Read Scratchpad

  for ( i = 0; i < 9; i++) {           // we need 9 bytes
    data[i] = ds.read();
  }

  return temp_from_data(data);
}

float temp_from_data(byte *data) {
  int LowByte = data[0];
  int HighByte = data[1];
  int TReading = (HighByte << 8) + LowByte;
  int SignBit = TReading & 0x8000;  // test most sig bit
  int Tc_100;
  int Whole;
  int Fract;
  float ret;

  if (SignBit) // negative
  {
    TReading = (TReading ^ 0xffff) + 1; // 2's comp
  }
  Tc_100 = (6 * TReading) + TReading / 4;    // multiply by (100 * 0.0625) or 6.25

  Whole = Tc_100 / 100;  // separate off the whole and fractional portions
  Fract = Tc_100 % 100;


  ret = Whole;
  ret += Fract / 100.0;
  if (SignBit)
    ret *= -1;

  return ret;
}



