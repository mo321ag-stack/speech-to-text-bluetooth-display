# Phone ↔ ATmega32A protocol

UART 9600 baud, 8N1, through the HC-05.

## Frame

```
AA 55 | TYPE | LEN | PAYLOAD[LEN] | CRC8
```

- `CRC8` is CRC-8/SMBUS (polynomial `0x07`, initial value `0x00`), computed over `TYPE`, `LEN` and `PAYLOAD`. The check value for `"123456789"` is `0xF4`.
- Maximum `LEN` is 200.
- A frame that stops arriving for more than 300 ms is dropped and answered with `NAK tt timeout`.

| Type | Payload | Meaning |
|---|---|---|
| `01` TEXT | ASCII `0x20–0x7E` | Show English text; the MCU word-wraps and pages it |
| `02` CLEAR | none | Clear the screen and stop paging |
| `03` PING | none | Replies `PONG 1.0` |
| `04` BACKLIGHT | `00` / `01` | Backlight off / on |
| `10` PAGES_BEGIN | count (1–8), page time × 100 ms | Start a glyph-page message |
| `11` PAGE | index, n (0–8), n × 8 glyph rows, 32 cells | One screen |
| `12` PAGES_END | none | Start showing the pages |

**Cells** are listed row 0 then row 1, left to right as seen on the screen:
- `0–7`: the custom glyph with that index on this page
- `0x20–0x7E`: an ASCII character from the LCD ROM

**Glyph rows**: 8 bytes per glyph, low 5 bits used, bit 4 = leftmost pixel.

**Replies**: `ACK tt`, or `NAK tt reason`, where reason is one of `crc`, `len`, `count`, `page`, `missing_page`, `timeout`, `too_long`, `unknown`.

## Examples

Text `HI`:
```
AA 55 01 02 48 49 <crc>
```

«مرحبا بكم» (one page, 8 glyphs):
```
AA 55 02 00 2A                         CLEAR
AA 55 10 02 01 19 EB                   PAGES_BEGIN  count=1, 2.5 s
AA 55 11 62 00 08 <64 glyph bytes> <32 cells> <crc>
AA 55 12 00 7D                         PAGES_END
```

## Plain-text fallback

Bytes that do not start a frame are collected as a text line. The line is shown on `\n`, or after a 600 ms pause.

Non-ASCII UTF-8 characters become `?` in this mode. A `0xAA` byte inside UTF-8 text (for example ت = `D8 AA`) is never mistaken for a frame start.

Test commands: `#HELLO`, `#AR` (built-in «مرحبا»), `#CLR`, `#INFO`.

## Arabic layout (done on the phone)

1. **Shaping:** each letter's joining type (dual or right) decides its form: isolated, initial, medial or final. لا is a mandatory ligature. Harakat and tatweel are dropped.
2. **Words become blocks.** An Arabic block is reversed for display; a Latin block keeps its order. In a right-to-left paragraph, blocks are placed from right to left and the lines are right-aligned.
3. **Pages:** blocks are packed greedily into 2 × 16 cells, starting a new page whenever a 9th distinct glyph would be needed. At most 8 pages.

Why this way: an HD44780 has 8 CGRAM slots, and that is the hard limit on how many different shapes one screen can show.
