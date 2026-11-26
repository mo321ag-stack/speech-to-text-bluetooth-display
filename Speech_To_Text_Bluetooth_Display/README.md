# Speech-to-Text Bluetooth Display: ATmega32A + HC-05 + I2C LCD

## Status

| Stage | State |
|---|---|
| 1. Hardware and Arabic analysis | Done (this file) |
| 2. AVR C firmware | Done: `Firmware/` |
| 3. Compile, HEX, flash | Done. Compiles with no warnings (4,810 B flash, 1,380 B RAM), burned and **verified** on the chip. Not yet tested with the LCD and HC-05 connected. |
| 4–8. Flutter app, integration, tests, docs | Not started |

## Chip state (measured with avrdude through the ESP32 programmer)

- Signature `1E 95 02`
- LFUSE `0xE4`: internal RC oscillator, **8 MHz**. The 8 MHz crystal did not oscillate and is not used.
- HFUSE `0xD9`: JTAG off, SPIEN on
- Lock `0xFF`
- Calibration bytes `99 9B 99 9E`. The firmware writes the 8 MHz value `0x9E` to OSCCAL at start-up, because the chip only loads the 1 MHz value automatically.

## Arabic on a 16x2 HD44780: what is possible

| Option | Verdict |
|---|---|
| A. Custom CGRAM glyphs on the current LCD | **Used.** Works, with a hard limit: an HD44780 has only **8 user-defined characters on screen at once**. Arabic needs about 100 shapes (28 letters × up to 4 joining forms). So one screen can show at most 8 *different* Arabic shapes, and longer text is split into pages. 5×8 pixels gives readable but simplified letters, and letters cannot visually join across the 1-pixel gap between cells. |
| B. LCD with an Arabic character ROM | Only special modules (e.g. some HD44780-compatible ROM variants) have Arabic, and not with shaping. The common blue/green 1602 modules have Japanese (A00) or European (A02) ROMs. Can't be confirmed without the module's part number, so it isn't relied on. |
| C. Graphic display (128×64 ST7920 / SSD1306 OLED) | Full Arabic with proper joining is realistic. **Recommended if Arabic quality matters.** This would replace the LCD, so it is only a recommendation, not something done here. |

**How option A works here:**
1. The phone app shapes the Arabic text (choosing isolated, initial, medial or final forms), orders it right to left, and lays it out into 16×2 pages with no more than 8 distinct glyphs per page.
2. For each page it sends the glyph bitmaps and the 32 cell codes.
3. The ATmega stores up to 8 pages, loads each page's glyphs into CGRAM, and cycles through the pages.

English needs none of this: the ATmega word-wraps ASCII text itself.

## Protocol

Frame: `AA 55 | TYPE | LEN | PAYLOAD | CRC8`. CRC-8/SMBUS (poly 0x07, init 0) is computed over TYPE, LEN and PAYLOAD.

| Type | Payload | Meaning |
|---|---|---|
| `01` | ASCII text (≤ 200) | Show English text |
| `02` | – | Clear |
| `03` | – | Ping → `PONG 1.0` |
| `04` | `00`/`01` | Backlight off/on |
| `10` | count, time×100 ms | Begin Arabic pages |
| `11` | index, n, n×8 glyph rows, 32 cells | One page (cells 0–7 = glyphs, 0x20–0x7E = ASCII) |
| `12` | – | End: start showing |

The ATmega replies `ACK tt` or `NAK tt reason` (`crc`, `len`, `timeout`, `missing_page`, …).

Example: text `HI` → `AA 55 01 02 48 49 CRC`.

**Plain-text fallback** for any Bluetooth serial terminal: type a line and it is shown. Commands:
- `#HELLO`: show HELLO WORLD
- `#AR`: built-in Arabic test "مرحبا"
- `#CLR`: clear the screen
- `#INFO`: print LCD address and error counters

## Build and flash

`Firmware\build.bat` builds with the avr-gcc from the Arduino IDE. Flash with:

```
avrdude -c stk500v1 -P COM4 -b 19200 -p m32 -U flash:w:bt_display.hex:i
```

**Fuses are not part of the HEX.** Neither the build nor flashing changes them. `F_CPU` (8 MHz) only informs the compiler; the real clock comes from the fuses (internal RC) and OSCCAL.

For Microchip Studio:
1. New Project → GCC C Executable Project → device **ATmega32A**.
2. Add every `.c` and `.h` file from `Firmware/`.
3. Project Properties → Toolchain → Symbols: add `F_CPU=8000000UL`. Optimisation: `-Os`.
4. Build. The HEX is in `Debug/`.
