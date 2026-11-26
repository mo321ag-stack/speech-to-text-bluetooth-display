# Hardware

## Wiring

### Power and clock

| ATmega32A pin | Connection |
|---|---|
| 10 VCC, 30 AVCC | +5 V (add 100 nF to GND close to each pin) |
| 11 GND, 31 GND | GND |
| 9 RESET | 10 kΩ pull-up (see the note on the ESP32 below) |
| 12 / 13 XTAL | Not used: the chip runs from its internal 8 MHz RC oscillator |

### HC-05 (Bluetooth)

| HC-05 | ATmega32A |
|---|---|
| VCC | 5 V (most breakout boards accept 3.6–6 V) |
| GND | GND |
| TXD | pin 14 PD0/RXD (direct: 3.3 V is above the AVR's 3.0 V V<sub>IH</sub> at 5 V) |
| RXD | pin 15 PD1/TXD through a divider: 1 kΩ in series, 2 kΩ to GND → about 3.3 V |

### LCD (PCF8574 backpack)

| LCD | ATmega32A |
|---|---|
| SDA | pin 23 PC1 |
| SCL | pin 22 PC0 |
| VCC / GND | 5 V / GND |

The firmware scans `0x20–0x27` and `0x38–0x3F` and prints the address it finds (`#INFO`).

### ESP32 as ISP programmer

| ESP32 | ATmega32A |
|---|---|
| GPIO23 | pin 6 MOSI |
| GPIO19 | pin 7 MISO, through a 1 kΩ / 2 kΩ divider (5 V → 3.3 V) |
| GPIO18 | pin 8 SCK |
| GPIO5 | pin 9 RESET |
| GPIO4 | pin 13 XTAL1: rescue clock, only needed for recovery |
| GND | GND |

> ⚠️ With RESET pulled up to **5 V** and connected to GPIO5, the ESP32 pin sees 5 V while it is not driving the line. This is above the ESP32's absolute maximum (≈3.6 V). Pull RESET up to 3.3 V instead, or add a series resistor or diode.

## Fuses and clock

| | Value | Meaning |
|---|---|---|
| LFUSE | `0xE4` | CKSEL=0100: internal RC 8 MHz; SUT=10; BOD off |
| HFUSE | `0xD9` | JTAG off, SPIEN on, CKOPT unprogrammed |
| Lock | `0xFF` | Unlocked |
| OSCCAL | `0x9E` | 8 MHz calibration byte, written by the firmware at start-up |

The AVR only loads the **1 MHz** calibration byte automatically. For 8 MHz, the firmware must write the 8 MHz byte into `OSCCAL`, otherwise UART timing can be off by several percent. Read your own chip's bytes with:

```bash
avrdude -c stk500v1 -P COM4 -b 19200 -p m32 -U calibration:r:-:h   # -> 1, 2, 4, 8 MHz values
```

Then set `OSCCAL_8MHZ` in `Firmware/config.h`.

`F_CPU` only informs the compiler. The real clock is chosen by the fuses.

## ISP recovery: `Device signature = 00 00 00`

This happened during development, after writing `LFUSE=0xFF`:

1. `LFUSE=0xFF` selects an **external crystal**. The 8 MHz crystal and capacitors did not oscillate, so the chip had no clock and its SPI programming interface was silent (`00 00 00`). SPIEN was still enabled.
2. [`ESP32_ArduinoISP_Clock`](../ESP32_ArduinoISP_Clock) drives a 1 MHz square wave on **GPIO4 → XTAL1**. This gives the chip a clock without the crystal, and the signature came back: `1E 95 02`.
3. With the chip responding, the fuses were read back (`FF D9`, lock `FF`). `LFUSE` was then set to `0xE4` (internal RC 8 MHz), and the clock wire was removed.

That sketch also verifies the Programming Enable echo (`0x53`) and samples MISO with majority voting, both of which help on breadboards.
