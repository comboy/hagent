#include <Wire.h>
#include "Adafruit_MCP23017.h"

Adafruit_MCP23017 mcp;
Adafruit_MCP23017 mcp2;

int led_states[16];
byte pressedButton = -1;
unsigned long lastPress = -1;

// keys array index = key, value = mcp pin
// 10 = #, 11 = *
int keys[] = {6, 12, 4, 0, 15, 7, 3, 13, 5, 1, 2, 14};
//            0  1   2  3  4   5  6  7   8  9  #  *

void setup() {
  mcp.begin();      // use default address 0
  mcp2.begin(4);

  for (int i=0; i<16; i++) {
    mcp.pinMode(i, INPUT);
    mcp.pullUp(i, HIGH);  // turn on a 100K pullup internally
    led_states[i] = 1;
    mcp2.pinMode(i, OUTPUT);
    mcp2.digitalWrite(i, LOW);
  }


//  delay(3100);
//  mcp2.digitalWrite(12, LOW);


  Serial.begin(9600);

  pinMode(13, OUTPUT);  // use the p13 LED as debugging
}

void releaseButton() {
  for (int i=0; i<16; i++) {
   //if (pressedButton != -1) {
     mcp2.digitalWrite(i, LOW);
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
      default:
        if (sig >= '0' && sig <= '9') {
          pressButton(sig - '0');
          rpl = '@';
        } else {
          rpl = '?';
        }
    }
    Serial.print((char)rpl);
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
  delay(10);
}

