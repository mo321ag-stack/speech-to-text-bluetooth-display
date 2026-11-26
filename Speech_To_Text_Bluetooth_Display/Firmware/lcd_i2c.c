/*
 * lcd_i2c.c - HD44780 over PCF8574.
 * Common backpack wiring: P0=RS P1=RW P2=EN P3=Backlight P4..P7=D4..D7.
 * If your backpack uses another mapping, change the defines below.
 */
#include "config.h"
#include "lcd_i2c.h"
#include "twi_i2c.h"
#include <avr/pgmspace.h>
#include <util/delay.h>

#define PIN_RS  0x01
#define PIN_RW  0x02
#define PIN_EN  0x04
#define PIN_BL  0x08

static uint8_t s_addr = 0;
static uint8_t s_bl = PIN_BL;

/* Sends one 4-bit nibble (already in bits 7..4) with an EN pulse, in ONE I2C transaction. */
static void write4(uint8_t nibble_and_mode)
{
    uint8_t v = nibble_and_mode | s_bl;
    uint8_t seq[3] = { v, (uint8_t)(v | PIN_EN), v };  /* EN high >= 450 ns, then low */
    twi_write_bytes(s_addr, seq, 3);
    _delay_us(40);                                     /* most commands need 37 us */
}

static void send(uint8_t value, uint8_t mode)
{
    write4((value & 0xF0) | mode);
    write4((uint8_t)(value << 4) | mode);
}

static void command(uint8_t c) { if (s_addr) send(c, 0); }

uint8_t lcd_init(void)
{
    static const uint8_t ranges[2][2] = { { 0x20, 0x27 }, { 0x38, 0x3F } };
    s_addr = 0;
    for (uint8_t r = 0; r < 2 && !s_addr; r++) {
        /* try the common 0x27 / 0x3F first */
        for (int8_t a = (int8_t)ranges[r][1]; a >= (int8_t)ranges[r][0]; a--) {
            if (twi_probe((uint8_t)a) == TWI_OK) { s_addr = (uint8_t)a; break; }
        }
    }
    if (!s_addr) return 0;

    _delay_ms(50);                         /* LCD power-on time */
    twi_write_bytes(s_addr, &s_bl, 1);     /* all lines low, backlight on */
    _delay_ms(5);

    /* Datasheet 4-bit initialisation by instruction */
    write4(0x30); _delay_ms(5);
    write4(0x30); _delay_us(150);
    write4(0x30); _delay_us(150);
    write4(0x20); _delay_us(150);          /* now in 4-bit mode */

    command(0x28);                         /* 4-bit, 2 lines, 5x8 font */
    command(0x08);                         /* display off */
    lcd_clear();
    command(0x06);                         /* entry: increment, no shift */
    command(0x0C);                         /* display on, cursor off */
    return s_addr;
}

uint8_t lcd_present(void) { return s_addr != 0; }
uint8_t lcd_address(void) { return s_addr; }

void lcd_clear(void)
{
    command(0x01);
    _delay_ms(2);                          /* clear needs 1.52 ms */
}

void lcd_set_cursor(uint8_t col, uint8_t row)
{
    static const uint8_t offs[2] = { 0x00, 0x40 };
    if (row >= LCD_ROWS) row = LCD_ROWS - 1;
    if (col >= LCD_COLS) col = LCD_COLS - 1;
    command(0x80 | (uint8_t)(offs[row] + col));
}

void lcd_putc(char c) { if (s_addr) send((uint8_t)c, PIN_RS); }

void lcd_puts(const char *s) { while (*s) lcd_putc(*s++); }

void lcd_puts_P(const char *p)
{
    char c;
    while ((c = (char)pgm_read_byte(p++)) != 0) lcd_putc(c);
}

void lcd_write_row(uint8_t row, const uint8_t *cells, uint8_t n)
{
    lcd_set_cursor(0, row);
    for (uint8_t i = 0; i < LCD_COLS; i++) lcd_putc(i < n ? (char)cells[i] : ' ');
}

void lcd_create_char(uint8_t slot, const uint8_t rows[8])
{
    command(0x40 | (uint8_t)((slot & 7) << 3));   /* set CGRAM address */
    for (uint8_t i = 0; i < 8; i++) send(rows[i] & 0x1F, PIN_RS);
    command(0x80);                                 /* back to DDRAM */
}

void lcd_backlight(uint8_t on)
{
    s_bl = on ? PIN_BL : 0;
    if (s_addr) twi_write_bytes(s_addr, &s_bl, 1);
}
