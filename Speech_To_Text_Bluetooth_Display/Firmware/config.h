/*
 * config.h - Speech-to-Text Bluetooth Display, ATmega32A firmware configuration.
 *
 * CLOCK - three different things, all must agree:
 *   1. F_CPU (below)   : only tells the compiler the speed for delays and baud math.
 *                        It does NOT change the hardware clock.
 *   2. Fuse bits       : select the real clock source. This chip currently has
 *                        LFUSE=0xE4 (internal RC 8 MHz), HFUSE=0xD9.
 *   3. OSCCAL          : the internal RC is only factory-calibrated for 1 MHz at reset.
 *                        For 8 MHz the 8 MHz calibration byte must be written by the
 *                        firmware. 0x9E was read from THIS chip with:
 *                          avrdude -c stk500v1 -P COM4 -b 19200 -p m32 -U calibration:r:-:h
 *                        -> 0x99,0x9b,0x99,0x9e  (1, 2, 4, 8 MHz). Another chip has another value.
 *
 * If you later switch to the 8 MHz crystal (LFUSE change), set USE_OSCCAL_8MHZ to 0.
 */
#ifndef CONFIG_H
#define CONFIG_H

#ifndef F_CPU
#define F_CPU 8000000UL
#endif

#define USE_OSCCAL_8MHZ     1
#define OSCCAL_8MHZ         0x9E

/* ---------- UART (HC-05) ---------- */
#define UART_BAUD           9600UL     /* HC-05 default data-mode baud rate */
#define UART_RX_BUF_SIZE    128        /* must be a power of two */

/* ---------- I2C / LCD ---------- */
#define TWI_SCL_HZ          100000UL
#define LCD_COLS            16
#define LCD_ROWS            2
/* PCF8574 backpacks are 0x20..0x27, PCF8574A backpacks 0x38..0x3F.
   The firmware scans both ranges at start-up and prints the address it found. */

/* ---------- Protocol ---------- */
#define FRAME_SYNC1         0xAA
#define FRAME_SYNC2         0x55
#define MAX_PAYLOAD         200
#define FRAME_TIMEOUT_MS    300        /* drop a frame that stops arriving mid-way */
#define LINE_TIMEOUT_MS     600        /* plain text without '\n' is shown after this pause */

/* ---------- Display ---------- */
#define MAX_TEXT_LEN        200        /* English / ASCII text */
#define MAX_GLYPH_PAGES     8          /* Arabic pages (each: 8 custom glyphs + 32 cells) */
#define MAX_TEXT_PAGES      16
#define DEFAULT_PAGE_MS     2500       /* time each page stays on screen */

#define FW_VERSION          "1.0"

#endif /* CONFIG_H */
