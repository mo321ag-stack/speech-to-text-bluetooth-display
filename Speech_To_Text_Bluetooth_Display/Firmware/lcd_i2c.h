/* lcd_i2c.h - HD44780 16x2 LCD through a PCF8574 I2C backpack (4-bit mode). */
#ifndef LCD_I2C_H
#define LCD_I2C_H

#include <stdint.h>

/* Scans 0x20-0x27 and 0x38-0x3F, initialises the LCD. Returns the address found, 0 if none. */
uint8_t lcd_init(void);
uint8_t lcd_present(void);
uint8_t lcd_address(void);

void lcd_clear(void);
void lcd_set_cursor(uint8_t col, uint8_t row);
void lcd_putc(char c);           /* raw byte: 0..7 = custom CGRAM glyphs */
void lcd_puts(const char *s);
void lcd_puts_P(const char *progmem_s);
/* Writes exactly LCD_COLS cells on a row, padding with spaces. */
void lcd_write_row(uint8_t row, const uint8_t *cells, uint8_t n);
/* Loads one 5x8 glyph (8 rows, low 5 bits used) into CGRAM slot 0..7. */
void lcd_create_char(uint8_t slot, const uint8_t rows[8]);
void lcd_backlight(uint8_t on);

#endif
