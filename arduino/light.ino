#include <EEPROM.h>
#include <Metro.h>

#define swCount 4

int swPins[] = {
// in, out
   3,  2,
   5,  4,
   7,  6,
   9,  8
};

// because why bother soldering it correctly
bool reverseFix[] = {false, false, false, true};

int swState[swCount];
int outState[swCount];

long unsigned int lastPing = 0;

Metro metroHeart = Metro(250);
int ledHeart = 10;
int ledHeartState = 0;

int ledAuto = 11;

int lightSensor = A1;

#define B_PING  46
#define B_HELLO 63
#define B_LIGHT 90

#define R_ERR    33
#define R_ACK    46
#define R_HELLO  63
#define R_LIGHT  90

// time without ping after which it switches to autonomous mode
#define AUTO_TIME 15*1000

// Protocol
// 100 + swI
// + 0 :: sw off
// + 1 :: sw on
// + 2 :: out off // when received it's comand, when sent it's info about the state
// + 3 :: sw on // -"-

void setup(void) {
//  pinMode(pinTest, OUTPUT);
//  pinMode(pinRead, INPUT_PULLUP);
//  readState = digitalRead(pinRead);
  Serial.begin(9600);

  for(int i=0; i < swCount; i++) {
    pinMode(swPins[i*2], INPUT_PULLUP);
    swState[i] = digitalRead(swPins[i*2]);
    pinMode(swPins[i*2 + 1], OUTPUT);
    int state = EEPROM.read(i);
    outState[i] = state;
    digitalWrite(swPins[i*2 + 1], state);
  }

  pinMode(ledHeart, OUTPUT);
  pinMode(ledAuto, OUTPUT);
}

void setOut(int swNum, int state) {
  digitalWrite(swPins[swNum*2 + 1], state);
  outState[swNum] = state;
  EEPROM.write(swNum, state);
  // TODO EEPROM
}

bool isAutonomous() {
  return (lastPing == 0 || lastPing < (millis() - AUTO_TIME));
}

void sendOutState(int swNum) {
  int state = outState[swNum];
  if (reverseFix[swNum]) {
    state = !state;
  }
  Serial.write(100 + swNum*4 + 2 + state);
}

void loop() {

  if (Serial.available() > 0) {
    int sb = Serial.read();

    // ping
    if (sb == B_PING) {
      lastPing = millis();
      Serial.write(R_ACK); // pong
    }

    // how many light switches
    if (sb == B_HELLO) {
      Serial.write(R_HELLO);
      Serial.println(swCount);
      // report switches and light state
      for(int i=0; i< swCount; i++) {
        Serial.write(100 + i*4 + swState[i]);
        sendOutState(i);
      }
    }

    // analog read of photo resistor
    if (sb == B_LIGHT) {
      int value = analogRead(lightSensor);
      Serial.write(R_LIGHT);
      Serial.println(value);
    }

    // light relays
    for(int i=0; i< swCount; i++) {
      if (sb == 100 + i*4 + 2) { // turn off
        setOut(i, reverseFix[i] ? HIGH : LOW);
        Serial.write(sb);
      }
      if (sb == 100 + i*4 + 3) { // turn on
        setOut(i, reverseFix[i] ? LOW : HIGH);
        Serial.write(sb);
      }
    }
  }

  // check light switches
  for(int i=0; i< swCount; i++) {
    int x = digitalRead(swPins[i*2]);
    if (x != swState[i]) {
      // simple debounce by checking if the value is the same ofter 20ms
      delay(20);
      x = digitalRead(swPins[i*2]);
      if (x != swState[i]) {

        swState[i] = x;
        if (isAutonomous()) {
          setOut(i, !outState[i]);
        } else {
          Serial.write(100 + i*4 + x);
        }

      }
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
      metroHeart.interval(700);
    }
  }

  digitalWrite(ledAuto, isAutonomous() ? HIGH : LOW);

}
