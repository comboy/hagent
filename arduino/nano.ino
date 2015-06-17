#include <Wire.h>
#include "Adafruit_MCP23017.h"
#include <Metro.h>

Adafruit_MCP23017 mcp;
Adafruit_MCP23017 mcp2;

int led_states[16];
byte pressedButton = -1;
unsigned long lastPress = -1;

// keys array index = key, value = mcp pin
// 10 = #, 11 = *
int keys[] = {6, 12, 4, 0, 15, 7, 3, 13, 5, 1, 2, 14};
//            0  1   2  3  4   5  6  7   8  9  #  *

// 8 9 10 11
int pinVoltage = A2;
int spkState = 0;

//int ledOrange = 3;
//int ledGreen = 2;
//int ledRed = 4;
int ledHeart = 4;
int ledOk = 2; 
Metro metroHeart = Metro(250);
Metro metroOk = Metro(250);
int ledHeartState = 0;
int ledOkState = 1;

void setup() {
  mcp.begin();      // use default address 0
  mcp2.begin(4);

  for (int i=0; i<16; i++) {
    mcp.pinMode(i, INPUT);
    mcp.pullUp(i, HIGH);  // turn on a 100K pullup internally
    led_states[i] = 1;
    if (i < 12) {
      mcp2.pinMode(keys[i], OUTPUT);
      mcp2.digitalWrite(keys[i], LOW);
    }
  }
  mcp2.pinMode(11, OUTPUT);


//  delay(3100);
//  mcp2.digitalWrite(12, LOW);


  Serial.begin(9600);

  pinMode(13, OUTPUT);  // use the p13 LED as debugging
  pinMode(ledHeart, OUTPUT);
  pinMode(ledOk, OUTPUT);
}

void releaseButton() {
  for (int i=0; i<12; i++) {
   //if (pressedButton != -1) {
     mcp2.digitalWrite(keys[i], LOW);
   //}
  }
  pressedButton = -1;
}


void pressButton(byte x) {
  releaseButton();
  lastPress = millis();
  pressedButton = x;
  mcp2.digitalWrite(keys[x], HIGH);
}

void loop() {
  // The LED will 'echo' the button
  // digitalWrite(13, mcp.digitalRead(0));
  for (int i=0; i<16; i++) {
    //if (i == 5) { continue; }
    int state = mcp.digitalRead(i);
    if (state != led_states[i]) {
      Serial.print(state ? "-" : "+");
      Serial.print((char)('a'+i));
      led_states[i] = state;
    }
  }

  if (Serial.available() > 0) {
    byte sig = Serial.read();
    byte rpl;
    switch(sig) {
      case '.':
        rpl = '.';
        break;
      case ',':
        rpl = ',';
        //delay(500);
        break;
      case '!':
        rpl = ',';
        //delay(3200);
        break;
      case '^':
        releaseButton();
        rpl = '@';
        break;
      case '#':
        pressButton(10);
        rpl = '@';
        break;
      case '*':
        pressButton(11);
        rpl = '@';
        break;
      case 'v':
        Serial.print('v');
        Serial.print(analogRead(pinVoltage));
        rpl = '.'; 
      default:
        if (sig >= '0' && sig <= '9') {
          pressButton(sig - '0');
          rpl = '@';
        } else {
          rpl = '?';
        }
    }
    Serial.print((char)rpl);
    //Serial.print("mm:");
    //Serial.println(mcp2.digitalRead(11));
 
    /*
    if (sig == '.') {
      Serial.print('.');
    } if (sig == ',') {
      Serial.print(',');
      delay(500);
    } else {
      if (sig == '#' || sig == '*' || (sig >= '0' && sig <= '9')) {
        Serial.print('@');
      } else {
        Serial.print('?');
      }
    }*/
    if (pressedButton != -1 && (millis() - lastPress) > 10000) {
      releaseButton();
    }
  }

  // heartbeat led
  if (metroHeart.check() == 1) {
    if (ledHeartState == 0) {
      ledHeartState = 1;
      digitalWrite(ledHeart, HIGH);
      metroHeart.interval(100);
    } else {
      ledHeartState = 0;
      digitalWrite(ledHeart, LOW);
      metroHeart.interval(100);
    }
  }

  // OK led
  if (metroOk.check() == 1) {
    if (ledOkState == 0) {
      ledOkState = 1;
      digitalWrite(ledOk, HIGH);
      metroOk.interval(100);
    } else {
      ledOkState = 0;
      digitalWrite(ledOk, LOW);
      metroOk.interval(700);
    }
  }
  
  int spk = mcp2.digitalRead(11);
  if (spk != spkState) {
    spkState = spk;
    Serial.print(spk ? "S" : "s");
  }

  delay(10);
}

