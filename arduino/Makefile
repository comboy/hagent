BOARD_TAG = pro5v328
ARDUINO_PORT = /dev/ttyAMA0
ARDUINO_LIBS = EEPROM Metro
USER_LIB_PATH = ../vendor/arduino
ARDUINO_DIR = /usr/share/arduino
include ../vendor/arduino/Arduino.mk

reset:
		sh -c 'gpio mode 1 out; gpio write 1 1;  sleep 4;  gpio write 1 0' &





