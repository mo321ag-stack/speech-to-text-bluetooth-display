# ATmega32A firmware. Needs avr-gcc + avr-libc (Linux: apt install gcc-avr avr-libc binutils-avr).
MCU     = atmega32a
F_CPU   = 8000000UL
TARGET  = bt_display
SRC     = main.c uart.c twi_i2c.c lcd_i2c.c protocol.c arabic_display.c
CC      = avr-gcc
OBJCOPY = avr-objcopy
SIZE    = avr-size
CFLAGS  = -mmcu=$(MCU) -DF_CPU=$(F_CPU) -Os -std=gnu99 -Wall -Wextra -Werror \
          -ffunction-sections -fdata-sections
LDFLAGS = -Wl,--gc-sections

PORT    ?= COM4

all: $(TARGET).hex size

$(TARGET).elf: $(SRC) $(wildcard *.h)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(SRC)

$(TARGET).hex: $(TARGET).elf
	$(OBJCOPY) -O ihex -R .eeprom $< $@

size: $(TARGET).elf
	$(SIZE) $(TARGET).elf

flash: $(TARGET).hex
	avrdude -c stk500v1 -P $(PORT) -b 19200 -p m32 -U flash:w:$(TARGET).hex:i

clean:
	rm -f $(TARGET).elf

.PHONY: all size flash clean
