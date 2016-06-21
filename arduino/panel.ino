/* Encoder Library - Basic Example
 * http://www.pjrc.com/teensy/td_libs_Encoder.html
 *
 * This example code is in the public domain.
 */

#define ENCODER_USE_INTERRUPTS


#include <Encoder.h>
#include <PCF8574.h>
#include <Wire.h>
#include <Metro.h>
#include <LiquidCrystal_I2C.h>

LiquidCrystal_I2C lcd(0x27,16,2);  // set the LCD address to 0x27 for a 20 chars and 4 line display

PCF8574 pcf(0x21);

// Change these two numbers to the pins connected to your encoder.
//   Best Performance: both pins have interrupt capability
//   Good Performance: only the first pin has interrupt capability
//   Low Performance:  neither pin has interrupt capability
// Encoder myEnc(5, 6);
Encoder myEnc(3, 2);
//   avoid usikg pins with LEDs attached

int wt=100;
int pinTest=9;
int intPin=11;
int pinSpk=10;
int pinLed=12;

int pinLight1=6;
int pinLight2=5;
int pinLight3=9;

void setup() {
  Serial.begin(57600);
  // Serial.println("Basic Encoder Test:");
  pinMode(pinTest, OUTPUT);
  pinMode(intPin, INPUT_PULLUP);
  pinMode(pinSpk, OUTPUT);
  pinMode(pinLed, OUTPUT);
  for(int i=0; i<80; i++) {
    tone(pinSpk, i*200);
    delay(3 + ((100-i) / 20)*((100-i) / 20));
  }
  noTone(pinSpk);
  //analogWrite(pinSpk, 100);
  //delay(10);
  //analogWrite(pinSpk, 0);
  lcd.init();                      // initialize the lcd

  // Print a message to the LCD.
  lcd.backlight();
  lcd.print("Initializing...");
  for(int i=50; i>0; i--) {
    tone(pinSpk, i*400);
    delay(1+(i / 20)*(i / 20));
  }
  tone(pinSpk,10);
  delay(200);
  tone(pinSpk,1000);
  delay(200);
  noTone(pinSpk);

  pinMode(pinLight1, OUTPUT);
  analogWrite(pinLight1, 40);
  pinMode(pinLight2, OUTPUT);
  analogWrite(pinLight2, 100);
  pinMode(pinLight3, OUTPUT);
  analogWrite(pinLight3, 40);
//  analogWrite(pinSpk, 70);
//  delay(20);
//  analogWrite(pinSpk, 0);
//  analogWrite(pinTest, 100);

}

long oldPosition  = 0;

int readState = 0;
int prevPCFState = 0;
// 1 waiting for lcd first line

unsigned long lastContact = 0;

Metro metroContact = Metro(1000);
Metro metroBeat = Metro(800);
int beatState = 0;

void loop() {
  if (metroBeat.check() == 1) {
    beatState = beatState + 1;
    if (beatState % 2 == 0) {
      digitalWrite(pinLed, HIGH);
    } else {
      digitalWrite(pinLed, LOW);
    }
    if (beatState % 4 == 1) {
      metroBeat.interval(400);
    } else {
      metroBeat.interval(100);
    }
  }
  if (metroContact.check() == 1) {
    if (millis() - lastContact > 6000) {
      lcd.noBacklight();
      lcd.clear();
      delay(100);
      lcd.backlight();
      lcd.setCursor(0,0);
      if (lastContact == 0) {
        lcd.print("Where is my mind");
      } else {
        lcd.print("MOL IS DEAD  X_X");
      }
      lcd.setCursor(0,1);
      lcd.print("     T => ");
      lcd.print((millis() - lastContact) / 1000);
    }
  }

  if (digitalRead(intPin) == 0) {
    int pcf_state = pcf.read8();
    if (pcf_state != prevPCFState) {
      prevPCFState = pcf_state;
      //analogWrite(pinSpk, 1);
      tone(pinSpk, 50);
      delay(100); //debounce
      noTone(pinSpk);
      //analogWrite(pinSpk, 0);
      Serial.print('P');
      Serial.println(pcf_state);
    }
  }

  long newPosition = myEnc.read();
  if (abs(newPosition - oldPosition) > 1) {


    if (newPosition > oldPosition) {
      for (int i=0; i < (newPosition - oldPosition) / 2; i++) {
        Serial.print("-");
        //analogWrite(pinSpk, 150);
        //delay(50);
        //analogWrite(pinSpk, 0);
      }
    } else {
      for (int i=0; i < (oldPosition - newPosition) / 2; i++) {
        Serial.print("+");
        //analogWrite(pinSpk, 100);
        //delay(50);
        //analogWrite(pinSpk, 0);
      }
    }
    oldPosition = newPosition;
    //Serial.println(newPosition);
  }

  if (readState == 1) {
    if (Serial.available() > 15) {
      char line[16];
      Serial.readBytes(line, 16);
      lcd.setCursor(0,0);
      lcd.print(line);
      //delay(200);
      readState = 0;
    }
  } else
  if (readState == 2) {
    if (Serial.available() > 15) {
      char line[16];
      Serial.readBytes(line, 16);
      lcd.setCursor(0,1);
      lcd.print(line);
      //delay(200);
      readState = 0;
    }
  } else {
    if (Serial.available() > 0) {
      int sb = Serial.read();
      if (sb == '.') {
        if (lastContact == 0) {
          lcd.setCursor(0,0);
          lcd.print("  Hello MOL!  ");
        }
        lastContact = millis();
        Serial.print('?');
      } else
      if (sb == '1') {
        readState = 1;
      } else
      if (sb == '2') {
        readState = 2;
      } else
      if (sb == 'b') {
        lcd.noBacklight();
      } else
      if (sb == 'B') {
        lcd.backlight();
      } else
      if (sb == 't') {
        int freq = Serial.parseInt();
        int length = Serial.parseInt();
        if (length == 0) {
          tone(pinSpk, freq);
        } else {
          tone(pinSpk, freq, length);
        }
      } else
      if (sb == 'T') {
        noTone(pinSpk);
      }
      if (sb == 'L') {
        int lightNum;
        int lb = Serial.read();
        if (lb == '1') { lightNum = pinLight1; }
        if (lb == '2') { lightNum = pinLight2; }
        if (lb == '3') { lightNum = pinLight3; }
        int value = Serial.parseInt();
        analogWrite(lightNum, value);
      } else
      if (sb == 'a') {
        int val = Serial.parseInt();
        analogWrite(pinTest, val);
      } else
      {
        Serial.print('?');
      }
    }
  }

}
